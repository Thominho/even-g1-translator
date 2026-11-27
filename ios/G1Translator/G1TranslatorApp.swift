import SwiftUI

@main
struct G1TranslatorApp: App {
    @StateObject private var settings: Settings
    @StateObject private var glasses: G1Glasses
    @StateObject private var engine: TranslatorEngine

    init() {
        let s = Settings()
        let g = G1Glasses()
        _settings = StateObject(wrappedValue: s)
        _glasses = StateObject(wrappedValue: g)
        _engine = StateObject(wrappedValue: TranslatorEngine(settings: s, glasses: g))
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(settings)
                .environmentObject(glasses)
                .environmentObject(engine)
                .environmentObject(engine.listener)
                .preferredColorScheme(.dark)
        }
    }
}

struct ContentView: View {
    @EnvironmentObject var settings: Settings
    @EnvironmentObject var glasses: G1Glasses
    @EnvironmentObject var engine: TranslatorEngine
    @EnvironmentObject var listener: SpeechListener
    @State private var showSettings = false

    @ObservedObject private var log = DebugLog.shared
    private let green = Color(red: 0.24, green: 1.0, blue: 0.56)

    var body: some View {
        NavigationStack {
            VStack(spacing: 20) {
                glassesStatus

                // Mirror of the glasses display
                Text(engine.screen.isEmpty ? " " : engine.screen)
                    .font(.system(.body, design: .monospaced))
                    .foregroundStyle(green)
                    .frame(maxWidth: .infinity, minHeight: 150, alignment: .topLeading)
                    .padding()
                    .background(Color.black, in: RoundedRectangle(cornerRadius: 14))
                    .overlay(RoundedRectangle(cornerRadius: 14).stroke(green.opacity(0.5)))

                if engine.running {
                    Label(settings.t(listener.activeSource == .glasses ? "G1 glasses" : "iPhone / AirPods"),
                          systemImage: "mic.fill")
                        .font(.footnote).foregroundStyle(.secondary)
                }

                if !engine.status.isEmpty {
                    Text(settings.t(engine.status)).font(.footnote).foregroundStyle(.orange)
                }

                DisclosureGroup("Log") {
                    ScrollViewReader { proxy in
                        ScrollView {
                            VStack(alignment: .leading, spacing: 1) {
                                ForEach(Array(log.lines.enumerated()), id: \.offset) { i, line in
                                    Text(line).font(.system(size: 10, design: .monospaced)).id(i)
                                }
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                        }
                        .frame(height: 180)
                        .onChange(of: log.lines.count) { proxy.scrollTo(log.lines.count - 1, anchor: .bottom) }
                    }
                }
                .font(.footnote)

                Text("\(settings.localeName(settings.speechLocale)) → \(settings.languageName(settings.nativeLanguage))")
                    .font(.subheadline).foregroundStyle(.secondary)

                Spacer()

                Button {
                    if engine.running { engine.stop() } else { Task { await engine.start() } }
                } label: {
                    Label(settings.t(engine.running ? "Stop" : "Start"), systemImage: engine.running ? "stop.fill" : "play.fill")
                        .font(.title3.bold())
                        .frame(maxWidth: .infinity, minHeight: 54)
                }
                .buttonStyle(.borderedProminent)
                .tint(engine.running ? .red : green.opacity(0.8))

                if engine.running {
                    Button {
                        if engine.dictating { engine.stopSay() } else { engine.startSay() }
                    } label: {
                        Label(settings.t(engine.dictating ? "Stop and translate" : "Say it in my language"),
                              systemImage: engine.dictating ? "checkmark.circle.fill" : "mic.badge.plus")
                            .frame(maxWidth: .infinity, minHeight: 44)
                    }
                    .buttonStyle(.bordered)
                    .tint(engine.dictating ? .orange : green)

                    HStack {
                        Button(settings.t(engine.paused ? "Resume" : "Pause")) { engine.togglePause() }
                        Spacer()
                        Button(settings.t("New conversation")) { engine.newConversation() }
                    }
                    .font(.subheadline)
                }
            }
            .padding()
            .navigationTitle("G1 Translator")
            .toolbar {
                Button { showSettings = true } label: { Image(systemName: "gearshape") }
            }
            .sheet(isPresented: $showSettings) { SettingsView() }
            .onAppear { if !settings.isConfigured { showSettings = true } }
        }
    }

    @ViewBuilder private var glassesStatus: some View {
        HStack {
            Image(systemName: "eyeglasses")
            switch glasses.state {
            case .idle: Text(settings.t("Glasses not connected"))
            case .scanning: Text(settings.t("Searching for G1…"))
            case .connecting: Text(settings.t("Connecting…"))
            case .connected: Text(settings.t("G1 connected")).foregroundStyle(green)
            case .failed(let msg): Text(settings.t(msg)).foregroundStyle(.orange)
            }
            Spacer()
            if glasses.state != .connected {
                Button(settings.t("Connect")) { glasses.connect() }.font(.subheadline)
            }
        }
        .font(.subheadline)
        if showNearby {
            VStack(alignment: .leading, spacing: 2) {
                Text(settings.t("Nearby Bluetooth devices")).font(.caption.bold())
                ForEach(glasses.nearby, id: \.self) { Text($0).font(.caption.monospaced()) }
            }
            .foregroundStyle(.secondary)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private var showNearby: Bool {
        guard !glasses.nearby.isEmpty else { return false }
        switch glasses.state {
        case .scanning, .failed: return true
        default: return false
        }
    }
}
