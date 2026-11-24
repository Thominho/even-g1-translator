<div align="center">

# Even G1 Live Translator

**Real-time speech translation with smart reply suggestions for Even Realities G1 smart glasses**

[![Python 3.11+](https://img.shields.io/badge/python-3.11%2B-blue.svg)](https://www.python.org/)
[![Platform: macOS](https://img.shields.io/badge/platform-macOS-lightgrey.svg)](#requirements)
[![License: MIT](https://img.shields.io/badge/license-MIT-green.svg)](LICENSE)
[![Even Realities G1](https://img.shields.io/badge/device-Even%20Realities%20G1-black.svg)](https://www.evenrealities.com/g1)

**English** · [Čeština](README.cs.md)

</div>

---

Someone speaks to you in a language you don't know – Spanish, English, German, anything.
Your **Even Realities G1** glasses show a **live translation**, tell you **which language** is being
spoken and, as soon as the speaker finishes, offer **three ready-to-say replies in their language**,
with a pronunciation guide so you can simply read them out loud.

```
 ┌─────────────────────────────────────────┐        ┌─────────────────────────────────────────┐
 │ [ŠPANĚLŠTINA]                           │        │ ANO 1/3: Ano, moc se mi tam líbí.       │
 │ Ahoj, odkud jsi? Líbí se ti Paraguay?   │  ──►   │ > sí, me gusta mučo                     │
 │                                         │        │                                         │
 └─────────────────────────────────────────┘        └─────────────────────────────────────────┘
    while they speak: live translation             finished → reply 1 (tap right ►)

 ┌─────────────────────────────────────────┐        ┌─────────────────────────────────────────┐
 │ NE 2/3: Upřímně, moc ne.                │        │ OTÁZKA 3/3: A ty jsi odkud?             │
 │ > no mučo, la verdad                    │  ──►   │ > i tu, de donde eres                   │
 │                                         │        │                                         │
 └─────────────────────────────────────────┘        └─────────────────────────────────────────┘
    reply 2: polite no (tap right ►)               reply 3: follow-up question
```

> **Native language:** the app currently translates **into Czech** and writes pronunciation for Czech
> speakers. See [Adapting to another language](#adapting-to-another-language).

## Table of contents

- [Features](#features)
- [How it works](#how-it-works)
- [Requirements](#requirements)
- [Quick start](#quick-start)
- [Using it with the glasses](#using-it-with-the-glasses)
- [Controls](#controls)
- [Configuration](#configuration)
- [Offline mode and costs](#offline-mode-and-costs)
- [Adapting to another language](#adapting-to-another-language)
- [Project structure](#project-structure)
- [Troubleshooting](#troubleshooting)
- [Contributing](#contributing)
- [License](#license)

## Features

- 🌍 **Automatic language detection** – works with ~100 languages and switches on the fly when a different person speaks another language.
- 💬 **Live translation** sentence by sentence, using the conversation so far as context.
- 🏷️ **Language label** on the first sentence, so you always know what you're hearing.
- ✅ **Three reply suggestions** when the speaker finishes: *yes / agree*, *polite no*, and a *follow-up question* (or "could you repeat that more slowly?" when the speech was unclear).
- 🗣️ **Pronunciation guide** written for your native language – no need to know how the foreign words are spelled.
- 🙊 **Your own speech is ignored** – native-language speech is never translated, and the app recognises when you read one of the suggestions aloud.
- 🔒 **Speech recognition runs locally** on your Mac (Whisper); a **fully offline mode** is available with a local model.
- 🧪 **Terminal simulator** – develop and test without the glasses.

## How it works

```
 microphone ─► speech segmentation ─► Whisper (text + language)
                                          │
                                          ├─► LLM: translation ─────────────► G1 display (Bluetooth LE)
                                          │
                     speaker finished ────┴─► LLM: 3 replies + pronunciation ─► G1 display
```

The app talks to the G1 directly over **Bluetooth Low Energy** (Nordic UART, both temples), based on
Even Realities' official [EvenDemoApp](https://github.com/even-realities/EvenDemoApp) protocol.

## Requirements

- **macOS** with Bluetooth (Apple Silicon recommended for fast local speech recognition)
- **Python 3.11+**
- **Even Realities G1** smart glasses (optional for the simulator)
- An LLM: an **Anthropic** or **OpenAI** API key, or **Ollama** for fully offline use

## Quick start

```bash
git clone https://github.com/Thominho/even-g1-translator.git
cd even-g1-translator

python3 -m venv .venv && source .venv/bin/activate
pip install -e .
pip install mlx-whisper              # Apple Silicon  (Intel: pip install faster-whisper)

cp config.example.toml config.toml   # then set [llm] backend and model
export ANTHROPIC_API_KEY="..."       # or OPENAI_API_KEY – add it to ~/.zshrc to keep it
```

Test the translation and replies without a microphone:

```bash
python -m g1preklad demo "¿Te gusta vivir en Paraguay?"
```

Run the full app with a **simulated display** in the terminal (uses your Mac microphone –
try playing a video in a foreign language):

```bash
python -m g1preklad run --sim
```

On the first run macOS asks for **microphone** and **Bluetooth** access for your terminal, and the
Whisper model (~1.5 GB) is downloaded once.

## Using it with the glasses

1. **Close the Even Realities app** on your phone – the G1 accepts only one connection at a time.
2. Take the glasses out of the case and put them on.
3. Run:

```bash
python -m g1preklad run
```

## Controls

| TouchBar gesture | Action |
|---|---|
| Tap right / left | Next / previous reply suggestion |
| Double tap | Close suggestions · again: start a new conversation |
| Hold right / look up | Show the suggestions again |
| Tap left (no suggestions shown) | Toggle the original text above the translation |
| Triple tap | Pause / resume |

Simulator keys (type + Enter): `d` / `a` tap right / left · `aa` double tap · `ttt` triple tap · `H` hold right · `q` quit.

## Configuration

All settings live in `config.toml` (see [`config.example.toml`](config.example.toml)).

| Setting | Default | Description |
|---|---|---|
| `translator.replies` | `true` | Offer reply suggestions |
| `translator.turn_end_s` | `1.5` | Silence (s) that ends the speaker's turn |
| `translator.sentence_pause_s` | `0.7` | Pause between sentences – lower means faster subtitles |
| `translator.show_spelling` | `false` | Show the written reply below the pronunciation |
| `translator.ignore_languages` | `["cs"]` | Languages that are never translated |
| `stt.backend` | `mlx-whisper` | `mlx-whisper`, `faster-whisper` or `openai` |
| `llm.backend` | `anthropic` | `anthropic`, `openai` or `ollama` |
| `audio.source` | `mac` | `mac` (Mac/AirPods mic) or `glasses` (G1 mic, needs [liblc3](https://github.com/google/liblc3)) |
| `glasses.chars_per_line` | `38` | Line width on the G1 display |

## Offline mode and costs

| Component | Default | Cost |
|---|---|---|
| Speech recognition | Whisper, **local** | Free |
| Translation + replies | Cloud LLM (fast, low-cost model) | Fractions of a cent per sentence |
| Fully offline | [Ollama](https://ollama.com) + `qwen2.5:7b` | Free, lower quality |

```bash
brew install ollama && ollama pull qwen2.5:7b
# config.toml →  [llm] backend = "ollama"   model = "qwen2.5:7b"
```

## Adapting to another language

The target language is Czech. To use another native language, change `HOME_LANG` in
[`g1preklad/app.py`](g1preklad/app.py), the prompts in [`g1preklad/ai.py`](g1preklad/ai.py)
(translation target and pronunciation spelling) and `ignore_languages` in your config.
Pull requests that make this configurable are very welcome.

## Project structure

| Path | Purpose |
|---|---|
| [`g1preklad/protocol.py`](g1preklad/protocol.py) | G1 BLE protocol – text (0x4E), microphone (0x0E), TouchBar events (0xF5), heartbeat |
| [`g1preklad/glasses.py`](g1preklad/glasses.py) | Connection to both temples (`bleak`) and the terminal simulator |
| [`g1preklad/audio.py`](g1preklad/audio.py) | Mac / G1 microphone (LC3), speech segmentation |
| [`g1preklad/ai.py`](g1preklad/ai.py) | Speech-to-text backends, LLM backends, prompts |
| [`g1preklad/app.py`](g1preklad/app.py) | Translator logic and command-line interface |
| [`tests/`](tests) | Tests that run without hardware: `python -m pytest` |

## Troubleshooting

| Problem | Fix |
|---|---|
| Glasses not found | Close the Even Realities app / turn off Bluetooth on your phone; run `python -m g1preklad -v run` |
| Lines wrap oddly | Adjust `glasses.chars_per_line` |
| Subtitles lag | Lower `sentence_pause_s`, use a smaller Whisper model |
| Suggestions appear too early / late | Adjust `turn_end_s` |
| Background noise gets translated | Raise `audio.threshold` |
| Connection drops | Lower `glasses.heartbeat_s` |

> **Project status:** early release. The BLE implementation follows the official protocol
> documentation but has had limited testing on real hardware. Bug reports with a `-v` log are appreciated.

## Contributing

Issues and pull requests are welcome – especially hardware test reports, support for more native
languages, and Linux / Windows testing.

## ⭐ Support the project

If this project helped you understand someone, or saved you an awkward moment abroad,
**please consider giving it a star** – it helps others find it. Thank you in advance! 🙏

## License

[MIT](LICENSE)

*Not affiliated with or endorsed by Even Realities. "Even Realities" and "G1" are trademarks of their respective owner.*
