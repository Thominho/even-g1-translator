import SwiftUI

struct SettingsView: View {
    @EnvironmentObject var settings: Settings
    @Environment(\.dismiss) private var dismiss
    private let locales = Settings.speechLocales

    @State private var models: [LLMClient.Model] = []
    @State private var loadingModels = false
    @State private var modelError: String?

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Picker("They speak", selection: $settings.speechLocale) {
                        ForEach(locales, id: \.self) { Text(Settings.localeName($0)).tag($0) }
                    }
                    Picker("Your language", selection: $settings.nativeLanguage) {
                        ForEach(Lang.supportedNative, id: \.self) {
                            Text(Lang.displayName($0, in: Locale.current.identifier)).tag($0)
                        }
                    }
                } header: {
                    Text("Languages")
                } footer: {
                    Text("Speech is recognised by iOS on the device. Translations, pronunciation and the glasses display use your language.")
                }

                Section {
                    SecureField("API key", text: $settings.apiKey)
                        .textInputAutocapitalization(.never).autocorrectionDisabled()
                        .onSubmit { Task { await loadModels() } }
                    modelPicker
                } header: {
                    Text("Anthropic API")
                } footer: {
                    Text("Create a key in the Anthropic Console. The fastest low-cost model is selected by default. The key is stored in the iOS Keychain.")
                }

                Section {
                    Picker("Microphone", selection: $settings.useGlassesMic) {
                        Text("G1 glasses").tag(true)
                        Text("iPhone / AirPods").tag(false)
                    }
                } header: {
                    Text("Audio")
                } footer: {
                    Text("With the glasses microphone your iPhone can stay in your pocket.")
                }

                Section("Conversation") {
                    Toggle("Suggest replies", isOn: $settings.replies)
                    Toggle("Suggest questions to ask back", isOn: $settings.followUps)
                    VStack(alignment: .leading) {
                        Text("Pause before replies: \(settings.turnEnd, specifier: "%.1f") s")
                        Slider(value: $settings.turnEnd, in: 0.8...3, step: 0.1)
                    }
                }

                Section("Display") {
                    VStack(alignment: .leading) {
                        Text("Characters per line: \(Int(settings.charsPerLine))")
                        Slider(value: $settings.charsPerLine, in: 28...46, step: 1)
                    }
                }
            }
            .navigationTitle("Settings")
            .toolbar { Button("Done") { dismiss() } }
            .task { await loadModels() }
            .onChange(of: settings.apiKey) { _, key in
                if key.count > 20 { Task { await loadModels() } }
            }
        }
    }

    @ViewBuilder private var modelPicker: some View {
        if loadingModels {
            HStack { Text("Model"); Spacer(); ProgressView() }
        } else if !models.isEmpty {
            Picker("Model", selection: $settings.model) {
                ForEach(models) { Text($0.name).tag($0.id) }
                if !settings.model.isEmpty, !models.contains(where: { $0.id == settings.model }) {
                    Text(settings.model).tag(settings.model)
                }
            }
        } else {
            TextField("Model ID", text: $settings.model)
                .textInputAutocapitalization(.never).autocorrectionDisabled()
            if let modelError {
                Text(modelError).font(.footnote).foregroundStyle(.orange)
            }
            if !settings.apiKey.isEmpty {
                Button("Load models") { Task { await loadModels() } }
            }
        }
    }

    private func loadModels() async {
        guard !settings.apiKey.isEmpty, !loadingModels else { return }
        loadingModels = true
        defer { loadingModels = false }
        do {
            let list = try await LLMClient.listModels(apiKey: settings.apiKey)
            models = list
            modelError = nil
            if settings.model.isEmpty || !list.contains(where: { $0.id == settings.model }),
               let def = LLMClient.defaultModel(in: list) {
                settings.model = def.id
            }
        } catch {
            modelError = error.localizedDescription
        }
    }
}
