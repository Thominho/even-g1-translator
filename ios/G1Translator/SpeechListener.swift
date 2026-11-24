import AVFoundation
import Foundation
import Speech

enum MicMode: String, CaseIterable { case auto, glasses, phone }
enum MicSource: String { case glasses, phone }

/// Continuous speech recognition with Apple's built-in recognizer.
///
/// Audio can come from the G1 glasses (`ingest(_, .glasses)`) and/or the iPhone microphone.
/// In `.auto` mode both are listened to and the one that hears the speaker better
/// (higher speech-to-noise ratio) is fed to the recognizer. The chosen stream gets
/// automatic gain so quiet or distant speakers are still recognised.
/// A sentence is finished when no new words arrive for `sentencePause` seconds.
@MainActor
final class SpeechListener: ObservableObject {
    @Published private(set) var running = false
    @Published private(set) var error: String?
    @Published private(set) var activeSource: MicSource = .phone

    var onPartial: ((String) -> Void)?
    var onSentence: ((String) -> Void)?
    /// What the user said in their own language while dictating.
    var onDictation: ((String) -> Void)?
    private(set) var dictating = false
    private var conversationLocale = ""

    var sentencePause: TimeInterval = 0.8
    private(set) var lastVoiceAt = Date.distantPast
    var isSpeaking: Bool { Date().timeIntervalSince(lastVoiceAt) < 0.35 }

    private let engine = AVAudioEngine()
    private var recognizer: SFSpeechRecognizer?
    private var request: SFSpeechAudioBufferRecognitionRequest?
    private var task: SFSpeechRecognitionTask?
    private var current = ""
    private var sentenceTimer: Task<Void, Never>?
    private var generation = 0
    private var mode: MicMode = .auto
    private var online = true

    private let pcmFormat = AVAudioFormat(commonFormat: .pcmFormatInt16, sampleRate: 16_000,
                                          channels: 1, interleaved: false)!
    /// Used on the audio thread only.
    nonisolated(unsafe) private var converter: AVAudioConverter?

    static func requestPermissions() async -> Bool {
        let speech = await withCheckedContinuation { cont in
            SFSpeechRecognizer.requestAuthorization { cont.resume(returning: $0 == .authorized) }
        }
        let mic = await AVAudioApplication.requestRecordPermission()
        return speech && mic
    }

    // MARK: - Start / stop

    func start(localeID: String, mode: MicMode, online: Bool) {
        stop()
        self.mode = mode
        self.online = online
        conversationLocale = localeID
        dictating = false
        stats = [:]
        activeSource = mode == .glasses ? .glasses : .phone
        guard let rec = SFSpeechRecognizer(locale: Locale(identifier: localeID)), rec.isAvailable else {
            error = "Speech recognition is not available for this language."
            return
        }
        recognizer = rec
        do {
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(.playAndRecord, mode: .measurement,
                                    options: [.allowBluetooth, .defaultToSpeaker, .mixWithOthers])
            try session.setActive(true, options: .notifyOthersOnDeactivation)

            // The iPhone microphone always runs: it is a source in auto/phone mode
            // and keeps the app alive in the background in glasses mode.
            let input = engine.inputNode
            let format = input.outputFormat(forBus: 0)
            converter = AVAudioConverter(from: format, to: pcmFormat)
            input.removeTap(onBus: 0)
            input.installTap(onBus: 0, bufferSize: 2048, format: format,
                             block: Self.makeTap(self, outFormat: pcmFormat))
            engine.prepare()
            try engine.start()
            running = true
            error = nil
            startRecognition()
        } catch {
            self.error = error.localizedDescription
            stop()
        }
    }

    func stop() {
        sentenceTimer?.cancel()
        task?.cancel(); task = nil
        request?.endAudio(); request = nil
        if engine.isRunning {
            engine.stop()
            engine.inputNode.removeTap(onBus: 0)
        }
        running = false
        current = ""
    }

    // MARK: - Dictation ("say it in my language")

