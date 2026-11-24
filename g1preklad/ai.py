"""Přepis řeči s detekcí jazyka (Whisper) a překlad + návrhy odpovědí (LLM: Anthropic / OpenAI / Ollama)."""
from __future__ import annotations

import asyncio
import io
import json
import logging
import os
import re
import urllib.request
import uuid
import wave
from dataclasses import dataclass

from .audio import SAMPLE_RATE
from .i18n import KIND_ALIASES, english_name

log = logging.getLogger("g1preklad.ai")

# OpenAI verbose_json vrací anglický název jazyka
_EN_NAMES = {"english": "en", "spanish": "es", "german": "de", "french": "fr", "italian": "it",
             "portuguese": "pt", "polish": "pl", "slovak": "sk", "russian": "ru",
             "ukrainian": "uk", "dutch": "nl", "hungarian": "hu", "czech": "cs",
             "romanian": "ro", "croatian": "hr", "greek": "el", "turkish": "tr",
             "swedish": "sv", "japanese": "ja", "chinese": "zh", "korean": "ko",
             "arabic": "ar", "danish": "da", "norwegian": "no", "finnish": "fi"}


@dataclass
class Heard:
    text: str
    lang: str | None
    prob: float | None = None


def _env(name: str | None) -> str:
    if not name:
        return "none"
    v = os.environ.get(name, "")
    if not v:
        raise SystemExit(f"Chybí proměnná prostředí {name} (API klíč).")
    return v


def _post_json(url: str, payload: dict, headers: dict, timeout: float = 60) -> dict:
    req = urllib.request.Request(url, data=json.dumps(payload).encode(), method="POST",
                                 headers={"Content-Type": "application/json", **headers})
    with urllib.request.urlopen(req, timeout=timeout) as r:
        return json.loads(r.read())


def _f32(pcm: bytes):
    import numpy as np
    return np.frombuffer(pcm, dtype=np.int16).astype(np.float32) / 32768.0


# ================================================================== přepis

class MlxWhisper:
    """Offline, Apple Silicon. Model 'small' zvládá jazyky slušně, 'large-v3-turbo' výborně."""

    def __init__(self, model: str = "mlx-community/whisper-large-v3-turbo"):
        try:
            import mlx_whisper  # noqa: F401
        except ImportError as e:  # pragma: no cover
            raise SystemExit("Chybí mlx-whisper: pip install mlx-whisper") from e
        self.model = model

    def _run(self, pcm: bytes, language: str | None) -> Heard:
        import mlx_whisper
        r = mlx_whisper.transcribe(_f32(pcm), path_or_hf_repo=self.model, language=language)
        return Heard((r.get("text") or "").strip(), r.get("language"))

    async def hear(self, pcm: bytes, language: str | None = None) -> Heard:
        return await asyncio.to_thread(self._run, pcm, language)


class FasterWhisper:
    def __init__(self, model: str = "small"):
        try:
            from faster_whisper import WhisperModel
        except ImportError as e:  # pragma: no cover
            raise SystemExit("Chybí faster-whisper: pip install faster-whisper") from e
        self.model = WhisperModel(model, device="cpu", compute_type="int8")

    def _run(self, pcm: bytes, language: str | None) -> Heard:
        segs, info = self.model.transcribe(_f32(pcm), language=language, beam_size=1,
                                           vad_filter=True)
        text = " ".join(s.text.strip() for s in segs).strip()
        return Heard(text, info.language, info.language_probability)

    async def hear(self, pcm: bytes, language: str | None = None) -> Heard:
        return await asyncio.to_thread(self._run, pcm, language)


class OpenAIWhisper:
    def __init__(self, model: str = "whisper-1", api_key_env: str = "OPENAI_API_KEY",
                 base_url: str = "https://api.openai.com/v1"):
        self.model, self.key = model, _env(api_key_env)
        self.url = base_url.rstrip("/") + "/audio/transcriptions"

    def _run(self, pcm: bytes, language: str | None) -> Heard:
        bio = io.BytesIO()
        with wave.open(bio, "wb") as w:
            w.setnchannels(1), w.setsampwidth(2), w.setframerate(SAMPLE_RATE), w.writeframes(pcm)
        b = uuid.uuid4().hex
        fields = {"model": self.model, "response_format": "verbose_json"}
        if language:
            fields["language"] = language
        body = b"".join(f"--{b}\r\nContent-Disposition: form-data; name=\"{k}\"\r\n\r\n{v}\r\n"
                        .encode() for k, v in fields.items())
        body += (f"--{b}\r\nContent-Disposition: form-data; name=\"file\"; filename=\"a.wav\"\r\n"
                 f"Content-Type: audio/wav\r\n\r\n").encode() + bio.getvalue() + f"\r\n--{b}--\r\n".encode()
        req = urllib.request.Request(self.url, data=body, method="POST", headers={
            "Authorization": f"Bearer {self.key}", "Content-Type": f"multipart/form-data; boundary={b}"})
        with urllib.request.urlopen(req, timeout=60) as r:
            d = json.loads(r.read())
        lang = (d.get("language") or "").lower()
        return Heard((d.get("text") or "").strip(), _EN_NAMES.get(lang, lang or None))

    async def hear(self, pcm: bytes, language: str | None = None) -> Heard:
        return await asyncio.to_thread(self._run, pcm, language)


