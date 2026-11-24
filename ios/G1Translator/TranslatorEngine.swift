import Foundation
import UIKit

/// The whole hands-free flow:
/// they speak → live translation → they stop → all 3 replies on one screen →
/// you read one aloud → questions to ask back → they answer → …
@MainActor
final class TranslatorEngine: ObservableObject {
    @Published private(set) var running = false
    @Published private(set) var paused = false
    @Published private(set) var screen = ""
    @Published private(set) var status = ""

    let glasses: G1Glasses
    let listener = SpeechListener()
    let settings: Settings

    private var lang: Lang { Lang(code: settings.nativeLanguage) }
    private var convLang: String { Lang.englishName(settings.conversationLanguage) }
    private var interpreter: Interpreter {
        Interpreter(llm: LLMClient(apiKey: settings.apiKey, model: settings.model),
                    native: Lang.englishName(settings.nativeLanguage))
    }

    private var turnOrig: [String] = []
    private var turnTr: [String] = []
    private var history: [String] = []
    private var replies: [Reply] = []
    private var mode = "reply"                  // "reply" or "ask"
    private var headerShown = false
    private var lastSpeech = Date.distantPast
    private var translateChain: Task<Void, Never>?
    private var turnTimer: Task<Void, Never>?
    private var prefetch: (turn: String, task: Task<[Reply], Error>)?
    private var followups: Task<[[Reply]], Error>?

    init(settings: Settings, glasses: G1Glasses) {
        self.settings = settings
        self.glasses = glasses
        listener.onSentence = { [weak self] in self?.onSentence($0) }
        listener.onPartial = { [weak self] _ in self?.cancelTurnTimer() }   // still talking
        glasses.onEvent = { [weak self] ev, side in self?.onEvent(ev, side: side) }
    }

    // MARK: - Start / stop

    func start() async {
        if settings.model.isEmpty, !settings.apiKey.isEmpty,
           let models = try? await LLMClient.listModels(apiKey: settings.apiKey),
           let def = LLMClient.defaultModel(in: models) {
            settings.model = def.id
        }
        guard settings.isConfigured else { status = "Add your API key and model in Settings."; return }
        guard await SpeechListener.requestPermissions() else {
            status = "Allow microphone and speech recognition in Settings."; return
        }
        glasses.charsPerLine = settings.charsPerLine
        if !glasses.isConnected { glasses.connect() }
        listener.start(localeID: settings.speechLocale)
        if let err = listener.error { status = err; return }
        running = true
        paused = false
        status = ""
        UIApplication.shared.isIdleTimerDisabled = true
        newConversation()
        show("\(lang.t("start", lang: lang.name(settings.nativeLanguage)))\n\(lang.t("listening"))")
    }

    func stop() {
        listener.stop()
        cancelTurnTimer()
        running = false
        UIApplication.shared.isIdleTimerDisabled = false
    }

    func togglePause() {
        paused.toggle()
        if paused { listener.stop() } else { listener.start(localeID: settings.speechLocale) }
        show(paused ? lang.t("paused") : lang.t("listening"))
    }

    func newConversation() {
        turnOrig = []; turnTr = []; history = []; replies = []
        mode = "reply"; headerShown = false
        prefetch?.task.cancel(); prefetch = nil
        followups?.cancel(); followups = nil
    }

    private func show(_ text: String) {
        screen = G1Protocol.tail(text, width: settings.charsPerLine)
        glasses.show(text)
    }

    // MARK: - Speech

    private func onSentence(_ text: String) {
        guard running, !paused else { return }
        if Date().timeIntervalSince(lastSpeech) > 90 { newConversation() }

        // the user read one of the suggestions aloud → don't translate it
        if let best = replies.max(by: { similarity($0.text, text) < similarity($1.text, text) }),
           similarity(best.text, text) >= 0.6 {
            Task { await userSaid(best) }
            return
        }
        // translate in order, one sentence after another
        let previous = translateChain
        translateChain = Task {
            await previous?.value
            await self.translateSentence(text)
        }
    }

