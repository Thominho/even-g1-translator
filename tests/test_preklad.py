import asyncio
import io
import json
import struct

from g1preklad.ai import Heard, Interpreter, parse_replies
from g1preklad.app import Translator, similar
from g1preklad.audio import AudioSource
from g1preklad.glasses import SimGlasses


def loud(ms=100):
    n = 16 * ms
    return struct.pack(f"<{n}h", *([3000, -3000] * (n // 2)))


def quiet(ms=100):
    return b"\x00\x00" * (16 * ms)


class FakeSTT:
    """Vrací předem dané (text, jazyk, pravděpodobnost)."""
    def __init__(self, items):
        self.items = list(items)
        self.calls = []

    async def hear(self, pcm, language=None):
        self.calls.append(language)
        t, lang, p = self.items.pop(0) if self.items else ("", None, None)
        return Heard(t, language or lang, p)


TR = {"¿Hola, de dónde eres?": "Ahoj, odkud jsi?", "¿Te gusta Paraguay?": "Líbí se ti Paraguay?",
      "Where is the station?": "Kde je nádraží?"}

REPLIES = json.dumps({"replies": [
    {"kind": "ano", "text": "Sí, me gusta mucho.", "pron": "sí, me gusta mučo", "cs": "Ano, moc."},
    {"kind": "ne", "text": "No mucho, la verdad.", "pron": "no mučo, la verdad", "cs": "Moc ne."},
    {"kind": "otazka", "text": "¿Y a ti?", "pron": "i a ti", "cs": "A tobě?"}]})


FOLLOWUPS = json.dumps({"followups": [
    [{"text": "¿Y a ti te gusta Praga?", "pron": "i a ti te gusta praga", "meaning": "A tobě se líbí Praha?"},
     {"text": "¿Cuánto tiempo vives aquí?", "pron": "kuanto tjempo bives aki", "meaning": "Jak dlouho tu žiješ?"},
     {"text": "¿Qué me recomiendas visitar?", "pron": "ke me rekomjendas visitar", "meaning": "Co mi doporučíš?"}],
    [], []]})


class FakeLLM:
    def __init__(self):
        self.calls = []

    async def chat(self, system, user, max_tokens=400):
        self.calls.append((system, user))
        if "follow-up questions" in system:
            return FOLLOWUPS
        if "JSON" in system:
            return "Tady jsou návrhy:\n" + REPLIES
        last = user.rsplit("\n", 1)[-1]
        return TR.get(last, f"<{last}>")


class FakeSource(AudioSource):
    def __init__(self):
        self.q = asyncio.Queue()

    async def frames(self):
        while True:
            yield await self.q.get()


def make(cfg=None, items=()):
    g = SimGlasses(interactive=False, out=io.StringIO())
    src = FakeSource()
    llm = FakeLLM()
    cfg = cfg or {"translator": {"turn_end_s": 0.15, "native_language": "cs"}}
    t = Translator(g, FakeSTT(items), Interpreter(llm, "cs"), cfg, source=src)
    return t, g, src, llm


async def speak(src, sentences=1, gap_ms=1000):
    for _ in range(sentences):
        for _ in range(8):
            await src.q.put(loud())
        for _ in range(gap_ms // 100):
            await src.q.put(quiet())
    await asyncio.sleep(0.05)


def test_parse_replies_with_noise():
    rs = parse_replies("blabla " + REPLIES + " konec")
    assert [r.kind for r in rs] == ["yes", "no", "question"]
    assert rs[0].meaning == "Ano, moc."
    assert rs[0].pron == "sí, me gusta mučo"
    assert parse_replies("nic") == []


def test_similar():
    assert similar("Sí, me gusta mucho.", "si me gusta mucho") > 0.9
    assert similar("Sí, me gusta mucho.", "Dónde está el baño") < 0.6


async def test_full_flow_spanish():
    t, g, src, llm = make(items=[("¿Hola, de dónde eres?", "es", 0.98),
                                 ("¿Te gusta Paraguay?", "es", 0.95)])
    await t.start()
    await speak(src, 1, gap_ms=900)     # první věta, krátká pauza (nedomluvil)
    await asyncio.sleep(0.05)
    assert "[ŠPANĚLŠTINA]\nAhoj, odkud jsi?" in g.screens[-1]   # jazyk u první věty
    await speak(src, 1, gap_ms=900)
    await asyncio.sleep(0.4)            # domluvil → návrhy
    screens = "\n".join(g.screens)
    assert "Ahoj, odkud jsi? Líbí se ti Paraguay?" in screens
    assert g.screens[-1] == "ANO 1/3: Ano, moc.\n> sí, me gusta mučo"
    await g.press("d")
    assert g.screens[-1].startswith("NE 2/3")
    await g.press("d")
    assert g.screens[-1].startswith("OTÁZKA 3/3")
    await g.press("a")
    assert g.screens[-1].startswith("NE 2/3")
    # kontext rozhovoru šel do LLM
    assert "Spanish" in llm.calls[-1][0] and "native Czech" in llm.calls[-1][0]
    await t.stop()


async def test_czech_ignored_and_own_reply_not_translated():
    t, g, src, llm = make(items=[("¿Te gusta Paraguay?", "es", 0.95),
                                 ("Dobře, tak jdeme.", "cs", 0.99),
                                 ("Si me gusta mucho", "es", 0.9)])
    await t.start()
    await speak(src, 1)
    await asyncio.sleep(0.4)
    assert g.screens[-1].startswith("ANO 1/3")
    await speak(src, 1)                  # česky → nic
    assert g.screens[-1].startswith("ANO 1/3")
    await speak(src, 1)                  # Tomáš přečetl návrh ANO → nabídnou se otázky
    assert g.screens[-1] == "ZEPTEJ SE 1/3: A tobě se líbí Praha?\n> i a ti te gusta praga"
    await g.press("d")
    assert g.screens[-1].startswith("ZEPTEJ SE 2/3: Jak dlouho tu žiješ?")
    assert len([c for c in llm.calls if "JSON" not in c[0]]) == 1   # překládala se jen 1 věta
    fu = next(c for c in llm.calls if "follow-up questions" in c[0])
    assert "Sí, me gusta mucho." in fu[1] and "same question back" in fu[0]
    await t.stop()


async def test_language_switch_and_uncertain_detection():
    t, g, src, llm = make(items=[("¿Te gusta Paraguay?", "es", 0.95),
                                 ("Si", "pt", 0.4), ("Sí", "es", None),      # nejisté → znovu s es
                                 ("Where is the station?", "en", 0.97)])
    await t.start()
    await speak(src, 1)
    await speak(src, 1)
    assert t.stt.calls[1:3] == [None, "es"]
    assert t.lang == "es"
    await speak(src, 1)
    await asyncio.sleep(0.05)
    assert "[ANGLIČTINA]\nKde je nádraží?" in "\n".join(g.screens)
    await t.stop()


async def test_double_tap_new_conversation_and_pause():
    t, g, src, llm = make(items=[("¿Te gusta Paraguay?", "es", 0.95)])
    await t.start()
    await speak(src, 1)
    await asyncio.sleep(0.4)
    await g.press("aa")                  # zavřít návrhy
    assert g.screens[-1] == "Poslouchám…"
    await g.press("aa")                  # nový rozhovor
    assert t.lang is None
    await g.press("ttt")
    assert t.paused
    await t.stop()


async def test_no_replies_when_disabled():
    t, g, src, llm = make({"translator": {"turn_end_s": 0.1, "replies": False}},
                          items=[("¿Te gusta Paraguay?", "es", 0.95)])
    await t.start()
    await speak(src, 1)
    await asyncio.sleep(0.3)
    assert not any("JSON" in c[0] for c in llm.calls)
    await t.stop()


class SlowLLM(FakeLLM):
    async def chat(self, system, user, max_tokens=400):
        if "JSON" in system:
            await asyncio.sleep(0.4)
        return await super().chat(system, user, max_tokens)


async def _time_to_replies(prefetch):
    g = SimGlasses(interactive=False, out=io.StringIO())
    times = []
    orig = g._send_page

    async def rec(text, page, total):
        times.append((asyncio.get_running_loop().time(), text))
        await orig(text, page, total)
    g._send_page = rec
    src = FakeSource()
    llm = SlowLLM()
    t = Translator(g, FakeSTT([("¿Te gusta Paraguay?", "es", 0.95)]), Interpreter(llm),
                   {"translator": {"turn_end_s": 0.3, "prefetch_replies": prefetch, "native_language": "cs"}}, source=src)
    await t.start()
    await speak(src, 1, gap_ms=900)
    await asyncio.sleep(1.0)
    await t.stop()
    tr = next(ts for ts, x in times if "Líbí se ti" in x)
    rp = next(ts for ts, x in times if x.startswith("ANO 1/3"))
    n_reply_calls = sum("very short replies" in c[0] for c in llm.calls)
    return rp - tr, n_reply_calls


async def test_prefetch_makes_replies_faster():
    slow, _ = await _time_to_replies(False)
    fast, calls = await _time_to_replies(True)
    assert slow >= 0.65          # 0.3 s ticho + 0.4 s generování
    assert fast < 0.45           # odpovědi hotové už během ticha
    assert calls == 1            # nic se negeneruje dvakrát


EN_REPLIES = json.dumps({"replies": [
    {"kind": "yes", "text": "Sí, me gusta mucho.", "pron": "see, meh GOOS-tah MOO-choh", "meaning": "Yes, I really like it."},
    {"kind": "no", "text": "No mucho.", "pron": "noh MOO-choh", "meaning": "Not much."},
    {"kind": "question", "text": "¿Y a ti?", "pron": "ee ah TEE", "meaning": "And you?"}]})


class EnLLM(FakeLLM):
    async def chat(self, system, user, max_tokens=400):
        self.calls.append((system, user))
        return EN_REPLIES if "JSON" in system else "Do you like Paraguay?"


async def test_english_native_language():
    g = SimGlasses(interactive=False, out=io.StringIO())
    src = FakeSource()
    llm = EnLLM()
    t = Translator(g, FakeSTT([("¿Te gusta Paraguay?", "es", 0.95), ("I like it", "en", 0.99)]),
                   Interpreter(llm, "en"), {"translator": {"turn_end_s": 0.15}}, source=src)
    assert "en" in t.ignore                      # výchozí rodný jazyk = angličtina
    await t.start()
    assert g.screens[0].startswith("Translator → English")
    await speak(src, 1)
    await asyncio.sleep(0.4)
    assert "[SPANISH]\nDo you like Paraguay?" in "\n".join(g.screens)
    assert g.screens[-1] == "YES 1/3: Yes, I really like it.\n> see, meh GOOS-tah MOO-choh"
    assert "native English speaker" in llm.calls[-1][0]
    await speak(src, 1)                          # angličtina se nepřekládá
    assert g.screens[-1].startswith("YES 1/3")
    await t.stop()


def test_ui_fallback_and_endonyms():
    from g1preklad.i18n import Lang
    assert Lang("de").label("question") == "FRAGE"
    assert Lang("de").name("es") == "Español"
    assert Lang("ja").t("listening") == "Listening…"   # neznámý UI jazyk → angličtina
    assert Lang("cs").name("es") == "španělština"


async def test_followup_question_read_aloud_and_no_followups_fallback():
    t, g, src, llm = make(items=[("¿Te gusta Paraguay?", "es", 0.95),
                                 ("No mucho, la verdad", "es", 0.9)])
    await t.start()
    await speak(src, 1)
    await asyncio.sleep(0.4)
    await speak(src, 1)                  # přečetl NE – pro něj LLM otázky nemá → "Řekl jsi"
    assert g.screens[-1].startswith("Řekl jsi: Moc ne.")
    assert t.replies == [] and t.mode == "reply"
    await t.stop()