    /// Switch recognition to the user's own language until `endDictation()`.
    func beginDictation(localeID: String) {
        guard running, !dictating,
              let rec = SFSpeechRecognizer(locale: Locale(identifier: localeID)), rec.isAvailable else { return }
        sentenceTimer?.cancel()
        let pending = current.trimmingCharacters(in: .whitespacesAndNewlines)
        task?.cancel(); request?.endAudio()
        if !pending.isEmpty { onSentence?(pending) }
        dictating = true
        recognizer = rec
        startRecognition()
    }

    func endDictation() {
        guard dictating else { return }
        Task {
            try? await Task.sleep(for: .milliseconds(700))   // let the last words arrive
            finishDictation()
        }
    }

    private func finishDictation() {
        guard dictating else { return }
        let text = current.trimmingCharacters(in: .whitespacesAndNewlines)
        dictating = false
        task?.cancel(); request?.endAudio()
        recognizer = SFSpeechRecognizer(locale: Locale(identifier: conversationLocale))
        if running { startRecognition() }
        if !text.isEmpty { onDictation?(text) }
    }

    // MARK: - Choosing the better microphone

    private struct Stats {
        var level: Float = 0          // short-term loudness
        var noise: Float = 0.01       // background noise floor
        var speech: Float = 0.05      // typical speech loudness (for gain)
        var gain: Float = 1
        var lastSeen = Date.distantPast
        var snr: Float { level / max(noise, 0.0005) }
    }
    private var stats: [MicSource: Stats] = [:]
    private var betterSince: Date?

    /// 16 kHz mono Int16 PCM from one of the microphones.
    func ingest(_ data: Data, from source: MicSource) {
        guard running, data.count >= 2 else { return }
        if mode == .glasses && source == .phone { return }
        if mode == .phone && source == .glasses { return }

        var samples = data.withUnsafeBytes { Array($0.bindMemory(to: Int16.self)) }
        let rms = Self.rms(samples)
        var s = stats[source] ?? Stats()
        s.lastSeen = Date()
        s.level = s.level * 0.6 + rms * 0.4
        s.noise = rms < s.noise ? s.noise * 0.9 + rms * 0.1 : s.noise * 0.998 + rms * 0.002
        let isSpeech = rms > s.noise * 3 && rms > 0.004
        if isSpeech { s.speech = s.speech * 0.95 + rms * 0.05 }
        stats[source] = s

        if mode == .auto { chooseSource() }
        guard source == activeSource else { return }

        // automatic gain: bring speech to a comfortable level (max 6×)
        let target = min(6, max(1, 0.12 / max(s.speech, 0.001)))
        s.gain += (target - s.gain) * 0.1
        stats[source] = s
        if s.gain > 1.05 {
            for i in samples.indices {
                samples[i] = Int16(clamping: Int(Float(samples[i]) * s.gain))
            }
        }
        append(samples)
        if isSpeech { lastVoiceAt = Date() }
    }

    private func chooseSource() {
        let now = Date()
        let glassesAlive = now.timeIntervalSince(stats[.glasses]?.lastSeen ?? .distantPast) < 1
        // the user's own voice: the glasses microphone is made for it
        if dictating, glassesAlive {
            if activeSource != .glasses { activeSource = .glasses }
            return
        }
        if !glassesAlive {
            if activeSource != .phone { activeSource = .phone }
            betterSince = nil
            return
        }
        let other: MicSource = activeSource == .glasses ? .phone : .glasses
        guard let a = stats[activeSource], let b = stats[other] else {
            if stats[activeSource] == nil, stats[other] != nil { activeSource = other }
            return
        }
        // switch only when the other microphone is clearly better for a while (no flapping)
        if b.snr > a.snr * 1.5, b.level > 0.006 {
            if let since = betterSince {
                if now.timeIntervalSince(since) > 0.8 {
                    activeSource = other
                    betterSince = nil
                }
            } else {
                betterSince = now
            }
        } else {
            betterSince = nil
        }
    }

