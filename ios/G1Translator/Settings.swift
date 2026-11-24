import Foundation
import Security
import Speech

/// User settings. The API key is stored in the Keychain, everything else in UserDefaults.
@MainActor
final class Settings: ObservableObject {
    private let d = UserDefaults.standard

    @Published var nativeLanguage: String { didSet { d.set(nativeLanguage, forKey: "native") } }
    @Published var speechLocale: String { didSet { d.set(speechLocale, forKey: "speechLocale") } }
    @Published var model: String { didSet { d.set(model, forKey: "model") } }
    @Published var replies: Bool { didSet { d.set(replies, forKey: "replies") } }
    @Published var followUps: Bool { didSet { d.set(followUps, forKey: "followUps") } }
    @Published var turnEnd: Double { didSet { d.set(turnEnd, forKey: "turnEnd") } }
    @Published var charsPerLine: Double { didSet { d.set(charsPerLine, forKey: "charsPerLine") } }
    @Published var appLanguage: String { didSet { d.set(appLanguage, forKey: "appLanguage") } }
    @Published var useGlassesMic: Bool { didSet { d.set(useGlassesMic, forKey: "glassesMic") } }
    @Published var apiKey: String { didSet { Keychain.save(apiKey, for: "apiKey") } }

    init() {
        let d = UserDefaults.standard
        let preferred = Locale.preferredLanguages.first.map { String($0.prefix(2)) } ?? "en"
        nativeLanguage = d.string(forKey: "native") ?? (Lang.supportedNative.contains(preferred) ? preferred : "en")
        speechLocale = d.string(forKey: "speechLocale") ?? "es-ES"
        model = d.string(forKey: "model") ?? ""
        replies = d.object(forKey: "replies") as? Bool ?? true
        followUps = d.object(forKey: "followUps") as? Bool ?? true
        turnEnd = d.object(forKey: "turnEnd") as? Double ?? 1.5
        charsPerLine = d.object(forKey: "charsPerLine") as? Double ?? 38
        useGlassesMic = d.object(forKey: "glassesMic") as? Bool ?? true
        appLanguage = d.string(forKey: "appLanguage") ?? "en"
        apiKey = Keychain.load("apiKey") ?? ""
    }

    /// App interface text in the chosen app language (English by default).
    func t(_ key: String) -> String { UIStrings.t(key, appLanguage) }

    /// Name of a language / locale in the app language.
    func languageName(_ code: String) -> String {
        Locale(identifier: appLanguage).localizedString(forLanguageCode: code)?.capitalized(with: Locale(identifier: appLanguage)) ?? code
    }

    func localeName(_ id: String) -> String {
        Locale(identifier: appLanguage).localizedString(forIdentifier: id) ?? id
    }

    /// The conversation language as an ISO code, e.g. "es" from "es-ES".
    var conversationLanguage: String { String(speechLocale.prefix(2)) }

    var isConfigured: Bool { !apiKey.isEmpty && !model.isEmpty }

    /// Locales the built-in speech recognizer supports, sorted by name.
    static var speechLocales: [String] {
        SFSpeechRecognizer.supportedLocales().map { $0.identifier.replacingOccurrences(of: "_", with: "-") }
            .sorted()
    }

    static func localeName(_ id: String) -> String {
        Locale.current.localizedString(forIdentifier: id) ?? id
    }
}

enum Keychain {
    private static let service = "g1translator"

    static func save(_ value: String, for key: String) {
        let base: [String: Any] = [kSecClass as String: kSecClassGenericPassword,
                                   kSecAttrService as String: service, kSecAttrAccount as String: key]
        SecItemDelete(base as CFDictionary)
        guard !value.isEmpty else { return }
        var add = base
        add[kSecValueData as String] = Data(value.utf8)
        add[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlock
        SecItemAdd(add as CFDictionary, nil)
    }

    static func load(_ key: String) -> String? {
        let q: [String: Any] = [kSecClass as String: kSecClassGenericPassword,
                                kSecAttrService as String: service, kSecAttrAccount as String: key,
                                kSecReturnData as String: true, kSecMatchLimit as String: kSecMatchLimitOne]
        var out: AnyObject?
        guard SecItemCopyMatching(q as CFDictionary, &out) == errSecSuccess, let data = out as? Data else { return nil }
        return String(data: data, encoding: .utf8)
    }
}
