import Foundation

/// Native language: translations go into it, pronunciation is spelled for it, the glasses UI uses it.
struct Lang {
    let code: String

    static let english: [String: String] = [
        "en": "English", "es": "Spanish", "de": "German", "fr": "French", "it": "Italian",
        "pt": "Portuguese", "pl": "Polish", "cs": "Czech", "sk": "Slovak", "ru": "Russian",
        "uk": "Ukrainian", "nl": "Dutch", "hu": "Hungarian", "ro": "Romanian", "hr": "Croatian",
        "sv": "Swedish", "da": "Danish", "nb": "Norwegian", "fi": "Finnish", "tr": "Turkish",
        "el": "Greek", "ja": "Japanese", "zh": "Chinese", "ko": "Korean", "ar": "Arabic",
        "he": "Hebrew", "hi": "Hindi", "vi": "Vietnamese", "th": "Thai", "id": "Indonesian",
    ]
    static let czech: [String: String] = [
        "en": "angličtina", "es": "španělština", "de": "němčina", "fr": "francouzština",
        "it": "italština", "pt": "portugalština", "pl": "polština", "cs": "čeština",
        "sk": "slovenština", "ru": "ruština", "uk": "ukrajinština", "nl": "nizozemština",
        "hu": "maďarština", "ro": "rumunština", "hr": "chorvatština", "sv": "švédština",
        "da": "dánština", "nb": "norština", "fi": "finština", "tr": "turečtina", "el": "řečtina",
        "ja": "japonština", "zh": "čínština", "ko": "korejština", "ar": "arabština",
        "he": "hebrejština", "hi": "hindština", "vi": "vietnamština", "th": "thajština",
        "id": "indonéština",
    ]

    static let supportedNative = ["en", "cs", "sk", "de", "es", "fr", "it", "pt", "pl", "nl"]

    private static let ui: [String: [String: String]] = [
        "en": ["say": "SAY", "speak": "Speak…", "ask": "ASK", "listening": "Listening…", "paused": "Paused", "new": "New conversation",
               "you_said": "You said", "start": "Translator → {lang}", "calib": "Say a few words…", "calib_ok": "Voice learned ✓"],
        "cs": ["say": "ŘEKNI", "speak": "Mluv…", "ask": "ZEPTEJ SE", "listening": "Poslouchám…", "paused": "Pauza", "new": "Nový rozhovor",
               "you_said": "Řekl jsi", "start": "Překladač → {lang}", "calib": "Řekni pár slov…", "calib_ok": "Hlas naučen ✓"],
        "sk": ["say": "POVEDZ", "speak": "Hovor…", "ask": "OPÝTAJ SA", "listening": "Počúvam…", "paused": "Pauza", "new": "Nový rozhovor",
               "you_said": "Povedal si", "start": "Prekladač → {lang}", "calib": "Povedz pár slov…", "calib_ok": "Hlas naučený ✓"],
        "de": ["say": "SAG", "speak": "Sprich…", "ask": "FRAG", "listening": "Höre zu…", "paused": "Pause", "new": "Neues Gespräch",
               "you_said": "Du hast gesagt", "start": "Übersetzer → {lang}", "calib": "Sag ein paar Worte…", "calib_ok": "Stimme gelernt ✓"],
        "es": ["say": "DI", "speak": "Habla…", "ask": "PREGUNTA", "listening": "Escuchando…", "paused": "Pausa", "new": "Nueva conversación",
               "you_said": "Has dicho", "start": "Traductor → {lang}", "calib": "Di unas palabras…", "calib_ok": "Voz aprendida ✓"],
        "fr": ["say": "DIS", "speak": "Parle…", "ask": "DEMANDE", "listening": "J'écoute…", "paused": "Pause", "new": "Nouvelle conversation",
               "you_said": "Vous avez dit", "start": "Traducteur → {lang}", "calib": "Dis quelques mots…", "calib_ok": "Voix apprise ✓"],
        "it": ["say": "DI'", "speak": "Parla…", "ask": "CHIEDI", "listening": "In ascolto…", "paused": "Pausa", "new": "Nuova conversazione",
               "you_said": "Hai detto", "start": "Traduttore → {lang}", "calib": "Di' qualche parola…", "calib_ok": "Voce appresa ✓"],
        "pt": ["say": "DIGA", "speak": "Fale…", "ask": "PERGUNTE", "listening": "Ouvindo…", "paused": "Pausa", "new": "Nova conversa",
               "you_said": "Você disse", "start": "Tradutor → {lang}", "calib": "Diga algumas palavras…", "calib_ok": "Voz aprendida ✓"],
        "pl": ["say": "POWIEDZ", "speak": "Mów…", "ask": "ZAPYTAJ", "listening": "Słucham…", "paused": "Pauza", "new": "Nowa rozmowa",
               "you_said": "Powiedziałeś", "start": "Tłumacz → {lang}", "calib": "Powiedz kilka słów…", "calib_ok": "Głos nauczony ✓"],
        "nl": ["say": "ZEG", "speak": "Spreek…", "ask": "VRAAG", "listening": "Luisteren…", "paused": "Pauze", "new": "Nieuw gesprek",
               "you_said": "Je zei", "start": "Vertaler → {lang}", "calib": "Zeg een paar woorden…", "calib_ok": "Stem geleerd ✓"],
    ]

    func t(_ key: String, lang: String = "") -> String {
        let s = Self.ui[code]?[key] ?? Self.ui["en"]![key] ?? key
        return s.replacingOccurrences(of: "{lang}", with: lang)
    }

    /// Name of a language for the glasses UI.
    func name(_ other: String) -> String {
        if code == "cs" { return Self.czech[other] ?? other.uppercased() }
        if code == "en" { return Self.english[other] ?? other.uppercased() }
        let endonym = Locale(identifier: other).localizedString(forLanguageCode: other)
        return endonym?.capitalized ?? Self.english[other] ?? other.uppercased()
    }

    /// Name of the language as it is called in this native language (for settings).
    static func displayName(_ code: String, in ui: String) -> String {
        Locale(identifier: ui).localizedString(forLanguageCode: code)?.capitalized ?? code
    }

    static func englishName(_ code: String) -> String { english[code] ?? code }

    /// Speech recognition locale for dictating in the native language.
    static func speechLocale(_ code: String) -> String {
        ["en": "en-US", "cs": "cs-CZ", "sk": "sk-SK", "de": "de-DE", "es": "es-ES", "fr": "fr-FR",
         "it": "it-IT", "pt": "pt-BR", "pl": "pl-PL", "nl": "nl-NL"][code] ?? code
    }
}
