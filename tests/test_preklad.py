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


class FakeLLM:
    def __init__(self):
        self.calls = []

    async def chat(self, system, user, max_tokens=400):
        self.calls.append((system, user))
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
    cfg = cfg or {"translator": {"turn_end_s": 0.15}}
    t = Translator(g, FakeSTT(items), Interpreter(llm), cfg, source=src)
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
    assert [r.kind for r in rs] == ["ano", "ne", "otazka"]
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
    # kontext rozhovoru šel do Claude
    assert "španělština" in llm.calls[-1][0]
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
    await speak(src, 1)                  # Tomáš přečetl návrh
    assert g.screens[-1].startswith("Řekl jsi: Ano, moc.")
    assert len([c for c in llm.calls if "JSON" not in c[0]]) == 1   # překládala se jen 1 věta
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