def make_stt(cfg: dict):
    kind = cfg.get("backend", "mlx-whisper")
    if kind == "mlx-whisper":
        return MlxWhisper(cfg.get("model", "mlx-community/whisper-large-v3-turbo"))
    if kind == "faster-whisper":
        return FasterWhisper(cfg.get("model", "small"))
    if kind == "openai":
        return OpenAIWhisper(cfg.get("model", "whisper-1"), cfg.get("api_key_env", "OPENAI_API_KEY"))
    raise SystemExit(f"Neznámý STT backend: {kind}")


# ===================================================================== LLM

class AnthropicLLM:
    def __init__(self, model: str, api_key_env: str = "ANTHROPIC_API_KEY"):
        if not model:
            raise SystemExit("V config.toml chybí [llm] model (ID modelu podle dokumentace poskytovatele).")
        self.model, self.key = model, _env(api_key_env)

    def _run(self, system: str, user: str, max_tokens: int) -> str:
        r = _post_json("https://api.anthropic.com/v1/messages", {
            "model": self.model, "max_tokens": max_tokens, "system": system,
            "messages": [{"role": "user", "content": user}]},
            {"x-api-key": self.key, "anthropic-version": "2023-06-01"})
        return "".join(b.get("text", "") for b in r.get("content", [])).strip()

    async def chat(self, system: str, user: str, max_tokens: int = 400) -> str:
        return await asyncio.to_thread(self._run, system, user, max_tokens)


class OpenAICompat:
    """OpenAI nebo lokální Ollama (offline): base_url = http://localhost:11434/v1"""

    def __init__(self, model: str, base_url: str, api_key_env: str | None = None):
        self.model, self.key = model, _env(api_key_env)
        self.url = base_url.rstrip("/") + "/chat/completions"

    def _run(self, system: str, user: str, max_tokens: int) -> str:
        r = _post_json(self.url, {"model": self.model, "max_tokens": max_tokens, "messages": [
            {"role": "system", "content": system}, {"role": "user", "content": user}]},
            {"Authorization": f"Bearer {self.key}"})
        return r["choices"][0]["message"]["content"].strip()

    async def chat(self, system: str, user: str, max_tokens: int = 400) -> str:
        return await asyncio.to_thread(self._run, system, user, max_tokens)


def make_llm(cfg: dict):
    kind = cfg.get("backend", "anthropic")
    if kind == "anthropic":
        return AnthropicLLM(cfg.get("model", ""), cfg.get("api_key_env", "ANTHROPIC_API_KEY"))
    if kind == "ollama":
        return OpenAICompat(cfg.get("model", "qwen2.5:7b"),
                            cfg.get("base_url", "http://localhost:11434/v1"), None)
    if kind == "openai":
        return OpenAICompat(cfg.get("model", "gpt-4o-mini"), cfg.get("base_url", "https://api.openai.com/v1"),
                            cfg.get("api_key_env", "OPENAI_API_KEY"))
    raise SystemExit(f"Neznámý LLM backend: {kind}")


# ============================================================ translation & replies

@dataclass
class Reply:
    kind: str      # "yes" | "no" | "question"
    text: str      # in the speaker's language
    pron: str      # pronunciation written with the native language's spelling
    meaning: str   # meaning in the native language


TRANSLATE_SYS = (
    "You translate live speech into {native} for subtitles in smart glasses. Return ONLY the "
    "{native} translation – natural, concise, no quotes, no comments. If the transcript is "
    "garbled, translate the most likely meaning.")