    private func append(_ samples: [Int16]) {
        guard let request,
              let buffer = AVAudioPCMBuffer(pcmFormat: pcmFormat, frameCapacity: AVAudioFrameCount(samples.count)),
              let channel = buffer.int16ChannelData?[0] else { return }
        buffer.frameLength = AVAudioFrameCount(samples.count)
        samples.withUnsafeBufferPointer { src in
            channel.update(from: src.baseAddress!, count: samples.count)
        }
        request.append(buffer)
    }

    nonisolated private static func rms(_ samples: [Int16]) -> Float {
        guard !samples.isEmpty else { return 0 }
        var sum: Float = 0
        for v in samples { let f = Float(v) / 32768; sum += f * f }
        return (sum / Float(samples.count)).squareRoot()
    }

    // MARK: - Recognition

    private func startRecognition() {
        guard let recognizer else { return }
        generation += 1
        let gen = generation
        let req = SFSpeechAudioBufferRecognitionRequest()
        req.shouldReportPartialResults = true
        // online = Apple's servers: more accurate in noise; offline = on the iPhone
        req.requiresOnDeviceRecognition = !online && recognizer.supportsOnDeviceRecognition
        req.addsPunctuation = true
        request = req
        current = ""
        task = recognizer.recognitionTask(with: req, resultHandler: Self.makeResultHandler(self, gen: gen))
    }

    // Callbacks arrive on background threads: build them outside the main actor.
    nonisolated private static func makeTap(_ listener: SpeechListener, outFormat: AVAudioFormat)
        -> AVAudioNodeTapBlock {
        { [weak listener] buffer, _ in
            guard let listener, let converter = listener.converter else { return }
            let ratio = outFormat.sampleRate / buffer.format.sampleRate
            let capacity = AVAudioFrameCount(Double(buffer.frameLength) * ratio) + 16
            guard let out = AVAudioPCMBuffer(pcmFormat: outFormat, frameCapacity: capacity) else { return }
            var fed = false
            var err: NSError?
            converter.convert(to: out, error: &err) { _, status in
                if fed { status.pointee = .noDataNow; return nil }
                fed = true
                status.pointee = .haveData
                return buffer
            }
            guard err == nil, out.frameLength > 0, let ch = out.int16ChannelData?[0] else { return }
            let data = Data(bytes: ch, count: Int(out.frameLength) * 2)
            Task { @MainActor in listener.ingest(data, from: .phone) }
        }
    }

    nonisolated private static func makeResultHandler(_ listener: SpeechListener, gen: Int)
        -> (SFSpeechRecognitionResult?, Error?) -> Void {
        { [weak listener] result, error in
            let text = result?.bestTranscription.formattedString
            let isFinal = result?.isFinal ?? false
            let failed = error != nil
            Task { @MainActor in
                guard let listener, gen == listener.generation else { return }
                listener.handle(text: text, isFinal: isFinal, failed: failed)
            }
        }
    }

    private func handle(text: String?, isFinal: Bool, failed: Bool) {
        if dictating {
            if let text, !text.isEmpty { current = text }
            return
        }
        if let text, !text.isEmpty, text != current {
            current = text
            onPartial?(text)
            scheduleSentenceEnd()
        }
        if failed && current.isEmpty {
            // e.g. "no speech detected" – restart calmly instead of looping
            task?.cancel()
            generation += 1
            Task {
                try? await Task.sleep(for: .seconds(1))
                if running { startRecognition() }
            }
            return
        }
        if isFinal || failed { finishSentence() }
    }

    private func scheduleSentenceEnd() {
        sentenceTimer?.cancel()
        sentenceTimer = Task {
            try? await Task.sleep(for: .seconds(sentencePause))
            if !Task.isCancelled { finishSentence() }
        }
    }

    /// Emit the current sentence and start a fresh recognition request.
    private func finishSentence() {
        sentenceTimer?.cancel()
        let text = current.trimmingCharacters(in: .whitespacesAndNewlines)
        task?.cancel()
        request?.endAudio()
        guard running else { return }
        startRecognition()
        if !text.isEmpty { onSentence?(text) }
    }
}
