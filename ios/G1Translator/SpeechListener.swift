import AVFoundation
import Foundation
import Speech

/// Continuous speech recognition with Apple's built-in recognizer (free, on-device when available).
/// A sentence is finished when no new words arrive for `sentencePause` seconds.
@MainActor
final class SpeechListener: ObservableObject {
    @Published private(set) var running = false
    @Published private(set) var error: String?

    var onPartial: ((String) -> Void)?
    var onSentence: ((String) -> Void)?

    var sentencePause: TimeInterval = 0.8
    private(set) var lastVoiceAt = Date.distantPast
    var isSpeaking: Bool { Date().timeIntervalSince(lastVoiceAt) < 0.35 }

    private let engine = AVAudioEngine()
    private var recognizer: SFSpeechRecognizer?
    private var request: SFSpeechAudioBufferRecognitionRequest? {
        didSet { tapRequest = request }
    }
    /// Read from the audio thread – audio buffers must be appended synchronously in the tap.
    nonisolated(unsafe) private var tapRequest: SFSpeechAudioBufferRecognitionRequest?
    private var task: SFSpeechRecognitionTask?
    private var current = ""
    private var sentenceTimer: Task<Void, Never>?
    private var generation = 0

    static func requestPermissions() async -> Bool {
        let speech = await withCheckedContinuation { cont in
            SFSpeechRecognizer.requestAuthorization { cont.resume(returning: $0 == .authorized) }
        }
        let mic = await AVAudioApplication.requestRecordPermission()
        return speech && mic
    }

    /// true = audio comes from the glasses (appendPCM), the phone microphone only keeps the app alive.
    nonisolated(unsafe) private var externalAudio = false
    private let pcmFormat = AVAudioFormat(commonFormat: .pcmFormatInt16, sampleRate: 16_000,
                                          channels: 1, interleaved: false)!

    func start(localeID: String, externalAudio: Bool = false) {
        stop()
        self.externalAudio = externalAudio
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

            let input = engine.inputNode
            let format = input.outputFormat(forBus: 0)
            input.removeTap(onBus: 0)
            input.installTap(onBus: 0, bufferSize: 1024, format: format, block: Self.makeTap(self))
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

    private func startRecognition() {
        guard let recognizer else { return }
        generation += 1
        let gen = generation
        let req = SFSpeechAudioBufferRecognitionRequest()
        req.shouldReportPartialResults = true
        if recognizer.supportsOnDeviceRecognition { req.requiresOnDeviceRecognition = true }
        req.addsPunctuation = true
        request = req
        current = ""
        task = recognizer.recognitionTask(with: req, resultHandler: Self.makeResultHandler(self, gen: gen))
    }

    // Callbacks arrive on background threads: build them outside the main actor.
    nonisolated private static func makeTap(_ listener: SpeechListener) -> AVAudioNodeTapBlock {
        { [weak listener] buffer, _ in
            guard let listener, !listener.externalAudio else { return }
            listener.tapRequest?.append(buffer)
            if rms(buffer) > 0.015 {
                Task { @MainActor in listener.lastVoiceAt = Date() }
            }
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

    /// 16 kHz mono Int16 PCM from the glasses microphone.
    func appendPCM(_ data: Data) {
        guard running, externalAudio, data.count >= 2 else { return }
        let frames = AVAudioFrameCount(data.count / 2)
        guard let buffer = AVAudioPCMBuffer(pcmFormat: pcmFormat, frameCapacity: frames),
              let channel = buffer.int16ChannelData?[0] else { return }
        buffer.frameLength = frames
        var sum: Float = 0
        data.withUnsafeBytes { raw in
            let src = raw.bindMemory(to: Int16.self)
            for i in 0..<Int(frames) {
                channel[i] = src[i]
                let v = Float(src[i]) / 32768
                sum += v * v
            }
        }
        tapRequest?.append(buffer)
        if (sum / Float(frames)).squareRoot() > 0.015 { lastVoiceAt = Date() }
    }

    private func handle(text: String?, isFinal: Bool, failed: Bool) {
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

    nonisolated private static func rms(_ buffer: AVAudioPCMBuffer) -> Float {
        guard let ch = buffer.floatChannelData?[0], buffer.frameLength > 0 else { return 0 }
        var sum: Float = 0
        for i in 0..<Int(buffer.frameLength) { sum += ch[i] * ch[i] }
        return (sum / Float(buffer.frameLength)).squareRoot()
    }
}