REPLY_SYS = (
    "The user is a native {native} speaker who does not speak {lang}. Someone has just spoken to "
    "them in {lang}. Suggest 3 very short replies IN {lang} that the user can read out loud:\n"
    "1. \"yes\" – positive / agreement / thanks (whatever fits),\n"
    "2. \"no\" – negative / polite refusal,\n"
    "3. \"question\" – a follow-up question on the topic, OR a request to repeat more slowly if "
    "the speech made no sense.\n"
    "Each reply max 5 words, simple vocabulary. For each add a pronunciation guide written with "
    "{native} spelling conventions, so a {native} speaker reading it naturally sounds right, and "
    "its meaning in {native} (max 4 words – all three must fit on a tiny display).\n"
    "Return ONLY JSON: {{\"replies\": [{{\"kind\": \"yes\", \"text\": \"...\", \"pron\": \"...\", "
    "\"meaning\": \"...\"}}, ...]}}")


FOLLOWUP_SYS = (
    "The user is a native {native} speaker talking with someone in {lang}, which the user does not "
    "speak. The other person just said something and the user will answer with ONE of the replies "
    "listed below. For EACH reply, suggest 3 short follow-up questions IN {lang} the user can ask "
    "right after answering, to keep the conversation going:\n"
    "1. if the other person asked the user a question, ask the same question back (e.g. 'And you?'); "
    "otherwise a natural reaction question,\n"
    "2.–3. other sensible, friendly questions on the topic.\n"
    "Each max 5 words, simple vocabulary, with a pronunciation guide in {native} spelling "
    "conventions and the meaning in {native} (max 4 words – they must fit on a tiny display).\n"
    "Return ONLY JSON: {{\"followups\": [[{{\"text\": \"...\", \"pron\": \"...\", \"meaning\": \"...\"}}, "
    "...3 items], ...one list per reply, in the same order]}}")


def _reply_from(d: dict, kind: str = "") -> Reply | None:
    if not isinstance(d, dict) or not d.get("text"):
        return None
    return Reply(kind, str(d["text"]).strip(), str(d.get("pron", "")).strip(),
                 str(d.get("meaning", d.get("cs", ""))).strip())


def parse_followups(raw: str, n: int) -> list[list[Reply]]:
    m = re.search(r"\{.*\}", raw, re.S)
    try:
        data = json.loads(m.group(0)) if m else {}
    except json.JSONDecodeError:
        data = {}
    out: list[list[Reply]] = []
    for group in (data.get("followups") or [])[:n]:
        items = [r for r in (_reply_from(d, "ask") for d in (group or [])[:3]) if r]
        out.append(items)
    return out + [[] for _ in range(n - len(out))]


def parse_replies(raw: str) -> list[Reply]:
    m = re.search(r"\{.*\}", raw, re.S)
    if not m:
        return []
    try:
        data = json.loads(m.group(0))
    except json.JSONDecodeError:
        return []
    out = []
    for r in data.get("replies", [])[:3]:
        if isinstance(r, dict) and r.get("text"):
            kind = KIND_ALIASES.get(str(r.get("kind", "")).lower(), str(r.get("kind", "")).lower())
            out.append(Reply(kind, str(r["text"]).strip(), str(r.get("pron", "")).strip(),
                             str(r.get("meaning", r.get("cs", ""))).strip()))
    return out


class Interpreter:
    def __init__(self, llm, native: str = "en"):
        self.llm = llm
        self.native = english_name(native)

    async def translate(self, text: str, lang: str | None, context: list[str]) -> str:
        user = ""
        if context:
            user += "Earlier sentences (context only, do not translate):\n" + "\n".join(context[-4:]) + "\n\n"
        user += f"Language: {english_name(lang)}\nTranslate into {self.native}:\n{text}"
        out = await self.llm.chat(TRANSLATE_SYS.format(native=self.native), user, 300)
        return out.strip().strip('"„“')

    async def replies(self, turn: str, lang: str | None, context: list[str]) -> list[Reply]:
        user = ""
        if context:
            user += "Conversation so far:\n" + "\n".join(context[-8:]) + "\n\n"
        user += f"They just said:\n{turn}"
        sys = REPLY_SYS.format(native=self.native, lang=english_name(lang))
        return parse_replies(await self.llm.chat(sys, user, 500))

    async def followups(self, turn: str, lang: str | None, context: list[str],
                        replies: list[Reply]) -> list[list[Reply]]:
        user = ""
        if context:
            user += "Conversation so far:\n" + "\n".join(context[-8:]) + "\n\n"
        user += f"They just said:\n{turn}\n\nThe user's possible replies:\n"
        user += "\n".join(f"{i + 1}. {r.text}" for i, r in enumerate(replies))
        sys = FOLLOWUP_SYS.format(native=self.native, lang=english_name(lang))
        return parse_followups(await self.llm.chat(sys, user, 900), len(replies))
