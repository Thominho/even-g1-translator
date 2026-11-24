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
                .preferredColorScheme(.dark)
        }
    }
}

struct ContentView: View {
    @EnvironmentObject var settings: Settings
    @EnvironmentObject var glasses: G1Glasses
    @EnvironmentObject var engine: TranslatorEngine
    @State private var showSettings = false

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

                if !engine.status.isEmpty {
                    Text(engine.status).font(.footnote).foregroundStyle(.orange)
                }

                Text("\(Settings.localeName(settings.speechLocale)) → \(Lang.displayName(settings.nativeLanguage, in: Locale.current.identifier))")
                    .font(.subheadline).foregroundStyle(.secondary)

                Spacer()

                Button {
                    if engine.running { engine.stop() } else { Task { await engine.start() } }
                } label: {
                    Label(engine.running ? "Stop" : "Start", systemImage: engine.running ? "stop.fill" : "play.fill")
                        .font(.title3.bold())
                        .frame(maxWidth: .infinity, minHeight: 54)
                }
                .buttonStyle(.borderedProminent)
                .tint(engine.running ? .red : green.opacity(0.8))

                if engine.running {
                    HStack {
                        Button(engine.paused ? "Resume" : "Pause") { engine.togglePause() }
                        Spacer()
                        Button("New conversation") { engine.newConversation() }
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
            case .idle: Text("Glasses not connected")
            case .scanning: Text("Searching for G1…")
            case .connecting: Text("Connecting…")
            case .connected: Text("G1 connected").foregroundStyle(green)
            case .failed(let msg): Text(msg).foregroundStyle(.orange)
            }
            Spacer()
            if glasses.state != .connected {
                Button("Connect") { glasses.connect() }.font(.subheadline)
            }
        }
        .font(.subheadline)
    }
}
