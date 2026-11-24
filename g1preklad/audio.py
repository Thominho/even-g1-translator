"""Zdroje zvuku: mikrofon brýlí (LC3) nebo mikrofon Macu. Výstup: PCM 16 kHz mono int16."""
from __future__ import annotations

import asyncio
import ctypes
import ctypes.util
import logging
import struct
from typing import AsyncIterator

log = logging.getLogger("g1preklad.audio")

SAMPLE_RATE = 16000


class AudioSource:
    async def start(self) -> None: ...
    async def stop(self) -> None: ...

    def frames(self) -> AsyncIterator[bytes]:
        """PCM int16 bloky (libovolná délka)."""
        raise NotImplementedError


# ------------------------------------------------------------- mikrofon Macu

class MacMic(AudioSource):
    """Mikrofon počítače (nebo AirPods) přes knihovnu sounddevice."""

    def __init__(self, device: str | int | None = None, block_ms: int = 100):
        self.device = device
        self.block = SAMPLE_RATE * block_ms // 1000
        self._q: asyncio.Queue[bytes] = asyncio.Queue(maxsize=200)
        self._stream = None

    async def start(self) -> None:
        try:
            import sounddevice as sd
        except ImportError as e:  # pragma: no cover
            raise SystemExit("Chybí sounddevice: pip install sounddevice") from e
        loop = asyncio.get_running_loop()

        def cb(indata, _frames, _time, status):
            if status:
                log.debug("audio: %s", status)
            data = bytes(indata)
            loop.call_soon_threadsafe(self._put, data)

        self._stream = sd.RawInputStream(samplerate=SAMPLE_RATE, channels=1, dtype="int16",
                                         blocksize=self.block, device=self.device, callback=cb)
        self._stream.start()

    def _put(self, data: bytes) -> None:
        try:
            self._q.put_nowait(data)
        except asyncio.QueueFull:
            pass

    async def stop(self) -> None:
        if self._stream is not None:
            self._stream.stop()
            self._stream.close()
            self._stream = None

    async def frames(self):
        while True:
            yield await self._q.get()


# ------------------------------------------------------------ mikrofon brýlí

class Lc3Decoder:
    """Dekodér LC3 přes Google liblc3 (ctypes). Brýle posílají 16 kHz, rámce 10 ms."""

    def __init__(self, frame_bytes: int = 20, dt_us: int = 10000, sr: int = SAMPLE_RATE,
                 lib_path: str | None = None):
        path = lib_path or ctypes.util.find_library("lc3")
        if not path:
            for cand in ("/opt/homebrew/lib/liblc3.dylib", "/usr/local/lib/liblc3.dylib"):
                try:
                    ctypes.CDLL(cand)
                    path = cand
                    break
                except OSError:
                    continue
        if not path:
            raise RuntimeError("Nenašel jsem liblc3 (viz README, sekce Mikrofon brýlí).")
        lib = ctypes.CDLL(path)
        lib.lc3_decoder_size.restype = ctypes.c_uint
        lib.lc3_decoder_size.argtypes = [ctypes.c_int, ctypes.c_int]
        lib.lc3_setup_decoder.restype = ctypes.c_void_p
        lib.lc3_setup_decoder.argtypes = [ctypes.c_int, ctypes.c_int, ctypes.c_int, ctypes.c_void_p]
        lib.lc3_decode.restype = ctypes.c_int
        lib.lc3_decode.argtypes = [ctypes.c_void_p, ctypes.c_void_p, ctypes.c_int, ctypes.c_int,
                                   ctypes.c_void_p, ctypes.c_int]
        self.lib = lib
        self.frame_bytes = frame_bytes
        self.samples = sr * dt_us // 1_000_000
        self._mem = ctypes.create_string_buffer(lib.lc3_decoder_size(dt_us, sr))
        self._dec = lib.lc3_setup_decoder(dt_us, sr, 0, self._mem)
        self._pcm = (ctypes.c_int16 * self.samples)()

    def decode(self, data: bytes) -> bytes:
        out = bytearray()
        for i in range(0, len(data) - self.frame_bytes + 1, self.frame_bytes):
            frame = data[i : i + self.frame_bytes]
            buf = ctypes.create_string_buffer(frame, len(frame))
            self.lib.lc3_decode(self._dec, buf, len(frame), 0, self._pcm, 1)  # 0 = S16
            out += bytes(self._pcm)
        return bytes(out)


class GlassesMic(AudioSource):
    def __init__(self, glasses, decoder: Lc3Decoder | None = None):
        self.glasses = glasses
        self.decoder = decoder or Lc3Decoder()

    async def start(self) -> None:
        while not self.glasses.audio_queue.empty():
            self.glasses.audio_queue.get_nowait()
        await self.glasses.mic(True)

    async def stop(self) -> None:
        await self.glasses.mic(False)

    async def frames(self):
        while True:
            pkt = await self.glasses.audio_queue.get()
            yield self.decoder.decode(pkt)


# ---------------------------------------------------------------- segmentace

def rms(pcm: bytes) -> float:
    n = len(pcm) // 2
    if n == 0:
        return 0.0
    vals = struct.unpack(f"<{n}h", pcm[: n * 2])
    return (sum(v * v for v in vals) / n) ** 0.5


class Segmenter:
    """Jednoduchá detekce řeči podle hlasitosti: vrací úseky ukončené pauzou.

    Pro průběžné titulky navíc umí vrátit rozpracovaný úsek (partial) každých `partial_s`.
    """

    def __init__(self, threshold: float = 500, silence_s: float = 0.7, max_s: float = 12.0,
                 min_s: float = 0.4, partial_s: float = 0.0):
        self.threshold = threshold
        self.silence_b = int(silence_s * SAMPLE_RATE * 2)
        self.max_b = int(max_s * SAMPLE_RATE * 2)
        self.min_b = int(min_s * SAMPLE_RATE * 2)
        self.partial_b = int(partial_s * SAMPLE_RATE * 2) if partial_s else 0
        self.buf = bytearray()
        self.quiet = 0
        self.speaking = False
        self._since_partial = 0

    def feed(self, pcm: bytes) -> list[tuple[str, bytes]]:
        """Vrací seznam ('final'|'partial', pcm)."""
        out: list[tuple[str, bytes]] = []
        loud = rms(pcm) >= self.threshold
        if loud:
            self.speaking = True
            self.quiet = 0
        elif self.speaking:
            self.quiet += len(pcm)
        if self.speaking:
            self.buf += pcm
            self._since_partial += len(pcm)
        if not self.speaking:
            return out
        if self.quiet >= self.silence_b or len(self.buf) >= self.max_b:
            if len(self.buf) - self.quiet >= self.min_b:
                out.append(("final", bytes(self.buf)))
            self.reset()
        elif self.partial_b and self._since_partial >= self.partial_b:
            self._since_partial = 0
            out.append(("partial", bytes(self.buf)))
        return out

    def flush(self) -> bytes | None:
        data = bytes(self.buf) if len(self.buf) >= self.min_b else None
        self.reset()
        return data

    def reset(self) -> None:
        self.buf = bytearray()
        self.quiet = 0
        self.speaking = False
        self._since_partial = 0


def make_source(kind: str, glasses) -> AudioSource:
    if kind == "glasses":
        return GlassesMic(glasses)
    if kind == "mac":
        return MacMic()
    raise ValueError(f"Neznámý zdroj zvuku: {kind}")
