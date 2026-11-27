import Foundation
import UIKit

/// Timestamped event log – shown in the app (and in the Xcode console) to find delays.
@MainActor
final class DebugLog: ObservableObject {
    static let shared = DebugLog()
    @Published private(set) var lines: [String] = []
    private let t0 = Date()
    func add(_ s: String) {
        let line = String(format: "%6.1f ", Date().timeIntervalSince(t0)) + s
        print("G1T " + line)
        lines.append(line)
        if lines.count > 80 { lines.removeFirst(lines.count - 80) }
    }
}
@MainActor func dlog(_ s: String) { DebugLog.shared.add(s) }
private func short(_ s: String, _ n: Int = 40) -> String {
    let one = s.replacingOccurrences(of: "\n", with: " / ")
    return one.count > n ? String(one.prefix(n)) + "…" : one
}

/// The whole hands-free flow:
/// they speak → live translation → they stop → all 3 replies on one screen →
/// you read one aloud → questions to ask back → they answer → …
@MainActor
final class TranslatorEngine: ObservableObject {
    @Published private(set) var running = false
    @Published private(set) var paused = false
    @Published private(set) var screen = ""
    @Published private(set) var status = ""
    @Published private(set) var dictating = false
    @Published private(set) var learningVoice = false

    let glasses: G1Glasses
    let listener = SpeechListener()
    private let lc3 = Lc3Decoder()
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
    private var pendingOrig: [String] = []
    private var turnTimer: Task<Void, Never>?
    private var prefetch: (turn: String, task: Task<[Reply], Error>)?
    private var followups: Task<[[Reply]], Error>?
    /// Draft translations started at short pauses, by exact text – reused when the sentence ends.
    private var drafts: [String: Task<String?, Error>] = [:]
    /// Running summary of the conversation (who, where, what about) – context for the AI.
    private var summary = ""

    /// What the AI should know besides the last sentences.
    private var background: String {
        var parts: [String] = []
        if !settings.aboutMe.trimmingCharacters(in: .whitespaces).isEmpty { parts.append("About the user: \(settings.aboutMe)") }
        if !summary.isEmpty { parts.append("Conversation so far: \(summary)") }
        return parts.joined(separator: "\n")
    }

    init(settings: Settings, glasses: G1Glasses) {
        self.settings = settings
        self.glasses = glasses
        listener.onSentence = { [weak self] text, level in self?.onSentence(text, level: level) }
        listener.onStable = { [weak self] text, level in self?.onStable(text, level: level) }
        listener.onOwnVoiceSample = { [weak self] level in self?.learnVoice(level, from: "say it") }
        listener.onPartial = { [weak self] _ in self?.speechActivity() }   // still talking → wait again
        listener.onDictation = { [weak self] text in Task { await self?.sayIt(text) } }
        glasses.onEvent = { [weak self] ev, side in self?.onEvent(ev, side: side) }
        glasses.onAudio = { [weak self] lc3data in
            guard let self, self.running, !self.paused else { return }
            self.listener.ingest(self.lc3.decode(lc3data), from: .glasses)
        }
    }

    // MARK: - Start / stop

    func start() async {
        if settings.model.isEmpty, !settings.apiKey.isEmpty,
           let models = try? await LLMClient.listModels(apiKey: settings.apiKey),
           let def = LLMClient.defaultModel(in: models) {
            settings.model = def.id
        }
        guard settings.isConfigured else { status = "Add your API key and model in Settings."; return }
        let key = settings.apiKey
        Task.detached { _ = try? await LLMClient.listModels(apiKey: key) }   // opens the connection early
        guard await SpeechListener.requestPermissions() else {
            status = "Allow microphone and speech recognition in Settings."; return
        }
        glasses.charsPerLine = settings.charsPerLine
        if !glasses.isConnected { glasses.connect() }
        listener.start(localeID: settings.speechLocale, mode: settings.mic, online: settings.onlineRecognition)
        if let err = listener.error { status = err; return }
        glasses.setMic(settings.mic != .phone)
        running = true
        paused = false
        status = ""
        UIApplication.shared.isIdleTimerDisabled = true
        newConversation()
        show("\(lang.t("start", lang: lang.name(settings.nativeLanguage)))\n\(lang.t("listening"))")
    }

