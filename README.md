# g1preklad – live translator with reply suggestions for Even Realities G1

**English** | [Čeština](README.cs.md)

An unofficial companion app for the **Even Realities G1** smart glasses, running on macOS.
When someone talks to you in **any language other than Czech**, the glasses show a live
**Czech translation**. The first sentence tells you **which language** is being spoken. When the
speaker **finishes**, you get **3 reply suggestions in their language** – the Czech meaning on top
and, below it, a **pronunciation written for Czech speakers**, so you can just read it out loud.

```
┌────────────────────────────────────────┐      ┌────────────────────────────────────────┐
│ [ŠPANĚLŠTINA]                          │      │ ANO 1/3: Ano, moc se mi tam líbí.      │
│ Ahoj, odkud jsi? Líbí se ti Paraguay?  │  →   │ > sí, me gusta mučo                    │
│                                        │      │                                        │
└────────────────────────────────────────┘      └────────────────────────────────────────┘
   speaker talking (Spanish → Czech)               speaker finished → tap right = next reply
```

Reply suggestions: **ANO** (yes / agree / thanks) · **NE** (polite no) · **OTÁZKA** (a follow-up
question, or "could you repeat that more slowly?" when the speech didn't make sense).

> The target language is Czech – the UI, prompts and pronunciation are made for Czech speakers.
> Adapting it to another native language means changing `HOME_LANG` in `app.py` and the prompts in `ai.py`.

## Features

- **Automatic language detection** (Whisper) – works with any language, switches when someone else speaks another one.
- **Czech speech is ignored**, so your own sentences are never translated (`ignore_languages`).
- **Recognises when you read a suggestion aloud** and doesn't translate it back.
- Holds the conversation language on short, uncertain sentences.
- Translation and replies use the earlier conversation as context.
- Speech-to-text runs **offline on your Mac**; translation and replies use **Claude** (or a local model via Ollama for fully offline use).

## Controls (TouchBar)

| Gesture | Action |
|---|---|
| tap right / left | next / previous reply suggestion |
| double tap | close suggestions · again = new conversation (forget language and context) |
| hold right / head up | show suggestions again |
| tap left (no suggestions) | toggle original text above translation |
| triple tap | pause / resume |

## Installation (macOS)

```bash
git clone https://github.com/Thominho/even-g1-translator.git
cd even-g1-translator
python3 -m venv .venv && source .venv/bin/activate
pip install -e .
pip install mlx-whisper            # Apple Silicon (Intel Mac: pip install faster-whisper, set backend = "faster-whisper")
cp config.example.toml config.toml
echo 'export ANTHROPIC_API_KEY="sk-ant-..."' >> ~/.zshrc && source ~/.zshrc
```

On first run macOS asks for microphone and Bluetooth access for your terminal – allow both.
The first run also downloads the Whisper model (~1.5 GB for large-v3-turbo); after that,
transcription works offline.

## Try it

```bash
python -m g1preklad demo "¿Te gusta vivir en Paraguay?"   # test Claude without a microphone
python -m g1preklad run --sim                            # Mac microphone, display simulated in the terminal
```

In the simulator, play a Spanish or English video and watch the terminal.
Keys + Enter: `d`/`a` tap right/left, `aa` double tap, `ttt` triple tap, `H` hold right, `q` quit.

## With the glasses

1. Close the Even Realities app on your phone (the glasses accept only one connection at a time).
2. `python -m g1preklad run`

## Cost / offline

- **Speech-to-text** (Whisper) runs **locally** – free.
- **Translation and replies** use Claude Haiku – a fraction of a cent per sentence.
- **Fully offline**: `brew install ollama && ollama pull qwen2.5:7b`, then in `config.toml`
  set `[llm] backend = "ollama"` and `model = "qwen2.5:7b"`. Quality will be noticeably lower.

## Tuning

- Subtitles too slow → `sentence_pause_s = 0.5`, smaller Whisper model.
- Suggestions appear too early / late → `turn_end_s` (default 1.5 s of silence).
- Picks up background noise → raise `[audio] threshold`.
- Odd line wrapping → `[glasses] chars_per_line`.
- Want to see the spelling of replies too → `show_spelling = true`.

## How it works

```
mic (Mac / glasses) → speech segmentation → Whisper (text + language)
   → Claude: Czech translation → G1 display (BLE, Nordic UART, command 0x4E)
   → silence = speaker finished → Claude: 3 replies + pronunciation → G1 display
```

| File | Purpose |
|---|---|
| `g1preklad/protocol.py` | G1 BLE protocol (UUIDs, 0x4E text, 0x0E mic, 0xF5 events, heartbeat) |
| `g1preklad/glasses.py` | Connection to both arms (bleak) + terminal simulator |
| `g1preklad/audio.py` | Mac / glasses microphone (LC3), speech segmentation |
| `g1preklad/ai.py` | Whisper (mlx / faster-whisper / OpenAI), Claude / Ollama, prompts |
| `g1preklad/app.py` | Translator logic and CLI |

Tests (no hardware needed): `python -m pytest`

## Status

The BLE protocol follows Even Realities' official
[EvenDemoApp](https://github.com/even-realities/EvenDemoApp) and community documentation.
**It has not yet been tested on real hardware** – line wrapping, heartbeat interval and TouchBar
events may need tuning. If something doesn't work, run `python -m g1preklad -v run` and open an issue
with the log.

Using the glasses' own microphone (`[audio] source = "glasses"`) requires Google's
[liblc3](https://github.com/google/liblc3); the default is the Mac microphone.

## Disclaimer

Not affiliated with or endorsed by Even Realities. Use at your own risk.

## License

MIT
