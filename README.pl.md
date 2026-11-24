<div align="center">

<img src="docs/app-icon.svg" width="120" alt="G1 Translator">

# Even G1 Live Translator

**Tłumaczenie mowy w czasie rzeczywistym z gotowymi odpowiedziami dla inteligentnych okularów Even Realities G1**

[![iOS 17+](https://img.shields.io/badge/iOS-17%2B-black.svg)](ios)
[![macOS](https://img.shields.io/badge/macOS-Python%203.11%2B-blue.svg)](#-aplikacja-na-mac)
[![License: MIT](https://img.shields.io/badge/license-MIT-green.svg)](LICENSE)
[![Even Realities G1](https://img.shields.io/badge/device-Even%20Realities%20G1-black.svg)](https://www.evenrealities.com/g1)
[![GitHub stars](https://img.shields.io/github/stars/Thominho/even-g1-translator?style=social)](https://github.com/Thominho/even-g1-translator/stargazers)

⭐ *Projekt ci pomógł? Gwiazdka pomoże innym go znaleźć – dziękuję!*

[🇬🇧 English](README.md) · [🇨🇿 Čeština](README.cs.md) · [🇸🇰 Slovenčina](README.sk.md) · [🇩🇪 Deutsch](README.de.md) · [🇪🇸 Español](README.es.md)<br>
[🇫🇷 Français](README.fr.md) · [🇮🇹 Italiano](README.it.md) · [🇵🇹 Português](README.pt.md) · **🇵🇱 Polski** · [🇳🇱 Nederlands](README.nl.md)

</div>

---

Ktoś mówi do ciebie w języku, którego nie znasz. Okulary **Even Realities G1** pokazują **tłumaczenie
na żywo**, mówią ci, **jaki to język**, a gdy rozmówca skończy, proponują **trzy gotowe odpowiedzi w jego
języku** z wymową. Przeczytaj jedną na głos, a okulary podpowiedzą, **o co zapytać w zamian**. Chcesz
powiedzieć coś innego? **Powiedz to w swoim języku** i zobacz tłumaczenie. Telefon zostaje w kieszeni.

<p align="center"><img src="docs/demo.svg" alt="Tłumaczenie na żywo i trzy propozycje odpowiedzi z wymową" width="900"></p>

## Spis treści

- [Funkcje](#funkcje)
- [Jak to działa](#jak-to-działa)
- [📱 Aplikacja na iPhone](#-aplikacja-na-iphone) – zalecana
- [Sterowanie](#sterowanie)
- [Wybór języka](#wybór-języka)
- [💻 Aplikacja na Mac](#-aplikacja-na-mac)
- [Koszty i prywatność](#koszty-i-prywatność)
- [Rozwiązywanie problemów](#rozwiązywanie-problemów)
- [Struktura projektu](#struktura-projektu)
- [Współtworzenie](#współtworzenie)

## Funkcje

- 💬 **Tłumaczenie na żywo** zdanie po zdaniu, z dotychczasową rozmową jako kontekstem.
- 🏷️ **Oznaczenie języka** przy pierwszym zdaniu.
- ✅ **Trzy odpowiedzi na jednym ekranie**, gdy rozmówca skończy – *tak*, *uprzejme nie*, *pytanie* (albo „czy może pan powtórzyć wolniej?”).
- 🗣️ **Wymowa zapisana dla ciebie** – tak, jak czyta się ją w twoim języku.
- 🔁 **Podtrzymuje rozmowę** – po twojej odpowiedzi okulary podpowiadają, o co zapytać (*„A pan?”* plus dwa sensowne pytania).
- 🎙️ **Powiedz cokolwiek** – przytrzymaj lewy TouchBar, powiedz to w swoim języku i zobacz w jego języku z wymową.
- 🙌 **Bez rąk** – wszystko pojawia się samo; gesty są opcjonalne.
- 🎧 **Inteligentny mikrofon** – słucha okularami G1 *i* iPhonem i używa tego, który lepiej słyszy rozmówcę, z automatycznym wzmocnieniem. Telefon może zostać w kieszeni.
- ⚡ **Szybko** – odpowiedzi i pytania przygotowują się w tle, więc pojawiają się, gdy tylko rozmówca umilknie.
- 🙊 **Rozpoznaje cię** – twój język nigdy nie jest tłumaczony, a aplikacja wie, kiedy czytasz propozycję na głos.
- 🌍 **Twój język** – tłumaczenia, wymowa i napisy w okularach w en, cs, sk, de, es, fr, it, pt, pl, nl; interfejs aplikacji w tych samych 10 językach.

## Jak to działa

<p align="center"><img src="docs/how-it-works.svg" alt="Mikrofon → mowa na tekst → tłumaczenie przez Claude API → wyświetlacz G1; odpowiedzi przygotowywane po każdym zdaniu" width="900"></p>

Okulary to wyświetlacz i mikrofony – myśli telefon. Mowa zamieniana jest na tekst w iPhonie
(rozpoznawanie mowy iOS) lub w Macu (Whisper); tłumaczenia, odpowiedzi i wymowę zapewnia **Claude API**
(domyślnie Claude Haiku – szybki i tani). Aplikacja łączy się z G1 bezpośrednio przez **Bluetooth LE**,
zgodnie z protokołem oficjalnej aplikacji [EvenDemoApp](https://github.com/even-realities/EvenDemoApp) od Even Realities.

## 📱 Aplikacja na iPhone

Natywna aplikacja SwiftUI w [`ios/`](ios) – wszystko działa na iPhonie, podczas używania komputer nie jest potrzebny.

**Instalacja** (jednorazowo, potrzebny Mac z Xcode – wystarczy darmowe Apple ID):

```bash
brew install xcodegen
git clone https://github.com/Thominho/even-g1-translator.git
cd even-g1-translator/ios && xcodegen && open G1Translator.xcodeproj
```

W Xcode: **Signing & Capabilities** → wybierz swój **Team** (swoje Apple ID) i unikalny **Bundle Identifier**,
wybierz iPhone'a i naciśnij **▶ Run**. Na iPhonie zaufaj certyfikatowi dewelopera
(*Ustawienia → Ogólne → VPN i urządzenia zarządzane*) i włącz *Tryb dewelopera*.

> Z darmowym Apple ID aplikacja działa **7 dni** – potem podłącz iPhone'a i ponownie naciśnij Run.

**Pierwsze uruchomienie** – otwórz w aplikacji *Ustawienia*:

| Ustawienie | |
|---|---|
| Mówią | Język rozmowy (rozpoznawanie iOS potrzebuje go z góry) |
| Twój język | Tłumaczenia, wymowa i napisy w okularach |
| Język aplikacji | Język interfejsu – domyślnie angielski, 10 języków |
| Klucz API | Z [Anthropic Console](https://console.anthropic.com); lista modeli ładuje się sama, domyślnie Claude Haiku |
| Mikrofon | **Automatycznie (lepszy)** (lepszy z okularów i iPhone'a), Okulary G1 lub iPhone / AirPods |
| Lepsze rozpoznawanie (online) | Rozpoznawanie na serwerach Apple – dokładniejsze w hałasie, wymaga internetu |

Następnie **zamknij aplikację Even Realities** (G1 przyjmują jedno połączenie naraz), załóż okulary i dotknij **Start**.

## Sterowanie

<p align="center"><img src="docs/controls.svg" alt="Przytrzymaj lewy: powiedz w swoim języku. Podwójne dotknięcie: ukryj propozycje / nowa rozmowa. Potrójne dotknięcie: pauza." width="900"></p>

Spojrzenie w górę ponownie pokazuje propozycje. W aplikacji na iPhone te same akcje są dostępne jako przyciski.

## Wybór języka

Ustaw **Twój język** (iPhone) lub `native_language` (Mac). Wszystko się do tego dostosuje:

| | Co się zmienia |
|---|---|
| Tłumaczenie | Wszystko jest tłumaczone na twój język |
| Ignorowana mowa | Twój własny język nigdy nie jest tłumaczony |
| Wymowa | Zapisana dla ciebie – osoba anglojęzyczna widzi `see, meh GOOS-tah`, Czech `sí, me gusta` |
| Powiedz to | Dyktujesz w swoim języku |
| Napisy w okularach | en, cs, sk, de, es, fr, it, pt, pl, nl (inne języki używają angielskiego) |

Brakuje twojego języka? Dodaj go w [`g1preklad/i18n.py`](g1preklad/i18n.py) i [`ios/G1Translator/I18n.swift`](ios/G1Translator/I18n.swift) – pull requesty mile widziane.

## 💻 Aplikacja na Mac

Oryginalna wersja w Pythonie – działa na Macu z Bluetoothem i rozpoznaje język automatycznie (Whisper).

```bash
git clone https://github.com/Thominho/even-g1-translator.git && cd even-g1-translator
python3 -m venv .venv && source .venv/bin/activate
pip install -e . && pip install mlx-whisper      # Intel Mac: pip install faster-whisper
cp config.example.toml config.toml                # domyślnie: Claude API z Claude Haiku
export ANTHROPIC_API_KEY="..."
python -m g1preklad demo "¿Te gusta vivir en Paraguay?"   # test bez mikrofonu
python -m g1preklad run --sim                            # symulowany wyświetlacz w terminalu
python -m g1preklad run                                  # z okularami
```

Najważniejsze ustawienia w `config.toml`: `native_language`, `replies`, `follow_up_questions`, `reply_layout`,
`turn_end_s`, `prefetch_replies`, `[stt] backend`, `[llm] backend` (`anthropic`, `openai` lub `ollama`
do pracy w pełni offline). Zobacz [`config.example.toml`](config.example.toml).

## Koszty i prywatność

| Część | Gdzie | Koszt |
|---|---|---|
| Mowa → tekst | Na iPhonie / Macu (rozpoznawanie online opcjonalne) | Za darmo |
| Tłumaczenie, odpowiedzi | Claude API (Claude Haiku) | Ułamki centa za zdanie |
| W pełni offline (Mac) | Whisper + [Ollama](https://ollama.com) | Za darmo, niższa jakość |

Do API wysyłany jest tylko tekst – dźwięk nie jest zapisywany. Klucz API jest przechowywany w pęku kluczy iOS.

## Rozwiązywanie problemów

| Problem | Rozwiązanie |
|---|---|
| Nie znaleziono okularów | Zamknij aplikację Even Realities; wyjmij okulary z etui |
| Rozmówcę słabo słychać | Mikrofon → *Automatycznie (lepszy)* lub *iPhone / AirPods*, włącz *Lepsze rozpoznawanie (online)* |
| Propozycje za wcześnie / za późno | Zmień *Pauza przed odpowiedziami* |
| Dziwne łamanie wierszy | Zmień *Znaków w wierszu* |
| Aplikacja przestała działać po tygodniu | Limit darmowego Apple ID – ponownie naciśnij ▶ Run w Xcode |

> **Status:** wczesna wersja – kompiluje się i działa na iPhonie; testy z prawdziwymi okularami w codziennym użyciu trwają.
> Zgłoszenia błędów są bardzo mile widziane.

## Struktura projektu

| | |
|---|---|
| [`ios/`](ios) | Aplikacja na iPhone (SwiftUI): Bluetooth G1, mikrofon okularów (LC3 przez Google liblc3), rozpoznawanie mowy, Claude API |
| [`g1preklad/`](g1preklad) | Aplikacja na Mac (Python): protokół, okulary, dźwięk, Whisper, backendy LLM |
| [`tests/`](tests) | Testy w Pythonie bez sprzętu: `python -m pytest` |
| [`docs/`](docs) | Ilustracje |

## Współtworzenie

Issues i pull requesty mile widziane – zwłaszcza doświadczenia z prawdziwego użycia, kolejne języki i wersja na Androida.

## ⭐ Wesprzyj projekt

Jeśli ten projekt pomógł ci kogoś zrozumieć albo oszczędził niezręcznej chwili za granicą,
**będę wdzięczny za gwiazdkę** – pomoże innym go znaleźć. Z góry dziękuję! 🙏

## Licencja

[MIT](LICENSE) · Dekoder LC3: Google liblc3 (Apache 2.0)

*Projekt nie jest powiązany z Even Realities ani przez nią zatwierdzony. „Even Realities” i „G1” są znakami towarowymi ich właściciela.*