    func stop() {
        glasses.setMic(false)
        listener.stop()
        cancelTurnTimer()
        running = false
        UIApplication.shared.isIdleTimerDisabled = false
    }

    func togglePause() {
        paused.toggle()
        if paused {
            glasses.setMic(false)
            listener.stop()
        } else {
            listener.start(localeID: settings.speechLocale, mode: settings.mic, online: settings.onlineRecognition)
            glasses.setMic(settings.mic != .phone)
        }
        show(paused ? lang.t("paused") : lang.t("listening"))
    }

    func newConversation() {
        turnOrig = []; turnTr = []; history = []; replies = []
        mode = "reply"; headerShown = false; summary = ""
        for job in drafts.values { job.cancel() }
        drafts = [:]
        prefetch?.task.cancel(); prefetch = nil
        followups?.cancel(); followups = nil
    }

    private func show(_ text: String) {
        dlog("SHOW \(short(text, 60))")
        screen = G1Protocol.tail(text, width: settings.charsPerLine)
        glasses.show(text)
    }

    // MARK: - Speech

    // MARK: - The user's own voice

    /// The glasses microphone sits next to the wearer's mouth: their own voice is much louder there.
    private func isOwnVoice(_ level: Float?) -> Bool {
        guard settings.ownVoiceLevel > 0, let level else { return false }
        return Double(level) >= settings.ownVoiceLevel * 0.5
    }

    private func learnVoice(_ level: Float, from source: String) {
        let old = settings.ownVoiceLevel
        settings.ownVoiceLevel = old == 0 ? Double(level) : old * 0.7 + Double(level) * 0.3
        dlog(String(format: "VOICE learned from %@: %.4f → %.4f", source, old, settings.ownVoiceLevel))
    }

    /// "Learn my voice": the user says a few words with the glasses on.
    func learnMyVoice() async {
        guard running, !paused, !learningVoice else { return }
        guard glasses.isConnected, settings.mic != .phone else {
            status = "Connect the glasses and use the glasses or automatic microphone."
            return
        }
        learningVoice = true
        cancelTurnTimer()
        show(lang.t("calib"))
        let level = await listener.measureVoice(seconds: 4)
        learningVoice = false
        if let level {
            settings.ownVoiceLevel = Double(level)
            dlog(String(format: "VOICE calibrated %.4f", level))
            show("\(lang.t("calib_ok"))\n\(lang.t("listening"))")
            status = ""
        } else {
            show(lang.t("listening"))
            status = "I couldn't hear you – try again a little louder."
        }
    }

    // MARK: - Speech

    private func onSentence(_ text: String, level: Float?) {
        guard running, !paused, !learningVoice else { return }
        let own = isOwnVoice(level)
        dlog("SENT \(short(text)) " + (level.map { String(format: "lvl %.4f", $0) } ?? "lvl –") + (own ? " ME" : ""))
        speechActivity()
        if Date().timeIntervalSince(lastSpeech) > 90 { newConversation() }
        let draft = drafts.removeValue(forKey: text)
        for job in drafts.values { job.cancel() }
        drafts = [:]

        // the user read one of the suggestions aloud → don't translate it
        if let best = replies.max(by: { similarity($0.text, text) < similarity($1.text, text) }),
           similarity(best.text, text) >= (own ? 0.4 : 0.6) {
            dlog("USER SAID suggestion \(short(best.text))")
            if let level, !own { learnVoice(level, from: "suggestion") }
            draft?.cancel()
            Task { await userSaid(best) }
            return
        }
        // the user's own voice (e.g. talking to someone next to them) → not the other person
        if own {
            dlog("ME – not translated")
            draft?.cancel()
            return
        }
        // the request starts right away (sentences are translated in parallel, or the draft is reused),
        // the results are shown in order
        let context = contextLines + pendingOrig.map { "They: \($0)" }
        pendingOrig.append(text)
        let interp = interpreter, l = convLang, bg = background
        let started = Date()
        if draft != nil { dlog("draft reused") }
        let job = draft ?? Task { try await interp.translate(text, lang: l, context: context, background: bg) }
        let previous = translateChain
        translateChain = Task {
            await previous?.value
            await self.applyTranslation(text, job: job, started: started)
        }
    }

