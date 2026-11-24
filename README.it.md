<div align="center">

<img src="docs/app-icon.svg" width="120" alt="G1 Translator">

# Even G1 Live Translator

**Traduzione vocale in tempo reale con risposte pronte da dire per gli occhiali smart Even Realities G1**

[![iOS 17+](https://img.shields.io/badge/iOS-17%2B-black.svg)](ios)
[![macOS](https://img.shields.io/badge/macOS-Python%203.11%2B-blue.svg)](#-app-per-mac)
[![License: MIT](https://img.shields.io/badge/license-MIT-green.svg)](LICENSE)
[![Even Realities G1](https://img.shields.io/badge/device-Even%20Realities%20G1-black.svg)](https://www.evenrealities.com/g1)
[![GitHub stars](https://img.shields.io/github/stars/Thominho/even-g1-translator?style=social)](https://github.com/Thominho/even-g1-translator/stargazers)

⭐ *Ti è stato utile? Una stella aiuta altri a trovarlo – grazie!*

[🇬🇧 English](README.md) · [🇨🇿 Čeština](README.cs.md) · [🇸🇰 Slovenčina](README.sk.md) · [🇩🇪 Deutsch](README.de.md) · [🇪🇸 Español](README.es.md)<br>
[🇫🇷 Français](README.fr.md) · **🇮🇹 Italiano** · [🇵🇹 Português](README.pt.md) · [🇵🇱 Polski](README.pl.md) · [🇳🇱 Nederlands](README.nl.md)

</div>

---

Qualcuno ti parla in una lingua che non conosci. I tuoi occhiali **Even Realities G1** mostrano una
**traduzione dal vivo**, ti dicono **di che lingua** si tratta e, appena l'altra persona ha finito, offrono
**tre risposte pronte da dire nella sua lingua** con la pronuncia. Leggine una ad alta voce e gli occhiali
suggeriscono **cosa chiedere a tua volta**. Vuoi dire altro? **Dillo nella tua lingua** e vedilo tradotto.
Il telefono resta in tasca.

<p align="center"><img src="docs/demo.svg" alt="Traduzione dal vivo e tre suggerimenti di risposta con pronuncia" width="900"></p>

## Indice

- [Funzioni](#funzioni)
- [Come funziona](#come-funziona)
- [📱 App per iPhone](#-app-per-iphone) – consigliata
- [Comandi](#comandi)
- [Scegliere la lingua](#scegliere-la-lingua)
- [💻 App per Mac](#-app-per-mac)
- [Costi e privacy](#costi-e-privacy)
- [Risoluzione dei problemi](#risoluzione-dei-problemi)
- [Struttura del progetto](#struttura-del-progetto)
- [Contribuire](#contribuire)

## Funzioni

- 💬 **Traduzione dal vivo** frase per frase, con la conversazione precedente come contesto.
- 🏷️ **Indicazione della lingua** alla prima frase.
- ✅ **Tre risposte su una schermata** quando l'altra persona ha finito – *sì*, *no gentile*, *domanda* (o «può ripetere più lentamente?»).
- 🗣️ **Pronuncia scritta per te** – come si legge nella tua lingua.
- 🔁 **Porta avanti la conversazione** – dopo la tua risposta gli occhiali suggeriscono cosa chiedere (*«E lei?»* più due domande sensate).
- 🎙️ **Di' qualsiasi cosa** – tieni premuto il TouchBar sinistro, dillo nella tua lingua e vedilo nella sua con la pronuncia.
- 🙌 **Mani libere** – tutto appare da solo; i gesti sono facoltativi.
- 🎧 **Microfono intelligente** – ascolta con gli occhiali G1 *e* l'iPhone e usa quello che sente meglio l'interlocutore, con guadagno automatico. Il telefono può restare in tasca.
- ⚡ **Veloce** – risposte e domande vengono preparate in background e compaiono appena l'interlocutore tace.
- 🙊 **Ti riconosce** – la tua lingua non viene mai tradotta e l'app sa quando leggi ad alta voce un suggerimento.
- 🌍 **La tua lingua** – traduzioni, pronuncia e testi negli occhiali in en, cs, sk, de, es, fr, it, pt, pl, nl; interfaccia dell'app nelle stesse 10 lingue.

## Come funziona

<p align="center"><img src="docs/how-it-works.svg" alt="Microfono → voce in testo → traduzione con l'API di Claude → display G1; risposte preparate dopo ogni frase" width="900"></p>

Gli occhiali sono display e microfoni – a pensare è il telefono. La voce diventa testo sull'iPhone
(riconoscimento vocale di iOS) o sul Mac (Whisper); traduzioni, risposte e pronuncia arrivano dall'**API
di Claude** (Claude Haiku di default – veloce ed economico). L'app parla direttamente con i G1 via
**Bluetooth LE**, seguendo il protocollo dell'app ufficiale
[EvenDemoApp](https://github.com/even-realities/EvenDemoApp) di Even Realities.

## 📱 App per iPhone

App SwiftUI nativa in [`ios/`](ios) – tutto gira sull'iPhone, durante l'uso non serve un computer.

**Installazione** (una volta, serve un Mac con Xcode – basta un ID Apple gratuito):

```bash
brew install xcodegen
git clone https://github.com/Thominho/even-g1-translator.git
cd even-g1-translator/ios && xcodegen && open G1Translator.xcodeproj
```

In Xcode: **Signing & Capabilities** → scegli il tuo **Team** (il tuo ID Apple) e un **Bundle Identifier** univoco,
seleziona il tuo iPhone e premi **▶ Run**. Sull'iPhone, autorizza il certificato sviluppatore
(*Impostazioni → Generali → VPN e gestione dispositivi*) e attiva la *Modalità sviluppatore*.

> Con un ID Apple gratuito l'app funziona per **7 giorni** – poi collega l'iPhone e premi di nuovo Run.

**Primo avvio** – apri *Impostazioni* nell'app:

| Impostazione | |
|---|---|
| Parlano | La lingua della conversazione (il riconoscimento di iOS deve saperla in anticipo) |
| La tua lingua | Traduzioni, pronuncia e testi negli occhiali |
| Lingua dell'app | Lingua dell'interfaccia – inglese di default, 10 lingue |
| Chiave API | Dalla [Anthropic Console](https://console.anthropic.com); l'elenco dei modelli si carica da solo, Claude Haiku preselezionato |
| Microfono | **Automatico (il migliore)** (il migliore tra occhiali e iPhone), Occhiali G1 o iPhone / AirPods |
| Riconoscimento migliore (online) | Riconoscimento sui server Apple – più preciso nel rumore, richiede internet |

Poi **chiudi l'app Even Realities** (i G1 accettano una sola connessione alla volta), indossa gli occhiali e tocca **Avvia**.

## Comandi

<p align="center"><img src="docs/controls.svg" alt="Tieni premuto a sinistra: dillo nella tua lingua. Doppio tocco: nascondi suggerimenti / nuova conversazione. Triplo tocco: pausa." width="900"></p>

Guardare in alto mostra di nuovo i suggerimenti. Nell'app per iPhone le stesse azioni sono disponibili come pulsanti.

## Scegliere la lingua

Imposta **La tua lingua** (iPhone) o `native_language` (Mac). Tutto si adegua:

| | Cosa cambia |
|---|---|
| Traduzione | Tutto viene tradotto nella tua lingua |
| Voce ignorata | La tua lingua non viene mai tradotta |
| Pronuncia | Scritta per te – chi parla inglese vede `see, meh GOOS-tah`, un ceco `sí, me gusta` |
| Dillo | Detti nella tua lingua |
| Testi negli occhiali | en, cs, sk, de, es, fr, it, pt, pl, nl (le altre lingue usano l'inglese) |

Manca la tua lingua? Aggiungila in [`g1preklad/i18n.py`](g1preklad/i18n.py) e [`ios/G1Translator/I18n.swift`](ios/G1Translator/I18n.swift) – le pull request sono benvenute.

## 💻 App per Mac

La versione Python originale – gira su un Mac con Bluetooth e riconosce la lingua automaticamente (Whisper).

```bash
git clone https://github.com/Thominho/even-g1-translator.git && cd even-g1-translator
python3 -m venv .venv && source .venv/bin/activate
pip install -e . && pip install mlx-whisper      # Intel Mac: pip install faster-whisper
cp config.example.toml config.toml                # default: API di Claude con Claude Haiku
export ANTHROPIC_API_KEY="..."
python -m g1preklad demo "¿Te gusta vivir en Paraguay?"   # prova senza microfono
python -m g1preklad run --sim                            # display simulato nel terminale
python -m g1preklad run                                  # con gli occhiali
```

Impostazioni principali in `config.toml`: `native_language`, `replies`, `follow_up_questions`, `reply_layout`,
`turn_end_s`, `prefetch_replies`, `[stt] backend`, `[llm] backend` (`anthropic`, `openai` o `ollama`
per l'uso completamente offline). Vedi [`config.example.toml`](config.example.toml).

## Costi e privacy

| Parte | Dove | Costo |
|---|---|---|
| Voce → testo | Sull'iPhone / Mac (riconoscimento online facoltativo) | Gratis |
| Traduzione, risposte | API di Claude (Claude Haiku) | Frazioni di centesimo per frase |
| Completamente offline (Mac) | Whisper + [Ollama](https://ollama.com) | Gratis, qualità inferiore |

All'API viene inviato solo testo – nessun audio viene salvato. La chiave API è conservata nel Portachiavi di iOS.

## Risoluzione dei problemi

| Problema | Soluzione |
|---|---|
| Occhiali non trovati | Chiudi l'app Even Realities; togli gli occhiali dalla custodia |
| L'interlocutore si capisce male | Microfono → *Automatico (il migliore)* o *iPhone / AirPods*, attiva *Riconoscimento migliore (online)* |
| Suggerimenti troppo presto / tardi | Regola *Pausa prima delle risposte* |
| Le righe vanno a capo in modo strano | Regola *Caratteri per riga* |
| L'app ha smesso di funzionare dopo una settimana | Limite dell'ID Apple gratuito – premi di nuovo ▶ Run in Xcode |

> **Stato:** versione iniziale – si compila e funziona su iPhone; i test con occhiali veri nell'uso quotidiano sono in corso.
> Le segnalazioni di bug sono molto gradite.

## Struttura del progetto

| | |
|---|---|
| [`ios/`](ios) | App per iPhone (SwiftUI): Bluetooth G1, microfono degli occhiali (LC3 con Google liblc3), riconoscimento vocale, API di Claude |
| [`g1preklad/`](g1preklad) | App per Mac (Python): protocollo, occhiali, audio, Whisper, backend LLM |
| [`tests/`](tests) | Test Python senza hardware: `python -m pytest` |
| [`docs/`](docs) | Illustrazioni |

## Contribuire

Issue e pull request sono benvenute – soprattutto esperienze d'uso reale, altre lingue e una versione Android.

## ⭐ Sostieni il progetto

Se questo progetto ti ha aiutato a capire qualcuno o ti ha evitato un momento imbarazzante all'estero,
**mi farebbe piacere una stella** – aiuta altri a trovarlo. Grazie in anticipo! 🙏

## Licenza

[MIT](LICENSE) · Decoder LC3: Google liblc3 (Apache 2.0)

*Non affiliato né approvato da Even Realities. «Even Realities» e «G1» sono marchi del rispettivo proprietario.*