    private func translateSentence(_ text: String) async {
        let context = history
        let translated: String?
        do {
            translated = try await interpreter.translate(text, lang: convLang, context: context)
        } catch {
            status = error.localizedDescription
            return
        }
        guard let tr = translated else { return }      // noise / not the conversation language
        lastSpeech = Date()
        replies = []; mode = "reply"
        followups?.cancel(); followups = nil
        turnOrig.append(text)
        turnTr.append(tr)
        history.append("They: \(text) (\(tr))")
        var body = turnTr.joined(separator: " ")
        if !headerShown {
            body = "[\(lang.name(settings.conversationLanguage).uppercased())]\n" + body
            if turnTr.count == 1 { headerShown = true }
        }
        show(body)
        status = ""
        if settings.replies {
            startPrefetch()
            scheduleTurnEnd()
        }
    }

    // MARK: - Speaker finished → replies

    private func cancelTurnTimer() { turnTimer?.cancel(); turnTimer = nil }

    private func scheduleTurnEnd() {
        cancelTurnTimer()
        turnTimer = Task {
            try? await Task.sleep(for: .seconds(settings.turnEnd))
            guard !Task.isCancelled else { return }
            if listener.isSpeaking { scheduleTurnEnd(); return }
            await turnEnded()
        }
    }

    /// After every sentence, prepare replies in the background → shown instantly at the pause.
    private func startPrefetch() {
        let turn = turnOrig.joined(separator: " ")
        prefetch?.task.cancel()
        let ctx = Array(history.dropLast(turnOrig.count))
        let interp = interpreter, l = convLang
        prefetch = (turn, Task { try await interp.replies(turn: turn, lang: l, context: ctx) })
    }

    private func turnEnded() async {
        guard !turnOrig.isEmpty, let pre = prefetch else { return }
        let turn = pre.turn
        do {
            let result = try await pre.task.value
            guard turn == turnOrig.joined(separator: " "), !listener.isSpeaking else { return }
            replies = result; mode = "reply"
            turnOrig = []; turnTr = []; prefetch = nil
            guard !result.isEmpty else { return }
            show(renderAll())
            if settings.followUps {
                let interp = interpreter, l = convLang, ctx = Array(history.suffix(8))
                followups = Task { try await interp.followups(turn: turn, lang: l, context: ctx, replies: result) }
            }
        } catch {
            if !(error is CancellationError) { status = error.localizedDescription }
        }
    }

    /// The user said a suggestion. After an answer, offer questions to ask back.
    private func userSaid(_ said: Reply) async {
        history.append("Me: \(said.text)")
        var questions: [Reply] = []
        if mode == "reply", let fu = followups, let idx = replies.firstIndex(of: said) {
            if let all = try? await fu.value, idx < all.count { questions = all[idx] }
        }
        followups = nil
        if questions.isEmpty {
            replies = []; mode = "reply"
            show("\(lang.t("you_said")): \(said.meaning.isEmpty ? said.text : said.meaning)\n\(lang.t("listening"))")
        } else {
            replies = questions; mode = "ask"
            show(renderAll())
        }
    }

    /// All suggestions on one screen: "<sign> meaning: pronunciation" per line.
    /// If it would not fit on 5 lines, drop the header, then the meanings.
    private func renderAll() -> String {
        let signs = ["yes": "+", "no": "-", "question": "?", "ask": "?"]
        func build(header: Bool, meaning: Bool) -> String {
            var lines: [String] = header && mode == "ask" ? ["\(lang.t("ask")):"] : []
            for r in replies {
                let sign = signs[mode == "ask" ? "ask" : r.kind] ?? "*"
                let say = r.pron.isEmpty ? r.text : r.pron
                lines.append(meaning && !r.meaning.isEmpty ? "\(sign) \(r.meaning): \(say)" : "\(sign) \(say)")
            }
            return lines.joined(separator: "\n")
        }
        for (h, m) in [(true, true), (false, true), (false, false)] {
            let text = build(header: h, meaning: m)
            if G1Protocol.fits(text, width: settings.charsPerLine) { return text }
        }
        return build(header: false, meaning: false)
    }

    // MARK: - Optional TouchBar

    private func onEvent(_ ev: G1Protocol.Event, side: String) {
        switch ev {
        case .tripleTap: togglePause()
        case .doubleTap:
            if !replies.isEmpty {
                replies = []
                show(lang.t("listening"))
            } else {
                newConversation()
                show("\(lang.t("new"))\n\(lang.t("listening"))")
            }
        case .headUp, .longPress:
            if !replies.isEmpty { show(renderAll()) }
        default: break
        }
    }
}
