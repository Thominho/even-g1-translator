<div align="center">

<img src="docs/app-icon.svg" width="120" alt="G1 Translator">

# Even G1 Live Translator

**Realtime spraakvertaling met kant-en-klare antwoorden voor de slimme bril Even Realities G1**

[![iOS 17+](https://img.shields.io/badge/iOS-17%2B-black.svg)](ios)
[![macOS](https://img.shields.io/badge/macOS-Python%203.11%2B-blue.svg)](#-mac-app)
[![License: MIT](https://img.shields.io/badge/license-MIT-green.svg)](LICENSE)
[![Even Realities G1](https://img.shields.io/badge/device-Even%20Realities%20G1-black.svg)](https://www.evenrealities.com/g1)
[![GitHub stars](https://img.shields.io/github/stars/Thominho/even-g1-translator?style=social)](https://github.com/Thominho/even-g1-translator/stargazers)

⭐ *Heb je er iets aan gehad? Een ster helpt anderen het te vinden – bedankt!*

[🇬🇧 English](README.md) · [🇨🇿 Čeština](README.cs.md) · [🇸🇰 Slovenčina](README.sk.md) · [🇩🇪 Deutsch](README.de.md) · [🇪🇸 Español](README.es.md)<br>
[🇫🇷 Français](README.fr.md) · [🇮🇹 Italiano](README.it.md) · [🇵🇹 Português](README.pt.md) · [🇵🇱 Polski](README.pl.md) · **🇳🇱 Nederlands**

</div>

---

Iemand spreekt je aan in een taal die je niet kent. Je **Even Realities G1** toont een **live
vertaling**, vertelt je **welke taal** het is en biedt, zodra de ander klaar is, **drie kant-en-klare
antwoorden in diens taal** met uitspraakhulp. Lees er één hardop voor en de bril stelt voor **wat je terug
kunt vragen**. Iets anders zeggen? **Zeg het in je eigen taal** en zie het vertaald. De telefoon blijft in
je zak.

<p align="center"><img src="docs/demo.svg" alt="Live vertaling en drie antwoordsuggesties met uitspraak" width="900"></p>

## Inhoud

- [Functies](#functies)
- [Hoe het werkt](#hoe-het-werkt)
- [📱 iPhone-app](#-iphone-app) – aanbevolen
- [Bediening](#bediening)
- [Je taal kiezen](#je-taal-kiezen)
- [💻 Mac-app](#-mac-app)
- [Kosten en privacy](#kosten-en-privacy)
- [Problemen oplossen](#problemen-oplossen)
- [Projectstructuur](#projectstructuur)
- [Bijdragen](#bijdragen)

## Functies

- 💬 **Live vertaling** zin voor zin, met het gesprek tot nu toe als context.
- 🏷️ **Taallabel** bij de eerste zin.
- ✅ **Drie antwoorden op één scherm** zodra de ander klaar is – *ja*, *beleefd nee*, *vervolgvraag* (of „kunt u dat langzamer herhalen?”).
- 🗣️ **Uitspraak voor jou geschreven** – zoals je het in je eigen taal leest.
- 🔁 **Houdt het gesprek gaande** – na je antwoord stelt de bril voor wat je terug kunt vragen (*„En u?”* plus twee zinnige vragen).
- 🎙️ **Zeg alles** – houd de linker TouchBar vast, zeg het in je eigen taal en zie het in de zijne met uitspraak.
- 🙌 **Handsfree** – alles verschijnt vanzelf; gebaren zijn optioneel.
- 🎧 **Slimme microfoon** – luistert met de G1-bril *en* de iPhone en gebruikt degene die de spreker beter hoort, met automatische versterking. De telefoon kan in je zak blijven.
- ⚡ **Snel** – antwoorden en vragen worden op de achtergrond voorbereid en verschijnen zodra de spreker stopt.
- 🙊 **Herkent jou** – je eigen taal wordt nooit vertaald en de app weet wanneer je een suggestie hardop voorleest.
- 🌍 **Jouw taal** – vertalingen, uitspraak en tekst in de bril in en, cs, sk, de, es, fr, it, pt, pl, nl; app-interface in dezelfde 10 talen.

## Hoe het werkt

<p align="center"><img src="docs/how-it-works.svg" alt="Microfoon → spraak naar tekst → vertaling via de Claude API → G1-scherm; antwoorden na elke zin voorbereid" width="900"></p>

De bril is scherm en microfoons – de telefoon doet het denkwerk. Spraak wordt omgezet in tekst op de
iPhone (iOS-spraakherkenning) of de Mac (Whisper); vertalingen, antwoorden en uitspraak komen van de
**Claude API** (standaard Claude Haiku – snel en goedkoop). De app praat rechtstreeks met de G1 via
**Bluetooth LE**, volgens het protocol van de officiële
[EvenDemoApp](https://github.com/even-realities/EvenDemoApp) van Even Realities.

## 📱 iPhone-app

Native SwiftUI-app in [`ios/`](ios) – alles draait op de iPhone, tijdens gebruik is geen computer nodig.

**Installatie** (eenmalig, vereist een Mac met Xcode – een gratis Apple ID volstaat):

```bash
brew install xcodegen
git clone https://github.com/Thominho/even-g1-translator.git
cd even-g1-translator/ios && xcodegen && open G1Translator.xcodeproj
```

In Xcode: **Signing & Capabilities** → kies je **Team** (je Apple ID) en een unieke **Bundle Identifier**,
selecteer je iPhone en druk op **▶ Run**. Vertrouw op de iPhone het ontwikkelaarscertificaat
(*Instellingen → Algemeen → VPN en apparaatbeheer*) en zet de *Ontwikkelaarsmodus* aan.

> Met een gratis Apple ID werkt de app **7 dagen** – sluit daarna de iPhone aan en druk opnieuw op Run.

**Eerste start** – open *Instellingen* in de app:

| Instelling | |
|---|---|
| Zij spreken | De gesprekstaal (iOS-herkenning moet die vooraf weten) |
| Jouw taal | Vertalingen, uitspraak en tekst in de bril |
| App-taal | Taal van de interface – standaard Engels, 10 talen |
| API-sleutel | Uit de [Anthropic Console](https://console.anthropic.com); de modellenlijst laadt vanzelf, Claude Haiku voorgeselecteerd |
| Microfoon | **Automatisch (beste)** (de beste van bril en iPhone), G1-bril of iPhone / AirPods |
| Betere herkenning (online) | Herkenning op servers van Apple – nauwkeuriger bij lawaai, vereist internet |

Sluit dan **de Even Realities-app** (de G1 accepteert één verbinding tegelijk), zet de bril op en tik op **Starten**.

## Bediening

<p align="center"><img src="docs/controls.svg" alt="Links vasthouden: zeg het in je eigen taal. Dubbeltik: suggesties verbergen / nieuw gesprek. Drievoudige tik: pauze." width="900"></p>

Omhoog kijken toont de suggesties opnieuw. In de iPhone-app zijn dezelfde acties beschikbaar als knoppen.

## Je taal kiezen

Stel **Jouw taal** (iPhone) of `native_language` (Mac) in. Alles volgt die keuze:

| | Wat verandert |
|---|---|
| Vertaling | Alles wordt naar jouw taal vertaald |
| Genegeerde spraak | Je eigen taal wordt nooit vertaald |
| Uitspraak | Voor jou geschreven – een Engelstalige ziet `see, meh GOOS-tah`, een Tsjech `sí, me gusta` |
| Zeg het | Je dicteert in je eigen taal |
| Tekst in de bril | en, cs, sk, de, es, fr, it, pt, pl, nl (andere talen gebruiken Engels) |

Mis je je taal? Voeg die toe in [`g1preklad/i18n.py`](g1preklad/i18n.py) en [`ios/G1Translator/I18n.swift`](ios/G1Translator/I18n.swift) – pull requests welkom.

## 💻 Mac-app

De oorspronkelijke Python-versie – draait op een Mac met Bluetooth en herkent de taal automatisch (Whisper).

```bash
git clone https://github.com/Thominho/even-g1-translator.git && cd even-g1-translator
python3 -m venv .venv && source .venv/bin/activate
pip install -e . && pip install mlx-whisper      # Intel Mac: pip install faster-whisper
cp config.example.toml config.toml                # standaard: Claude API met Claude Haiku
export ANTHROPIC_API_KEY="..."
python -m g1preklad demo "¿Te gusta vivir en Paraguay?"   # test zonder microfoon
python -m g1preklad run --sim                            # gesimuleerd scherm in de terminal
python -m g1preklad run                                  # met de bril
```

Belangrijkste instellingen in `config.toml`: `native_language`, `replies`, `follow_up_questions`, `reply_layout`,
`turn_end_s`, `prefetch_replies`, `[stt] backend`, `[llm] backend` (`anthropic`, `openai` of `ollama`
voor volledig offline gebruik). Zie [`config.example.toml`](config.example.toml).

## Kosten en privacy

| Onderdeel | Waar | Kosten |
|---|---|---|
| Spraak → tekst | Op de iPhone / Mac (online herkenning optioneel) | Gratis |
| Vertaling, antwoorden | Claude API (Claude Haiku) | Fracties van een cent per zin |
| Volledig offline (Mac) | Whisper + [Ollama](https://ollama.com) | Gratis, lagere kwaliteit |

Alleen tekst gaat naar de API – er wordt geen audio opgeslagen. De API-sleutel staat in de iOS-sleutelhanger.

## Problemen oplossen

| Probleem | Oplossing |
|---|---|
| Bril niet gevonden | Sluit de Even Realities-app; haal de bril uit de koker |
| Spreker slecht te verstaan | Microfoon → *Automatisch (beste)* of *iPhone / AirPods*, zet *Betere herkenning (online)* aan |
| Suggesties te vroeg / te laat | Pas *Pauze voor antwoorden* aan |
| Regels breken vreemd af | Pas *Tekens per regel* aan |
| App werkt na een week niet meer | Limiet van gratis Apple ID – druk in Xcode opnieuw op ▶ Run |

> **Status:** vroege versie – bouwt en draait op iPhone; testen met een echte bril in dagelijks gebruik loopt.
> Bugmeldingen zijn zeer welkom.

## Projectstructuur

| | |
|---|---|
| [`ios/`](ios) | iPhone-app (SwiftUI): G1-Bluetooth, brilmicrofoon (LC3 via Google liblc3), spraakherkenning, Claude API |
| [`g1preklad/`](g1preklad) | Mac-app (Python): protocol, bril, audio, Whisper, LLM-backends |
| [`tests/`](tests) | Python-tests zonder hardware: `python -m pytest` |
| [`docs/`](docs) | Illustraties |

## Bijdragen

Issues en pull requests zijn welkom – vooral ervaringen uit de praktijk, meer talen en een Android-versie.

## ⭐ Steun het project

Als dit project je heeft geholpen iemand te begrijpen of je een ongemakkelijk moment in het buitenland heeft bespaard,
**zou ik een ster erg waarderen** – zo vinden anderen het ook. Alvast bedankt! 🙏

## Licentie

[MIT](LICENSE) · LC3-decoder: Google liblc3 (Apache 2.0)

*Niet verbonden aan of goedgekeurd door Even Realities. „Even Realities” en „G1” zijn handelsmerken van hun respectieve eigenaar.*
