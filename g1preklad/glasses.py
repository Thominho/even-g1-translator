"""Připojení k brýlím: skutečné BLE (bleak) a simulátor v terminálu."""
from __future__ import annotations

import asyncio
import logging
import sys
from typing import Awaitable, Callable

from . import protocol as P

log = logging.getLogger("g1preklad.glasses")

EventHandler = Callable[[P.GlassesEvent], Awaitable[None] | None]


class BaseGlasses:
    """Společné rozhraní pro skutečné brýle i simulátor."""

    def __init__(self, chars_per_line: float = 38):
        self.chars_per_line = chars_per_line
        self._handlers: list[EventHandler] = []
        self.audio_queue: asyncio.Queue[bytes] = asyncio.Queue(maxsize=500)
        self._pages: list[list[str]] = [[""]]
        self._page = 0
        self._lock = asyncio.Lock()

    # --- události
    def on_event(self, handler: EventHandler) -> None:
        self._handlers.append(handler)

    async def _dispatch(self, ev: P.GlassesEvent) -> None:
        log.debug("událost %s z %s", ev.name, ev.side)
        for h in list(self._handlers):
            try:
                r = h(ev)
                if asyncio.iscoroutine(r):
                    await r
            except Exception:  # handler nesmí shodit spojení
                log.exception("chyba v obsluze události")

    # --- text
    async def show(self, text: str, page: int = 0) -> None:
        """Zobrazí text, zalomí ho a rozdělí na stránky po 5 řádcích."""
        lines = P.wrap(text, self.chars_per_line)
        self._pages = P.paginate(lines)
        self._page = max(0, min(page, len(self._pages) - 1))
        await self._render()

    async def show_tail(self, text: str) -> None:
        """Zobrazí poslední stránku – vhodné pro průběžné titulky."""
        lines = P.wrap(text, self.chars_per_line)
        await self._show_lines(lines[-P.LINES_PER_SCREEN:])

    async def _show_lines(self, lines: list[str]) -> None:
        self._pages = [lines]
        self._page = 0
        await self._render()

    async def next_page(self) -> None:
        if self._page < len(self._pages) - 1:
            self._page += 1
            await self._render()

    async def prev_page(self) -> None:
        if self._page > 0:
            self._page -= 1
            await self._render()

    async def _render(self) -> None:
        async with self._lock:
            await self._send_page("\n".join(self._pages[self._page]), self._page, len(self._pages))

    async def _send_page(self, text: str, page: int, total: int) -> None:
        raise NotImplementedError

    async def clear(self) -> None:
        await self.show("")

    # --- mikrofon
    async def mic(self, enable: bool) -> None:
        raise NotImplementedError

    async def connect(self) -> None:
        raise NotImplementedError

    async def close(self) -> None:
        pass


# ======================================================================= BLE