    private var contextLines: [String] { Array(history.suffix(8)) }

    /// A short pause mid-speech: translate what we have so far and show it as a draft.
    private func onStable(_ text: String, level: Float?) {
        guard running, !paused, !learningVoice, !dictating, text.count >= 4,
              drafts[text] == nil, !isOwnVoice(level) else { return }
        if replies.contains(where: { similarity($0.text, text) >= 0.45 }) { return }   // reading a suggestion
        let context = contextLines + pendingOrig.map { "They: \($0)" }
        let interp = interpreter, l = convLang, bg = background
        let started = Date()
        let job = Task { try await interp.translate(text, lang: l, context: context, background: bg) }
        drafts[text] = job
        Task {
            guard let tr = try? await job.value else { return }   // nil = noise
            // still being spoken (the final sentence will show it otherwise)
            guard self.drafts[text] != nil, self.pendingOrig.isEmpty else { return }
            dlog(String(format: "DRAFT %.1fs ", Date().timeIntervalSince(started)) + short(tr))
            self.show(self.turnBody(adding: tr))
            if self.settings.replies { self.startPrefetch(adding: text) }
        }
    }

    /// The translated turn so far (with the language label at the start of a conversation).
    private func turnBody(adding extra: String? = nil) -> String {
        var body = (turnTr + (extra.map { [$0] } ?? [])).joined(separator: " ")
        if !headerShown {
            body = "[\(lang.name(settings.conversationLanguage).uppercased())]\n" + body
        }
        return body
    }

    private func applyTranslation(_ text: String, job: Task<String?, Error>, started: Date) async {
        defer { if let i = pendingOrig.firstIndex(of: text) { pendingOrig.remove(at: i) } }
        let translated: String?
        do {
            translated = try await job.value
        } catch {
            dlog("TRANSLATE ERROR \(error.localizedDescription)")
            status = error.localizedDescription
            return
        }
        dlog(String(format: "TR %.1fs ", Date().timeIntervalSince(started)) + short(translated ?? "– (noise)"))
        guard let tr = translated else { return }      // noise / not the conversation language
        lastSpeech = Date()
        replies = []; mode = "reply"
        followups?.cancel(); followups = nil
        turnOrig.append(text)
        turnTr.append(tr)
        history.append("They: \(text) (\(tr))")
        let body = turnBody()
        if turnTr.count >= 1 { headerShown = true }
        show(body)
        status = ""
        if settings.replies { startPrefetch() }
    }

    // MARK: - Speaker finished → replies

    private func cancelTurnTimer() { turnTimer?.cancel(); turnTimer = nil }

    /// Any recognised speech restarts the countdown to "the speaker has finished".
    /// (The countdown no longer depends on a sentence being translated – a mumble that the
    /// translator drops as noise used to stop the replies from ever appearing.)
    private func speechActivity() {
        guard running, !paused, !dictating, settings.replies else { return }
        scheduleTurnEnd()
    }

    private func scheduleTurnEnd() {
        cancelTurnTimer()
        turnTimer = Task {
            try? await Task.sleep(for: .seconds(settings.turnEnd))
            guard !Task.isCancelled else { return }
            // a voice still in the microphone → give it a moment, but noise must not block replies forever
            var waited = 0.0
            while listener.isSpeaking, waited < 3 {
                try? await Task.sleep(for: .milliseconds(250))
                guard !Task.isCancelled else { return }
                waited += 0.25
            }
            dlog(waited > 0 ? String(format: "TURN END (waited %.1fs for silence)", waited) : "TURN END")
            await turnEnded()
        }
    }

