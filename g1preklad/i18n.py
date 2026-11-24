"""Languages and UI strings.

The *native language* (config `translator.native_language`) is the language you speak:
everything is translated into it, it is never translated itself, the pronunciation guide is
written with its spelling and the glasses UI uses it (English fallback).
"""
from __future__ import annotations

# English names – used in prompts and in the English UI
EN = {
    "en": "English", "es": "Spanish", "de": "German", "fr": "French", "it": "Italian",
    "pt": "Portuguese", "pl": "Polish", "cs": "Czech", "sk": "Slovak", "ru": "Russian",
    "uk": "Ukrainian", "nl": "Dutch", "hu": "Hungarian", "ro": "Romanian", "hr": "Croatian",
    "sl": "Slovenian", "sr": "Serbian", "bg": "Bulgarian", "el": "Greek", "tr": "Turkish",
    "sv": "Swedish", "da": "Danish", "no": "Norwegian", "nn": "Norwegian", "fi": "Finnish",
    "ja": "Japanese", "zh": "Chinese", "ko": "Korean", "ar": "Arabic", "he": "Hebrew",
    "hi": "Hindi", "vi": "Vietnamese", "th": "Thai", "id": "Indonesian", "gn": "Guarani",
}

# Czech names – the original Czech UI
CS = {
    "en": "angličtina", "es": "španělština", "de": "němčina", "fr": "francouzština",
    "it": "italština", "pt": "portugalština", "pl": "polština", "sk": "slovenština",
    "ru": "ruština", "uk": "ukrajinština", "nl": "nizozemština", "hu": "maďarština",
    "ro": "rumunština", "hr": "chorvatština", "sl": "slovinština", "sr": "srbština",
    "bg": "bulharština", "el": "řečtina", "tr": "turečtina", "sv": "švédština",
    "da": "dánština", "no": "norština", "nn": "norština", "fi": "finština", "ja": "japonština",
    "zh": "čínština", "ko": "korejština", "ar": "arabština", "he": "hebrejština",
    "hi": "hindština", "vi": "vietnamština", "th": "thajština", "id": "indonéština",
    "gn": "guaraní", "cs": "čeština",
}

# Endonyms – recognisable for every user, used for UI languages without their own table
ENDONYM = {
    "en": "English", "es": "Español", "de": "Deutsch", "fr": "Français", "it": "Italiano",
    "pt": "Português", "pl": "Polski", "cs": "Čeština", "sk": "Slovenčina", "ru": "Русский",
    "uk": "Українська", "nl": "Nederlands", "hu": "Magyar", "ro": "Română", "hr": "Hrvatski",
    "sl": "Slovenščina", "sr": "Српски", "bg": "Български", "el": "Ελληνικά", "tr": "Türkçe",
    "sv": "Svenska", "da": "Dansk", "no": "Norsk", "nn": "Norsk", "fi": "Suomi",
    "ja": "日本語", "zh": "中文", "ko": "한국어", "ar": "العربية", "he": "עברית",
    "hi": "हिन्दी", "vi": "Tiếng Việt", "th": "ไทย", "id": "Bahasa Indonesia", "gn": "Avañe'ẽ",
}

