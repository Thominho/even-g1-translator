"""Nízkoúrovňový BLE protokol Even G1.

Zdroje: oficiální EvenDemoApp (github.com/even-realities/EvenDemoApp) a komunitní
dokumentace protokolu. Každá stranice brýlí je samostatné BLE zařízení s Nordic UART.
Pravidlo z dema: posílej nejdřív doleva, po potvrzení doprava; mikrofon (0x0E) jen doprava.
"""
from __future__ import annotations

import enum
import re
import unicodedata
from dataclasses import dataclass

UART_SERVICE = "6e400001-b5a3-f393-e0a9-e50e24dcca9e"
UART_WRITE = "6e400002-b5a3-f393-e0a9-e50e24dcca9e"   # host -> brýle
UART_NOTIFY = "6e400003-b5a3-f393-e0a9-e50e24dcca9e"  # brýle -> host

CMD_TEXT = 0x4E
CMD_MIC = 0x0E
CMD_MIC_DATA = 0xF1
CMD_EVENT = 0xF5
CMD_HEARTBEAT = 0x25
CMD_CLEAR = 0x18
CMD_INIT = 0x4D

RSP_OK = 0xC9
RSP_FAIL = 0xCA

# Horní nibble "newscreen" u textu: 0x70 = text show, dolní 0x01 = nový obsah
SCREEN_TEXT_NEW = 0x71

MAX_CHUNK = 180          # bezpečná velikost dat v jednom paketu
LINES_PER_SCREEN = 5     # podle dema


class Event(enum.IntEnum):
    DOUBLE_TAP = 0x00
    SINGLE_TAP = 0x01
    HEAD_UP = 0x02
    HEAD_DOWN = 0x03
    TRIPLE_TAP = 0x04
    TRIPLE_TAP_2 = 0x05
    WORN = 0x06
    TAKEN_OFF = 0x07
    IN_CASE_OPEN = 0x08
    IN_CASE_CLOSED = 0x0B
    LONG_PRESS = 0x17
    LONG_PRESS_RELEASE = 0x18
    DASHBOARD_OPEN = 0x1E
    DASHBOARD_CLOSE = 0x1F


@dataclass
class GlassesEvent:
    side: str            # "L" nebo "R"
    event: Event | int
    payload: bytes = b""

    @property
    def name(self) -> str:
        return self.event.name if isinstance(self.event, Event) else f"0x{self.event:02X}"


def parse_event(side: str, data: bytes) -> GlassesEvent | None:
    if len(data) < 2 or data[0] != CMD_EVENT:
        return None
    try:
        ev: Event | int = Event(data[1])
    except ValueError:
        ev = data[1]
    if ev == Event.TRIPLE_TAP_2:
        ev = Event.TRIPLE_TAP
    return GlassesEvent(side, ev, bytes(data[2:]))


def heartbeat(seq: int) -> bytes:
    """Heartbeat ve tvaru používaném komunitními knihovnami (6 bajtů)."""
    seq &= 0xFF
    length = 6
    return bytes([CMD_HEARTBEAT, length & 0xFF, (length >> 8) & 0xFF, seq, 0x04, seq])


def mic(enable: bool) -> bytes:
    return bytes([CMD_MIC, 1 if enable else 0])


def clear_screen() -> bytes:
    return bytes([CMD_CLEAR])


# ---------------------------------------------------------------- text layout

def _char_width(ch: str) -> float:
    """Hrubý odhad šířky znaku v jednotkách 'průměrného znaku'."""
    if ch in "iIl.,:;'!|":
        return 0.5
    if ch in "mwMW@":
        return 1.5
    if unicodedata.east_asian_width(ch) in ("W", "F"):
        return 2.0
    return 1.0


def text_width(s: str) -> float:
    return sum(_char_width(c) for c in s)


def wrap(text: str, width: float = 38) -> list[str]:
    """Zalomí text na řádky podle odhadované šířky displeje (488 px, písmo 21)."""
    lines: list[str] = []
    for para in text.replace("\r", "").split("\n"):
        words = re.split(r"(\s+)", para.strip())
        cur = ""
        for w in words:
            if not w or w.isspace():
                if cur:
                    cur += " "
                continue
            cand = (cur + w) if cur else w
            if text_width(cand) <= width:
                cur = cand
                continue
            if cur.strip():
                lines.append(cur.rstrip())
            # příliš dlouhé slovo rozsekat
            while text_width(w) > width:
                cut = 1
                while cut < len(w) and text_width(w[: cut + 1]) <= width:
                    cut += 1
                lines.append(w[:cut])
                w = w[cut:]
            cur = w
        lines.append(cur.rstrip())
    # odstraň prázdné řádky na konci
    while lines and not lines[-1]:
        lines.pop()
    return lines or [""]


def paginate(lines: list[str], per_page: int = LINES_PER_SCREEN) -> list[list[str]]:
    return [lines[i : i + per_page] for i in range(0, len(lines), per_page)] or [[""]]


def text_packets(page_text: str, seq: int, page: int, total_pages: int,
                 screen: int = SCREEN_TEXT_NEW) -> list[bytes]:
    """Pakety 0x4E pro jednu obrazovku textu.

    Hlavička: cmd, seq, total_pkg, cur_pkg, newscreen, pos_hi, pos_lo, cur_page, max_page, data
    """
    data = page_text.encode("utf-8")
    chunks = [data[i : i + MAX_CHUNK] for i in range(0, len(data), MAX_CHUNK)] or [b""]
    total = len(chunks)
    out = []
    for i, ch in enumerate(chunks):
        out.append(bytes([
            CMD_TEXT, seq & 0xFF, total, i, screen, 0, 0,
            page & 0xFF, max(1, total_pages) & 0xFF,
        ]) + ch)
    return out


def is_ack(data: bytes, cmd: int) -> bool:
    return len(data) >= 2 and data[0] == cmd and data[1] == RSP_OK


_NAME_RE = re.compile(r"G1_(\d+)_([LR])_", re.I)


def parse_name(name: str | None) -> tuple[str, str] | None:
    """'G1_45_L_92333' -> ('45', 'L')"""
    if not name:
        return None
    m = _NAME_RE.search(name)
    return (m.group(1), m.group(2).upper()) if m else None
