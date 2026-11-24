"""Hlavní logika: poslouchá, cizí řeč překládá do češtiny, po domluvení nabídne odpovědi.

Ovládání na brýlích:
  ťuk P / L      – další / předchozí návrh odpovědi (když jsou zobrazené)
  dvojťuk        – zavřít návrhy / nový rozhovor (zapomene jazyk)
  podržet P      – ukázat znovu návrhy odpovědí
  ťuk L (bez návrhů) – přepnout zobrazení originálu
  trojťuk        – pauza / pokračovat
"""
from __future__ import annotations

import argparse
import asyncio
import difflib
import logging
import re
import signal
import sys
import time
import tomllib
from pathlib import Path

from . import protocol as P
from .ai import Interpreter, KIND_LABEL, Reply, lang_name, make_llm, make_stt
from .audio import Segmenter, make_source
from .glasses import BleGlasses, SimGlasses

log = logging.getLogger("g1preklad")
HOME_LANG = "cs"


def _norm(s: str) -> str:
    return re.sub(r"[^\w ]", "", s.lower()).strip()


def similar(a: str, b: str) -> float:
    return difflib.SequenceMatcher(None, _norm(a), _norm(b)).ratio()


class Translator:
    def __init__(self, glasses, stt, interp: Interpreter, cfg: dict, source=None):
        self.g = glasses
        self.stt = stt
        self.interp = interp
        c = cfg.get("translator", {})
        a = cfg.get("audio", {})
        self.turn_end_s = float(c.get("turn_end_s", 1.5))
        self.reset_after_s = float(c.get("new_conversation_after_s", 90))
        self.show_original = bool(c.get("show_original", False))
        self.min_prob = float(c.get("min_language_probability", 0.6))
        self.replies_enabled = bool(c.get("replies", True))
        self.show_spelling = bool(c.get("show_spelling", False))
        self.ignore = set(c.get("ignore_languages", [HOME_LANG]))
        self.seg = Segmenter(threshold=float(a.get("threshold", 500)),
                             silence_s=float(c.get("sentence_pause_s", 0.7)))
        self.source = source or make_source(a.get("source", "mac"), glasses)
        self.queue: asyncio.Queue[bytes] = asyncio.Queue(maxsize=10)

        self.lang: str | None = None           # jazyk aktuálního rozhovoru
        self.turn_orig: list[str] = []         # co právě říká (originál)
        self.turn_cs: list[str] = []           # …a česky
        self.history: list[str] = []           # celý rozhovor pro kontext
        self.replies: list[Reply] = []
        self.reply_idx = 0
        self.showing_replies = False
        self.paused = False
        self.last_speech = 0.0
        self._turn_timer: asyncio.Task | None = None
        self._tasks: list[asyncio.Task] = []

    # --------------------------------------------------------------- zvuk
    def on_audio(self, pcm: bytes) -> None:
        if self.paused:
            return
        was = self.seg.speaking
        for kind, seg in self.seg.feed(pcm):
            if kind == "final":
                try:
                    self.queue.put_nowait(seg)
                except asyncio.QueueFull:
                    log.warning("nestíhám – zahazuji úsek")
        if self.seg.speaking and not was:
            self._cancel_turn_timer()   # mluví dál → ještě nedomluvil

    async def _pump(self) -> None:
        async for pcm in self.source.frames():
            self.on_audio(pcm)

    async def _worker(self) -> None:
        while True:
            pcm = await self.queue.get()
            try:
                await self.handle_segment(pcm)
            except Exception as e:
                log.exception("chyba při zpracování")
                await self.g.show(f"Chyba: {e}")

    # --------------------------------------------------------------- logika
    async def handle_segment(self, pcm: bytes) -> None:
        now = time.monotonic()
        if self.lang and now - self.last_speech > self.reset_after_s:
            self.new_conversation()
        heard = await self.stt.hear(pcm)
        # nejistá detekce u krátké věty → drž jazyk rozhovoru
        if (self.lang and heard.lang != self.lang and heard.prob is not None
                and heard.prob < self.min_prob):
            heard = await self.stt.hear(pcm, self.lang)
            heard.lang = self.lang
        text = heard.text.strip()
        if not text or len(_norm(text)) < 2:
            return
        if heard.lang in self.ignore:
            log.info("[%s] %s – ignoruji (čeština)", heard.lang, text)
            return
        # Tomáš právě nahlas přečetl jeden z návrhů → nepřekládat
        if self.replies:
            best = max(self.replies, key=lambda r: similar(r.text, text))
            if similar(best.text, text) >= 0.6:
                self.history.append(f"Já: {best.text}")
                self.replies = []
                self.showing_replies = False
                await self.g.show(f"Řekl jsi: {best.cs or best.text}\nPoslouchám…")
                return

        self.last_speech = time.monotonic()
        first = self.lang is None or heard.lang != self.lang
        if first:
            self.lang = heard.lang
            self.turn_orig, self.turn_cs = [], []
        self.showing_replies = False
        self.replies = []

        cs = await self.interp.translate(text, self.lang, self.history)
        self.turn_orig.append(text)
        self.turn_cs.append(cs)
        self.history.append(f"On/ona: {text} ({cs})")
        await self.draw_turn(header=first)
        self._schedule_turn_end()

    def _header(self) -> str:
        return f"[{lang_name(self.lang).upper()}]"

    async def draw_turn(self, header: bool = False) -> None:
        if self.show_original:
            body = "\n".join(f"{o}\n= {c}" for o, c in zip(self.turn_orig[-2:], self.turn_cs[-2:]))
        else:
            body = " ".join(self.turn_cs)
        text = f"{self._header()}\n{body}" if header or len(self.turn_cs) == 1 else body
        await self.g.show_tail(text)

    # ------------------------------------------------------- konec promluvy
    def _cancel_turn_timer(self) -> None:
        if self._turn_timer and not self._turn_timer.done():
            self._turn_timer.cancel()

    def _schedule_turn_end(self) -> None:
        self._cancel_turn_timer()
        if self.replies_enabled:
            self._turn_timer = asyncio.create_task(self._turn_end())

    async def _turn_end(self) -> None:
        await asyncio.sleep(self.turn_end_s)
        if self.seg.speaking or not self.queue.empty() or not self.turn_orig:
            return
        turn = " ".join(self.turn_orig)
        try:
            replies = await self.interp.replies(turn, self.lang, self.history[:-len(self.turn_orig)])
        except Exception:
            log.exception("návrhy odpovědí selhaly")
            return
        if self.seg.speaking or not self.queue.empty():
            return  # mezitím začal zase mluvit
        self.replies, self.reply_idx = replies, 0
        self.turn_orig, self.turn_cs = [], []
        if replies:
            await self.show_reply()

    async def show_reply(self) -> None:
        if not self.replies:
            await self.g.show("Žádné návrhy.")
            return
        self.showing_replies = True
        r = self.replies[self.reply_idx]
        label = KIND_LABEL.get(r.kind, r.kind.upper())
        # nahoře česky, pod tím odpověď v jazyce mluvčího a výslovnost
        head = f"{label} {self.reply_idx + 1}/{len(self.replies)}"
        lines = [f"{head}: {r.cs}" if r.cs else head]
        lines.append(f"> {r.pron}" if r.pron else f"> {r.text}")
        if self.show_spelling and r.pron:
            lines.append(f"({r.text})")
        await self.g.show("\n".join(lines))

    def new_conversation(self) -> None:
        self.lang = None
        self.turn_orig, self.turn_cs, self.history = [], [], []
        self.replies, self.showing_replies = [], False

    # --------------------------------------------------------------- ovládání
    async def on_event(self, ev: P.GlassesEvent) -> None:
        e = ev.event
        if e == P.Event.TRIPLE_TAP:
            self.paused = not self.paused
            self.seg.reset()
            await self.g.show("Pauza" if self.paused else "Poslouchám…")
        elif e == P.Event.SINGLE_TAP and self.showing_replies and self.replies:
            step = 1 if ev.side == "R" else -1
            self.reply_idx = (self.reply_idx + step) % len(self.replies)
            await self.show_reply()
        elif e == P.Event.SINGLE_TAP and ev.side == "L":
            self.show_original = not self.show_original
            await self.g.show("Zobrazuji originál + překlad" if self.show_original else "Jen překlad")
        elif e == P.Event.SINGLE_TAP and ev.side == "R" and self.turn_cs:
            await self.draw_turn(header=True)
        elif e == P.Event.DOUBLE_TAP:
            if self.showing_replies:
                self.showing_replies = False
                await self.g.show("Poslouchám…")
            else:
                self.new_conversation()
                await self.g.show("Nový rozhovor\nPoslouchám…")
        elif e == P.Event.LONG_PRESS and ev.side == "R" and self.replies:
            await self.show_reply()
        elif e == P.Event.HEAD_UP and self.showing_replies:
            await self.show_reply()

    # --------------------------------------------------------------- běh
    async def start(self) -> None:
        self.g.on_event(self.on_event)
        await self.source.start()
        self._tasks = [asyncio.create_task(self._pump()), asyncio.create_task(self._worker())]
        await self.g.show("Překladač → čeština\nPoslouchám…")

    async def stop(self) -> None:
        self._cancel_turn_timer()
        for t in self._tasks:
            t.cancel()
        await self.source.stop()