UI: dict[str, dict[str, str]] = {
    "en": {"yes": "YES", "no": "NO", "question": "QUESTION", "listening": "Listening…",
           "paused": "Paused", "new": "New conversation", "you_said": "You said",
           "no_replies": "No suggestions.", "error": "Error", "orig_on": "Original + translation",
           "orig_off": "Translation only", "start": "Translator → {lang}"},
    "cs": {"yes": "ANO", "no": "NE", "question": "OTÁZKA", "listening": "Poslouchám…",
           "paused": "Pauza", "new": "Nový rozhovor", "you_said": "Řekl jsi",
           "no_replies": "Žádné návrhy.", "error": "Chyba", "orig_on": "Originál + překlad",
           "orig_off": "Jen překlad", "start": "Překladač → {lang}"},
    "sk": {"yes": "ÁNO", "no": "NIE", "question": "OTÁZKA", "listening": "Počúvam…",
           "paused": "Pauza", "new": "Nový rozhovor", "you_said": "Povedal si",
           "no_replies": "Žiadne návrhy.", "error": "Chyba", "orig_on": "Originál + preklad",
           "orig_off": "Len preklad", "start": "Prekladač → {lang}"},
    "de": {"yes": "JA", "no": "NEIN", "question": "FRAGE", "listening": "Höre zu…",
           "paused": "Pause", "new": "Neues Gespräch", "you_said": "Du hast gesagt",
           "no_replies": "Keine Vorschläge.", "error": "Fehler", "orig_on": "Original + Übersetzung",
           "orig_off": "Nur Übersetzung", "start": "Übersetzer → {lang}"},
    "es": {"yes": "SÍ", "no": "NO", "question": "PREGUNTA", "listening": "Escuchando…",
           "paused": "Pausa", "new": "Nueva conversación", "you_said": "Has dicho",
           "no_replies": "Sin sugerencias.", "error": "Error", "orig_on": "Original + traducción",
           "orig_off": "Solo traducción", "start": "Traductor → {lang}"},
    "fr": {"yes": "OUI", "no": "NON", "question": "QUESTION", "listening": "J'écoute…",
           "paused": "Pause", "new": "Nouvelle conversation", "you_said": "Vous avez dit",
           "no_replies": "Aucune suggestion.", "error": "Erreur", "orig_on": "Original + traduction",
           "orig_off": "Traduction seule", "start": "Traducteur → {lang}"},
    "it": {"yes": "SÌ", "no": "NO", "question": "DOMANDA", "listening": "In ascolto…",
           "paused": "Pausa", "new": "Nuova conversazione", "you_said": "Hai detto",
           "no_replies": "Nessun suggerimento.", "error": "Errore", "orig_on": "Originale + traduzione",
           "orig_off": "Solo traduzione", "start": "Traduttore → {lang}"},
    "pt": {"yes": "SIM", "no": "NÃO", "question": "PERGUNTA", "listening": "Ouvindo…",
           "paused": "Pausa", "new": "Nova conversa", "you_said": "Você disse",
           "no_replies": "Sem sugestões.", "error": "Erro", "orig_on": "Original + tradução",
           "orig_off": "Só tradução", "start": "Tradutor → {lang}"},
    "pl": {"yes": "TAK", "no": "NIE", "question": "PYTANIE", "listening": "Słucham…",
           "paused": "Pauza", "new": "Nowa rozmowa", "you_said": "Powiedziałeś",
           "no_replies": "Brak propozycji.", "error": "Błąd", "orig_on": "Oryginał + tłumaczenie",
           "orig_off": "Tylko tłumaczenie", "start": "Tłumacz → {lang}"},
    "nl": {"yes": "JA", "no": "NEE", "question": "VRAAG", "listening": "Luisteren…",
           "paused": "Pauze", "new": "Nieuw gesprek", "you_said": "Je zei",
           "no_replies": "Geen suggesties.", "error": "Fout", "orig_on": "Origineel + vertaling",
           "orig_off": "Alleen vertaling", "start": "Vertaler → {lang}"},
}

# Reply kinds – accepts English keys and the original Czech ones
KIND_ALIASES = {"yes": "yes", "ano": "yes", "no": "no", "ne": "no",
                "question": "question", "otazka": "question", "otázka": "question"}


class Lang:
    def __init__(self, native: str = "en"):
        self.native = (native or "en").lower()
        self.ui = UI.get(self.native, UI["en"])

    def t(self, key: str, **kw) -> str:
        return self.ui.get(key, UI["en"][key]).format(**kw)

    def name(self, code: str | None) -> str:
        """Language name for the glasses UI."""
        c = code or ""
        if self.native == "cs":
            return CS.get(c, c.upper() or "?")
        if self.native == "en":
            return EN.get(c, c.upper() or "?")
        return ENDONYM.get(c, EN.get(c, c.upper() or "?"))

    def label(self, kind: str) -> str:
        k = KIND_ALIASES.get(kind, kind)
        return self.t(k) if k in ("yes", "no", "question") else kind.upper()


def english_name(code: str | None) -> str:
    return EN.get(code or "", code or "unknown")
