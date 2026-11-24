<div align="center">

<img src="docs/app-icon.svg" width="120" alt="G1 Translator">

# Even G1 Live Translator

**Preklad reči v reálnom čase s odpoveďami pripravenými na vyslovenie pre inteligentné okuliare Even Realities G1**

[![iOS 17+](https://img.shields.io/badge/iOS-17%2B-black.svg)](ios)
[![macOS](https://img.shields.io/badge/macOS-Python%203.11%2B-blue.svg)](#-aplikácia-pre-mac)
[![License: MIT](https://img.shields.io/badge/license-MIT-green.svg)](LICENSE)
[![Even Realities G1](https://img.shields.io/badge/device-Even%20Realities%20G1-black.svg)](https://www.evenrealities.com/g1)
[![GitHub stars](https://img.shields.io/github/stars/Thominho/even-g1-translator?style=social)](https://github.com/Thominho/even-g1-translator/stargazers)

⭐ *Pomohol vám projekt? Hviezdička pomôže, aby ho našli aj ďalší – ďakujem!*

[🇬🇧 English](README.md) · [🇨🇿 Čeština](README.cs.md) · **🇸🇰 Slovenčina** · [🇩🇪 Deutsch](README.de.md) · [🇪🇸 Español](README.es.md)<br>
[🇫🇷 Français](README.fr.md) · [🇮🇹 Italiano](README.it.md) · [🇵🇹 Português](README.pt.md) · [🇵🇱 Polski](README.pl.md) · [🇳🇱 Nederlands](README.nl.md)

</div>

---

Niekto na vás hovorí jazykom, ktorý nepoznáte. Okuliare **Even Realities G1** zobrazujú **živý
preklad**, povedia vám, **aký je to jazyk**, a hneď ako hovoriaci dohovorí, ponúknu **tri odpovede
pripravené na vyslovenie v jeho jazyku** s návodom na výslovnosť. Jednu prečítate nahlas a okuliare
navrhnú, **na čo sa opýtať späť**. Chcete povedať niečo iné? **Povedzte to svojím jazykom** a uvidíte
to preložené. Telefón zostáva vo vrecku.

<p align="center"><img src="docs/demo.svg" alt="Živý preklad a tri návrhy odpovedí s výslovnosťou" width="900"></p>

## Obsah

- [Funkcie](#funkcie)
- [Ako to funguje](#ako-to-funguje)
- [📱 Aplikácia pre iPhone](#-aplikácia-pre-iphone) – odporúčané
- [Ovládanie](#ovládanie)
- [Výber jazyka](#výber-jazyka)
- [💻 Aplikácia pre Mac](#-aplikácia-pre-mac)
- [Náklady a súkromie](#náklady-a-súkromie)
- [Riešenie problémov](#riešenie-problémov)
- [Štruktúra projektu](#štruktúra-projektu)
- [Prispievanie](#prispievanie)

## Funkcie

- 💬 **Živý preklad** po vetách, s doterajším rozhovorom ako kontextom.
- 🏷️ **Označenie jazyka** pri prvej vete.
- ✅ **Tri odpovede na jednej obrazovke**, keď hovoriaci dohovorí – *áno*, *zdvorilé nie*, *doplňujúca otázka* (alebo „môžete to zopakovať pomalšie?“).
- 🗣️ **Výslovnosť písaná pre vás** – tak, ako ju čítate vo svojom jazyku.
- 🔁 **Rozvíja rozhovor** – po vašej odpovedi okuliare navrhnú, na čo sa opýtať späť (*„A vy?“* a dve rozumné otázky).
- 🎙️ **Povedzte čokoľvek** – podržte ľavý TouchBar, povedzte to svojím jazykom a uvidíte to v jeho jazyku s výslovnosťou.
- 🙌 **Bez rúk** – všetko sa zobrazí samo; gestá sú voliteľné.
- 🎧 **Inteligentný mikrofón** – počúva okuliarmi G1 *aj* iPhonom a použije ten, ktorý hovoriaceho počuje lepšie, s automatickým zosilnením. Telefón môže zostať vo vrecku.
- ⚡ **Rýchle** – odpovede aj otázky sa pripravujú na pozadí, takže sa zobrazia hneď, ako hovoriaci stíchne.
- 🙊 **Rozpozná vás** – váš jazyk sa nikdy neprekladá a aplikácia vie, keď nahlas čítate návrh.
- 🌍 **Váš jazyk** – preklady, výslovnosť a popisy v okuliaroch v en, cs, sk, de, es, fr, it, pt, pl, nl; rozhranie aplikácie v tých istých 10 jazykoch.

## Ako to funguje

<p align="center"><img src="docs/how-it-works.svg" alt="Mikrofón → reč na text → preklad cez Claude API → displej G1; odpovede sa pripravujú po každej vete" width="900"></p>

Okuliare sú displej a mikrofóny – rozmýšľa telefón. Reč sa mení na text v telefóne
(rozpoznávanie reči iOS) alebo v Macu (Whisper); preklady, odpovede a výslovnosť zabezpečuje
**Claude API** (predvolene Claude Haiku – rýchly a lacný). Aplikácia komunikuje s G1 priamo cez
**Bluetooth LE** podľa protokolu oficiálnej aplikácie
[EvenDemoApp](https://github.com/even-realities/EvenDemoApp) od Even Realities.

## 📱 Aplikácia pre iPhone

Natívna aplikácia SwiftUI v [`ios/`](ios) – všetko beží v iPhone, počas používania nepotrebujete počítač.

**Inštalácia** (raz, potrebujete Mac s Xcode – stačí bezplatné Apple ID):

```bash
brew install xcodegen
git clone https://github.com/Thominho/even-g1-translator.git
cd even-g1-translator/ios && xcodegen && open G1Translator.xcodeproj
```

V Xcode: **Signing & Capabilities** → zvoľte **Team** (svoje Apple ID) a jedinečný **Bundle Identifier**,
vyberte svoj iPhone a stlačte **▶ Run**. V iPhone dôverujte certifikátu vývojára
(*Nastavenia → Všeobecné → Správa VPN a zariadení*) a zapnite *Režim vývojára*.

> S bezplatným Apple ID aplikácia beží **7 dní** – potom pripojte iPhone a znova stlačte Run.

**Prvé spustenie** – v aplikácii otvorte *Nastavenia*:

| Nastavenie | |
|---|---|
| Hovorí | Jazyk rozhovoru (rozpoznávanie v iOS ho potrebuje vopred) |
| Váš jazyk | Preklady, výslovnosť a popisy v okuliaroch |
| Jazyk aplikácie | Jazyk rozhrania – predvolene angličtina, 10 jazykov |
| API kľúč | Z [Anthropic Console](https://console.anthropic.com); zoznam modelov sa načíta sám, predvolený je Claude Haiku |
| Mikrofón | **Automaticky (lepší)** (lepší z okuliarov a iPhonu), Okuliare G1 alebo iPhone / AirPods |
| Presnejšie rozpoznávanie (online) | Serverové rozpoznávanie Apple – presnejšie v hluku, potrebuje internet |

Potom **zatvorte aplikáciu Even Realities** (G1 prijíma len jedno pripojenie naraz), nasaďte si okuliare a ťuknite na **Spustiť**.

## Ovládanie

<p align="center"><img src="docs/controls.svg" alt="Podržanie vľavo: povedzte to svojím jazykom. Dvojité ťuknutie: skryť návrhy / nový rozhovor. Trojité ťuknutie: pauza." width="900"></p>

Pohľad hore znova zobrazí návrhy. V aplikácii pre iPhone sú tie isté akcie dostupné ako tlačidlá.

## Výber jazyka

Nastavte **Váš jazyk** (iPhone) alebo `native_language` (Mac). Všetko sa podľa toho riadi:

| | Čo sa zmení |
|---|---|
| Preklad | Všetko sa prekladá do vášho jazyka |
| Ignorovaná reč | Váš vlastný jazyk sa nikdy neprekladá |
| Výslovnosť | Písaná pre vás – anglicky hovoriaci uvidí `see, meh GOOS-tah`, Čech `sí, me gusta` |
| Povedzte to | Diktujete vo svojom jazyku |
| Popisy v okuliaroch | en, cs, sk, de, es, fr, it, pt, pl, nl (ostatné jazyky použijú angličtinu) |

Chýba váš jazyk? Pridajte ho do [`g1preklad/i18n.py`](g1preklad/i18n.py) a [`ios/G1Translator/I18n.swift`](ios/G1Translator/I18n.swift) – pull requesty sú vítané.

## 💻 Aplikácia pre Mac

Pôvodná verzia v Pythone – beží na Macu s Bluetoothom a jazyk rozpozná automaticky (Whisper).

```bash
git clone https://github.com/Thominho/even-g1-translator.git && cd even-g1-translator
python3 -m venv .venv && source .venv/bin/activate
pip install -e . && pip install mlx-whisper      # Intel Mac: pip install faster-whisper
cp config.example.toml config.toml                # predvolene: Claude API s Claude Haiku
export ANTHROPIC_API_KEY="..."
python -m g1preklad demo "¿Te gusta vivir en Paraguay?"   # test bez mikrofónu
python -m g1preklad run --sim                            # simulovaný displej v termináli
python -m g1preklad run                                  # s okuliarmi
```

Hlavné nastavenia v `config.toml`: `native_language`, `replies`, `follow_up_questions`, `reply_layout`,
`turn_end_s`, `prefetch_replies`, `[stt] backend`, `[llm] backend` (`anthropic`, `openai` alebo `ollama`
pre úplne offline použitie). Pozrite [`config.example.toml`](config.example.toml).

## Náklady a súkromie

| Časť | Kde | Cena |
|---|---|---|
| Reč → text | V iPhone / Macu (online rozpoznávanie voliteľné) | Zadarmo |
| Preklad, odpovede | Claude API (Claude Haiku) | Zlomky centu za vetu |
| Úplne offline (Mac) | Whisper + [Ollama](https://ollama.com) | Zadarmo, nižšia kvalita |

Do API sa posiela len text – zvuk sa neukladá. API kľúč je uložený v Keychaine iOS.

## Riešenie problémov

| Problém | Riešenie |
|---|---|
| Okuliare sa nenašli | Zatvorte aplikáciu Even Realities; vyberte okuliare z puzdra |
| Hovoriacemu je zle rozumieť | Mikrofón → *Automaticky (lepší)* alebo *iPhone / AirPods*, zapnite *Presnejšie rozpoznávanie (online)* |
| Návrhy príliš skoro / neskoro | Upravte *Pauza pred odpoveďami* |
| Riadky sa zalamujú divne | Upravte *Znakov na riadok* |
| Aplikácia po týždni prestala fungovať | Limit bezplatného Apple ID – v Xcode znova stlačte ▶ Run |

> **Stav:** skorá verzia – zostaví sa a beží v iPhone; testovanie so skutočnými okuliarmi v bežnom používaní prebieha.
> Hlásenia chýb sú veľmi vítané.

## Štruktúra projektu

| | |
|---|---|
| [`ios/`](ios) | Aplikácia pre iPhone (SwiftUI): Bluetooth G1, mikrofón okuliarov (LC3 cez Google liblc3), rozpoznávanie reči, Claude API |
| [`g1preklad/`](g1preklad) | Aplikácia pre Mac (Python): protokol, okuliare, zvuk, Whisper, LLM backendy |
| [`tests/`](tests) | Testy v Pythone bez hardvéru: `python -m pytest` |
| [`docs/`](docs) | Ilustrácie |

## Prispievanie

Issues a pull requesty sú vítané – najmä skúsenosti z reálneho používania, ďalšie jazyky a verzia pre Android.

## ⭐ Podporte projekt

Ak vám projekt pomohol niekomu porozumieť alebo vás zachránil pred trápnou chvíľou v zahraničí,
**budem rád za hviezdičku** – pomôže, aby ho našli aj ďalší. Vopred ďakujem! 🙏

## Licencia

[MIT](LICENSE) · Dekodér LC3: Google liblc3 (Apache 2.0)

*Projekt nie je spojený so spoločnosťou Even Realities ani ňou podporovaný. „Even Realities“ a „G1“ sú ochranné známky ich vlastníka.*
