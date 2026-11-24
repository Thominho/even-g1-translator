import SwiftUI

struct SettingsView: View {
    @EnvironmentObject var settings: Settings
    @Environment(\.dismiss) private var dismiss
    private let locales = Settings.speechLocales

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
                    TextField("Model ID", text: $settings.model)
                        .textInputAutocapitalization(.never).autocorrectionDisabled()
                } header: {
                    Text("Anthropic API")
                } footer: {
                    Text("Create a key in the Anthropic Console. Use a fast, low-cost model ID from the Anthropic docs. The key is stored in the iOS Keychain.")
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
        }
    }
}
