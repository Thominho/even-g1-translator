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
                    Picker(settings.t("They speak"), selection: $settings.speechLocale) {
                        ForEach(locales.sorted { settings.localeName($0) < settings.localeName($1) }, id: \.self) {
                            Text(settings.localeName($0)).tag($0)
                        }
                    }
                    Picker(settings.t("Your language"), selection: $settings.nativeLanguage) {
                        ForEach(Lang.supportedNative, id: \.self) { Text(settings.languageName($0)).tag($0) }
                    }
                    Picker(settings.t("App language"), selection: $settings.appLanguage) {
                        ForEach(Lang.supportedNative, id: \.self) {
                            Text(Lang.displayName($0, in: $0)).tag($0)
                        }
                    }
                } header: {
                    Text(settings.t("Languages"))
                } footer: {
                    Text(settings.t("Speech is recognised by iOS on the device. Translations, pronunciation and the glasses display use your language."))
                }

                Section {
                    SecureField(settings.t("API key"), text: $settings.apiKey)
                        .textInputAutocapitalization(.never).autocorrectionDisabled()
                        .onSubmit { Task { await loadModels() } }
                    modelPicker
                } header: {
                    Text("Anthropic API")
                } footer: {
                    Text(settings.t("Create a key in the Anthropic Console. The fastest low-cost model is selected by default. The key is stored in the iOS Keychain."))
                }

                Section {
                    Picker(settings.t("Microphone"), selection: $settings.micMode) {
                        Text(settings.t("Automatic (best)")).tag("auto")
                        Text(settings.t("G1 glasses")).tag("glasses")
                        Text(settings.t("iPhone / AirPods")).tag("phone")
                    }
                    Toggle(settings.t("Better recognition (online)"), isOn: $settings.onlineRecognition)
                } header: {
                    Text(settings.t("Audio"))
                } footer: {
                    Text(settings.t("Automatic listens with both microphones and uses the one that hears the speaker better. Online recognition is more accurate in noise but needs internet."))
                }

                Section {
                    TextField(settings.t("e.g. Czech couple on holiday in Paraguay"), text: $settings.aboutMe, axis: .vertical)
                        .lineLimit(2...4)
                } header: {
                    Text(settings.t("About me"))
                } footer: {
                    Text(settings.t("Who you are and where you are. Translations and replies take it into account."))
                }

                Section {
                    if settings.ownVoiceLevel > 0 {
                        Label(settings.t("Your voice is learned – your own words are not translated."), systemImage: "checkmark.circle")
                        Button(settings.t("Forget my voice"), role: .destructive) { settings.ownVoiceLevel = 0 }
                    } else {
                        Text(settings.t("Tap “Learn my voice” on the main screen and say a few words with the glasses on – then your own words are not translated."))
                            .font(.footnote)
                    }
                } header: {
                    Text(settings.t("My voice"))
                }

                Section(settings.t("Conversation")) {
                    Toggle(settings.t("Suggest replies"), isOn: $settings.replies)
                    Toggle(settings.t("Suggest questions to ask back"), isOn: $settings.followUps)
                    VStack(alignment: .leading) {
                        Text(settings.t("Pause before replies") + ": " + String(format: "%.1f s", settings.turnEnd))
                        Slider(value: $settings.turnEnd, in: 0.8...3, step: 0.1)
                    }
                }

                Section(settings.t("Display")) {
                    Toggle(settings.t("Replies in boxes (more room)"), isOn: $settings.boxes)
                    VStack(alignment: .leading) {
                        Text(settings.t("Characters per line") + ": \(Int(settings.charsPerLine))")
                        Slider(value: $settings.charsPerLine, in: 28...46, step: 1)
                    }
                }
            }
            .navigationTitle(settings.t("Settings"))
            .toolbar { Button(settings.t("Done")) { dismiss() } }
            .task { await loadModels() }
            .onChange(of: settings.apiKey) { _, key in
                if key.count > 20 { Task { await loadModels() } }
            }
        }
    }

    @ViewBuilder private var modelPicker: some View {
        if loadingModels {
            HStack { Text(settings.t("Model")); Spacer(); ProgressView() }
        } else if !models.isEmpty {
            Picker(settings.t("Model"), selection: $settings.model) {
                ForEach(models) { Text($0.name).tag($0.id) }
                if !settings.model.isEmpty, !models.contains(where: { $0.id == settings.model }) {
                    Text(settings.model).tag(settings.model)
                }
            }
        } else {
            TextField(settings.t("Model ID"), text: $settings.model)
                .textInputAutocapitalization(.never).autocorrectionDisabled()
            if let modelError {
                Text(modelError).font(.footnote).foregroundStyle(.orange)
            }
            if !settings.apiKey.isEmpty {
                Button(settings.t("Load models")) { Task { await loadModels() } }
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
