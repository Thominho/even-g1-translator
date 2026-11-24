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
from .ai import Interpreter, Reply, make_llm, make_stt
from .i18n import Lang
from .audio import Segmenter, make_source
from .glasses import BleGlasses, SimGlasses

log = logging.getLogger("g1preklad")


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
        self.prefetch = bool(c.get("prefetch_replies", True))
        self.followups_enabled = bool(c.get("follow_up_questions", True))
        self.mode = "reply"                      # "reply" = answers, "ask" = questions to ask
        self._fu: asyncio.Task | None = None
        self._pre: tuple[str, asyncio.Task] | None = None
        self.L = Lang(c.get("native_language", "en"))
        self.ignore = {self.L.native, *c.get("ignore_languages", [])}
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
                await self.g.show(f"{self.L.t('error')}: {e}")

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
        # the user just read one of the suggestions aloud → don't translate it
        if self.replies:
            best = max(self.replies, key=lambda r: similar(r.text, text))
            if similar(best.text, text) >= 0.6:
                await self.on_user_said(best)
                return

        self.last_speech = time.monotonic()
        first = self.lang is None or heard.lang != self.lang
        if first:
            self.lang = heard.lang
            self.turn_orig, self.turn_cs = [], []
        self.showing_replies = False
        self.replies, self.mode = [], "reply"
        if self._fu is not None and not self._fu.done():
            self._fu.cancel()
        self._fu = None

        cs = await self.interp.translate(text, self.lang, self.history)
        self.turn_orig.append(text)
        self.turn_cs.append(cs)
        self.history.append(f"On/ona: {text} ({cs})")
        await self.draw_turn(header=first)
        self._schedule_turn_end()

    def _header(self) -> str:
        return f"[{self.L.name(self.lang).upper()}]"

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
            if self.prefetch:
                self._prefetch_replies()
            self._turn_timer = asyncio.create_task(self._turn_end())

    def _prefetch_replies(self) -> None:
        """Po každé větě připraví odpovědi na pozadí – při konci promluvy jsou hned hotové."""
        turn = " ".join(self.turn_orig)
        if self._pre is not None and self._pre[0] == turn:
            return
        if self._pre is not None and not self._pre[1].done():
            self._pre[1].cancel()   # starší verze promluvy už není potřeba
        ctx = self.history[:-len(self.turn_orig)]
        self._pre = (turn, asyncio.create_task(self.interp.replies(turn, self.lang, ctx)))

    async def _turn_end(self) -> None:
        await asyncio.sleep(self.turn_end_s)
        if self.seg.speaking or not self.queue.empty() or not self.turn_orig:
            return
        turn = " ".join(self.turn_orig)
        try:
            if self._pre is not None and self._pre[0] == turn:
                replies = await asyncio.shield(self._pre[1])   # obvykle už hotové
            else:
                replies = await self.interp.replies(turn, self.lang,
                                                    self.history[:-len(self.turn_orig)])
        except asyncio.CancelledError:
            raise
        except Exception:
            log.exception("návrhy odpovědí selhaly")
            return
        if self.seg.speaking or not self.queue.empty():
            return  # mezitím začal zase mluvit
        self.replies, self.reply_idx, self.mode = replies, 0, "reply"
        self.turn_orig, self.turn_cs = [], []
        self._pre = None
        if replies and self.followups_enabled:
            # prepare "what to ask next" for every reply while the user is reading them
            self._fu = asyncio.create_task(self.interp.followups(
                turn, self.lang, self.history[-8:], replies))
        if replies:
            await self.show_reply()

    async def on_user_said(self, said: Reply) -> None:
        """The user said a suggestion. After an answer, offer questions to ask back."""
        self.history.append(f"Me: {said.text}")
        fus: list[Reply] = []
        if self.mode == "reply" and self._fu is not None:
            idx = next((i for i, r in enumerate(self.replies) if r is said), -1)
            try:
                all_fu = await asyncio.wait_for(asyncio.shield(self._fu), 6)
                fus = all_fu[idx] if 0 <= idx < len(all_fu) else []
            except Exception:
                log.exception("follow-up questions failed")
        self._fu = None
        self.showing_replies = False
        if fus:
            self.replies, self.reply_idx, self.mode = fus, 0, "ask"
            await self.show_reply()
        else:
            self.replies, self.mode = [], "reply"
            await self.g.show(f"{self.L.t('you_said')}: {said.meaning or said.text}\n{self.L.t('listening')}")

    async def show_reply(self) -> None:
        if not self.replies:
            await self.g.show(self.L.t("no_replies"))
            return
        self.showing_replies = True
        r = self.replies[self.reply_idx]
        label = self.L.t("ask") if self.mode == "ask" else self.L.label(r.kind)
        # nahoře česky, pod tím odpověď v jazyce mluvčího a výslovnost
        head = f"{label} {self.reply_idx + 1}/{len(self.replies)}"
        lines = [f"{head}: {r.meaning}" if r.meaning else head]
        lines.append(f"> {r.pron}" if r.pron else f"> {r.text}")
        if self.show_spelling and r.pron:
            lines.append(f"({r.text})")
        await self.g.show("\n".join(lines))

    def new_conversation(self) -> None:
        if self._pre is not None and not self._pre[1].done():
            self._pre[1].cancel()
        self._pre = None
        self.lang = None
        self.turn_orig, self.turn_cs, self.history = [], [], []
        self.replies, self.showing_replies = [], False

    # --------------------------------------------------------------- ovládání
    async def on_event(self, ev: P.GlassesEvent) -> None:
        e = ev.event
        if e == P.Event.TRIPLE_TAP:
            self.paused = not self.paused
            self.seg.reset()
            await self.g.show(self.L.t("paused") if self.paused else self.L.t("listening"))
        elif e == P.Event.SINGLE_TAP and self.showing_replies and self.replies:
            step = 1 if ev.side == "R" else -1
            self.reply_idx = (self.reply_idx + step) % len(self.replies)
            await self.show_reply()
        elif e == P.Event.SINGLE_TAP and ev.side == "L":
            self.show_original = not self.show_original
            await self.g.show(self.L.t("orig_on") if self.show_original else self.L.t("orig_off"))
        elif e == P.Event.SINGLE_TAP and ev.side == "R" and self.turn_cs:
            await self.draw_turn(header=True)
        elif e == P.Event.DOUBLE_TAP:
            if self.showing_replies:
                self.showing_replies = False
                await self.g.show(self.L.t("listening"))
            else:
                self.new_conversation()
                await self.g.show(f"{self.L.t('new')}\n{self.L.t('listening')}")
        elif e == P.Event.LONG_PRESS and ev.side == "R" and self.replies:
            await self.show_reply()
        elif e == P.Event.HEAD_UP and self.showing_replies:
            await self.show_reply()

    # --------------------------------------------------------------- běh
    async def start(self) -> None:
        self.g.on_event(self.on_event)
        await self.source.start()
        self._tasks = [asyncio.create_task(self._pump()), asyncio.create_task(self._worker())]
        await self.g.show(f"{self.L.t('start', lang=self.L.name(self.L.native))}\n{self.L.t('listening')}")

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
    native = cfg.get("translator", {}).get("native_language", "en")
    interp = Interpreter(make_llm(cfg.get("llm", {})), native)
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
    """Test the LLM without a microphone: translate a sentence and suggest replies."""
    cfg = load_config(args.config)
    native = cfg.get("translator", {}).get("native_language", "en")
    L = Lang(native)
    interp = Interpreter(make_llm(cfg.get("llm", {})), native)
    g = SimGlasses(interactive=False)
    print("Translation:", await interp.translate(args.text, args.lang, []))
    for r in await interp.replies(args.text, args.lang, []):
        print(f"- {L.label(r.kind)}: {r.meaning}  > {r.pron}  ({r.text})")
    del g


def main(argv: list[str] | None = None) -> None:
    ap = argparse.ArgumentParser(prog="g1preklad", description="Live translator with reply suggestions for Even Realities G1")
    ap.add_argument("-c", "--config")
    ap.add_argument("-v", "--verbose", action="store_true")
    sub = ap.add_subparsers(dest="cmd")
    r = sub.add_parser("run", help="spustit překladač")
    r.add_argument("--sim", action="store_true", help="simulátor v terminálu místo brýlí")
    d = sub.add_parser("demo", help="test LLM: přeložit text a navrhnout odpovědi")
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