class BleGlasses(BaseGlasses):
    def __init__(self, chars_per_line: float = 38, heartbeat_s: float = 8.0,
                 scan_timeout: float = 15.0, channel: str | None = None):
        super().__init__(chars_per_line)
        self.heartbeat_s = heartbeat_s
        self.scan_timeout = scan_timeout
        self.channel = channel
        self.clients: dict[str, object] = {}
        self._acks: dict[str, asyncio.Queue[bytes]] = {"L": asyncio.Queue(), "R": asyncio.Queue()}
        self._seq = 0
        self._hb_seq = 0
        self._hb_task: asyncio.Task | None = None

    async def connect(self) -> None:
        try:
            from bleak import BleakClient, BleakScanner
        except ImportError as e:  # pragma: no cover
            raise SystemExit("Chybí knihovna bleak: pip install bleak") from e

        log.info("Hledám brýle G1 (%.0f s)… Zavři oficiální aplikaci / vypni Bluetooth v telefonu.",
                 self.scan_timeout)
        found: dict[str, dict[str, object]] = {}
        devices = await BleakScanner.discover(timeout=self.scan_timeout)
        for d in devices:
            parsed = P.parse_name(d.name)
            if not parsed:
                continue
            ch, side = parsed
            if self.channel and ch != self.channel:
                continue
            found.setdefault(ch, {})[side] = d
        pair = next((v for v in found.values() if "L" in v and "R" in v), None)
        if not pair:
            raise SystemExit(f"Nenašel jsem obě stranice G1. Nalezeno: {found or 'nic'}")

        for side in ("L", "R"):
            dev = pair[side]
            client = BleakClient(dev, disconnected_callback=lambda c, s=side: log.warning(
                "Stranice %s se odpojila", s))
            await client.connect()
            await client.start_notify(P.UART_NOTIFY, self._make_notify(side))
            self.clients[side] = client
            log.info("Připojeno %s: %s", side, getattr(dev, "name", dev))

        self._hb_task = asyncio.create_task(self._heartbeat_loop())

    def _make_notify(self, side: str):
        loop = asyncio.get_running_loop()

        def cb(_char, data: bytearray) -> None:
            data = bytes(data)
            if not data:
                return
            if data[0] == P.CMD_MIC_DATA and len(data) > 2:
                try:
                    self.audio_queue.put_nowait(data[2:])
                except asyncio.QueueFull:
                    pass
                return
            ev = P.parse_event(side, data)
            if ev is not None:
                loop.create_task(self._dispatch(ev))
                return
            self._acks[side].put_nowait(data)

        return cb

    async def _write(self, side: str, data: bytes) -> None:
        client = self.clients[side]
        await client.write_gatt_char(P.UART_WRITE, data, response=False)  # type: ignore[attr-defined]

    async def _write_ack(self, side: str, data: bytes, timeout: float = 1.5) -> bool:
        q = self._acks[side]
        while not q.empty():
            q.get_nowait()
        await self._write(side, data)
        try:
            while True:
                rsp = await asyncio.wait_for(q.get(), timeout)
                if rsp and rsp[0] == data[0]:
                    return len(rsp) < 2 or rsp[1] != P.RSP_FAIL
        except asyncio.TimeoutError:
            log.debug("Bez potvrzení od %s pro 0x%02X", side, data[0])
            return False

    async def _send_page(self, text: str, page: int, total: int) -> None:
        self._seq = (self._seq + 1) & 0xFF
        for pkt in P.text_packets(text, self._seq, page, total):
            await self._write_ack("L", pkt)   # nejdřív levá…
            await self._write_ack("R", pkt)   # …pak pravá

    async def mic(self, enable: bool) -> None:
        await self._write_ack("R", P.mic(enable))

    async def _heartbeat_loop(self) -> None:
        while True:
            await asyncio.sleep(self.heartbeat_s)
            self._hb_seq = (self._hb_seq + 1) & 0xFF
            try:
                for side in ("L", "R"):
                    await self._write(side, P.heartbeat(self._hb_seq))
            except Exception:
                log.exception("heartbeat selhal")

    async def close(self) -> None:
        if self._hb_task:
            self._hb_task.cancel()
        for c in self.clients.values():
            try:
                await c.disconnect()  # type: ignore[attr-defined]
            except Exception:
                pass


# ================================================================= simulátor

KEYMAP = {
    "a": ("L", P.Event.SINGLE_TAP), "d": ("R", P.Event.SINGLE_TAP),
    "aa": ("L", P.Event.DOUBLE_TAP), "dd": ("R", P.Event.DOUBLE_TAP),
    "ttt": ("L", P.Event.TRIPLE_TAP),
    "h": ("L", P.Event.LONG_PRESS), "hr": ("L", P.Event.LONG_PRESS_RELEASE),
    "H": ("R", P.Event.LONG_PRESS), "Hr": ("R", P.Event.LONG_PRESS_RELEASE),
    "u": ("L", P.Event.HEAD_UP),
}

SIM_HELP = ("Simulátor TouchBaru – napiš a Enter: a/d = ťuk L/P, aa/dd = dvojťuk, ttt = trojťuk, "
            "h/hr = podržet/pustit L, H/Hr = podržet/pustit P, u = zvednutí hlavy, q = konec")


class SimGlasses(BaseGlasses):
    """Brýle v terminálu – pro vývoj bez hardwaru."""

    def __init__(self, chars_per_line: float = 38, interactive: bool = True, out=None):
        super().__init__(chars_per_line)
        self.interactive = interactive
        self.out = out or sys.stdout
        self.mic_on = False
        self.screens: list[str] = []
        self._kb_task: asyncio.Task | None = None
        self.quit = asyncio.Event()

    async def connect(self) -> None:
        if self.interactive:
            print(SIM_HELP, file=self.out)
            self._kb_task = asyncio.create_task(self._keyboard())

    async def _send_page(self, text: str, page: int, total: int) -> None:
        self.screens.append(text)
        w = int(self.chars_per_line) + 2
        bar = "─" * w
        body = "\n".join(f"│ {ln:<{w - 1}}│" for ln in (text.split("\n") + [""] * 5)[:5])
        print(f"┌{bar}┐ {page + 1}/{total}\n{body}\n└{bar}┘", file=self.out, flush=True)

    async def mic(self, enable: bool) -> None:
        self.mic_on = enable

    async def press(self, key: str) -> None:
        if key in KEYMAP:
            side, ev = KEYMAP[key]
            await self._dispatch(P.GlassesEvent(side, ev))

    async def _keyboard(self) -> None:
        loop = asyncio.get_running_loop()
        while True:
            line = await loop.run_in_executor(None, sys.stdin.readline)
            if not line:
                await asyncio.sleep(3600)
                continue
            key = line.strip()
            if key == "q":
                self.quit.set()
                return
            if key in KEYMAP:
                await self.press(key)
            elif key:
                print(SIM_HELP, file=self.out)

    async def close(self) -> None:
        if self._kb_task:
            self._kb_task.cancel()