# =========================================================================== CLI

DEFAULT_CONFIG = Path(__file__).resolve().parent.parent / "config.toml"


def load_config(path: str | None) -> dict:
    p = Path(path) if path else DEFAULT_CONFIG
    if not p.exists():
        p = p.with_name("config.example.toml")
    if not p.exists():
        return {}
    with p.open("rb") as f:
        return tomllib.load(f)


async def _run(args) -> None:
    cfg = load_config(args.config)
    gc = cfg.get("glasses", {})
    cpl = float(gc.get("chars_per_line", 38))
    g = SimGlasses(cpl) if args.sim else BleGlasses(cpl, heartbeat_s=float(gc.get("heartbeat_s", 8)),
                                                     channel=gc.get("channel"))
    stt = make_stt(cfg.get("stt", {}))
    interp = Interpreter(make_llm(cfg.get("llm", {})))
    await g.connect()
    t = Translator(g, stt, interp, cfg)
    await t.start()
    stop = asyncio.Event()
    loop = asyncio.get_running_loop()
    for s in (signal.SIGINT, signal.SIGTERM):
        try:
            loop.add_signal_handler(s, stop.set)
        except NotImplementedError:  # pragma: no cover
            pass
    waits = [asyncio.create_task(stop.wait())]
    if isinstance(g, SimGlasses):
        waits.append(asyncio.create_task(g.quit.wait()))
    await asyncio.wait(waits, return_when=asyncio.FIRST_COMPLETED)
    await t.stop()
    await g.close()