    /// After every sentence, prepare replies in the background → shown instantly at the pause.
    private func startPrefetch(adding extra: String? = nil) {
        let turn = (turnOrig + (extra.map { [$0] } ?? [])).joined(separator: " ")
        if prefetch?.turn == turn { return }               // already being prepared (e.g. from the draft)
        prefetch?.task.cancel()
        let ctx = Array(history.dropLast(turnOrig.count))
        let interp = interpreter, l = convLang, bg = background
        dlog("PREFETCH \(short(turn))")
        prefetch = (turn, Task {
            let t = Date()
            let r = try await interp.replies(turn: turn, lang: l, context: ctx, background: bg)
            dlog(String(format: "REPLIES ready %.1fs, %d", Date().timeIntervalSince(t), r.count))
            return r
        })
    }

    private func turnEnded() async {
        // wait until the last sentence is translated (slow speakers: it may still be on its way)
        await translateChain?.value
        guard !Task.isCancelled, settings.replies, !turnOrig.isEmpty else {
            dlog("turn end skipped (cancelled: \(Task.isCancelled), nothing translated: \(turnOrig.isEmpty))")
            return
        }
        let turn = turnOrig.joined(separator: " ")
        if prefetch?.turn != turn { startPrefetch() }
        guard let pre = prefetch else { return }

        var result: [Reply] = []
        var failure: Error?
        do { result = try await pre.task.value } catch { failure = error; dlog("REPLIES ERROR \(error.localizedDescription)") }
        // they started speaking again → the next pause will bring replies for the whole turn
        guard !Task.isCancelled, turn == turnOrig.joined(separator: " ") else {
            dlog("replies dropped – speech went on")
            return
        }

        if result.isEmpty {
            // the prepared request failed or returned nothing usable → ask once more
            let ctx = Array(history.dropLast(turnOrig.count))
            do { result = try await interpreter.replies(turn: turn, lang: convLang, context: ctx, background: background) }
            catch { failure = error }
            guard !Task.isCancelled, turn == turnOrig.joined(separator: " ") else { return }
        }
        guard !result.isEmpty else {
            dlog("NO REPLIES")
            if let failure, !(failure is CancellationError) { status = failure.localizedDescription }
            return
        }

        replies = result; mode = "reply"
        turnOrig = []; turnTr = []; prefetch = nil
        show(renderAll())
        if settings.followUps {
            let interp = interpreter, l = convLang, ctx = Array(history.suffix(8)), bg = background
            followups = Task { try await interp.followups(turn: turn, lang: l, context: ctx, replies: result, background: bg) }
        }
        updateSummary()
    }

    /// Keeps a 1–2 sentence summary of the conversation for later translations (in the background).
    private func updateSummary() {
        let interp = interpreter, recent = Array(history.suffix(10)), old = summary
        Task {
            guard let s = try? await interp.summarize(previous: old, recent: recent), !s.isEmpty else { return }
            self.summary = s
            dlog("SUMMARY \(short(s, 90))")
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
        let signs = ["yes": "+", "no": "-", "question": "?", "ask": "?", "say": ">"]
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

    // MARK: - Say it in my language

    /// Hold (left TouchBar or the button in the app): the user speaks in their own language.
    func startSay() {
        guard running, !paused, !dictating else { return }
        dictating = true
        cancelTurnTimer()
        listener.beginDictation(localeID: Lang.speechLocale(settings.nativeLanguage))
        show("\(lang.t("say")):\n\(lang.t("speak"))")
    }

    func stopSay() {
        guard dictating else { return }
        dictating = false
        listener.endDictation()
    }

    private func sayIt(_ text: String) async {
        show("\(lang.t("say")): \(text)\n…")
        do {
            let r = try await interpreter.sayIt(text, lang: convLang, context: history, background: background)
            replies = [r]; mode = "say"
            followups?.cancel(); followups = nil
            show("\(lang.t("say")): \(r.meaning)\n> \(r.pron.isEmpty ? r.text : r.pron)")
        } catch {
            status = error.localizedDescription
        }
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
        case .longPress where side == "L":
            startSay()
        case .longPressRelease:
            stopSay()
        case .headUp:
            if !replies.isEmpty { show(renderAll()) }
        default: break
        }
    }
}