async def _demo(args) -> None:
    """Otestuje Claude bez mikrofonu: přeloží větu a navrhne odpovědi."""
    cfg = load_config(args.config)
    interp = Interpreter(make_llm(cfg.get("llm", {})))
    g = SimGlasses(interactive=False)
    print("Překlad:", await interp.translate(args.text, args.lang, []))
    for r in await interp.replies(args.text, args.lang, []):
        print(f"- {KIND_LABEL.get(r.kind, r.kind)}: {r.text}  [{r.pron}]  = {r.cs}")
    del g


def main(argv: list[str] | None = None) -> None:
    ap = argparse.ArgumentParser(prog="g1preklad", description="Překladač do češtiny pro Even G1")
    ap.add_argument("-c", "--config")
    ap.add_argument("-v", "--verbose", action="store_true")
    sub = ap.add_subparsers(dest="cmd")
    r = sub.add_parser("run", help="spustit překladač")
    r.add_argument("--sim", action="store_true", help="simulátor v terminálu místo brýlí")
    d = sub.add_parser("demo", help="test Claude: přeložit text a navrhnout odpovědi")
    d.add_argument("text")
    d.add_argument("--lang", default="es")
    args = ap.parse_args(argv)
    logging.basicConfig(level=logging.DEBUG if args.verbose else logging.INFO,
                        format="%(asctime)s %(levelname)s %(message)s", stream=sys.stderr)
    fn = {"demo": _demo}.get(args.cmd, _run)
    if args.cmd is None:
        args.sim = False
    try:
        asyncio.run(fn(args))
    except KeyboardInterrupt:
        pass
