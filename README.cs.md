<div align="center">

# Even G1 Live Translator

**Překlad řeči v reálném čase s návrhy odpovědí pro chytré brýle Even Realities G1**

[![Python 3.11+](https://img.shields.io/badge/python-3.11%2B-blue.svg)](https://www.python.org/)
[![Platforma: macOS](https://img.shields.io/badge/platforma-macOS-lightgrey.svg)](#požadavky)
[![Licence: MIT](https://img.shields.io/badge/licence-MIT-green.svg)](LICENSE)
[![Even Realities G1](https://img.shields.io/badge/zařízení-Even%20Realities%20G1-black.svg)](https://www.evenrealities.com/g1)

[English](README.md) · **Čeština**

</div>

---

Někdo na vás mluví jazykem, který neznáte – španělsky, anglicky, německy, čímkoli.
Brýle **Even Realities G1** ukazují **živý překlad do češtiny**, u první věty napíší, **jakým jazykem**
mluví, a jakmile domluví, nabídnou **tři odpovědi v jeho jazyce** – nahoře česky, co říkáte, pod tím
**výslovnost**, takže odpověď stačí přečíst nahlas.

```
 ┌─────────────────────────────────────────┐        ┌─────────────────────────────────────────┐
 │ [ŠPANĚLŠTINA]                           │        │ ANO 1/3: Ano, moc se mi tam líbí.       │
 │ Ahoj, odkud jsi? Líbí se ti Paraguay?   │  ──►   │ > sí, me gusta mučo                     │
 │                                         │        │                                         │
 └─────────────────────────────────────────┘        └─────────────────────────────────────────┘
    když mluví: živý překlad                       domluvil → odpověď 1 (ťuk vpravo ►)

 ┌─────────────────────────────────────────┐        ┌─────────────────────────────────────────┐
 │ NE 2/3: Upřímně, moc ne.                │        │ OTÁZKA 3/3: A ty jsi odkud?             │
 │ > no mučo, la verdad                    │  ──►   │ > i tu, de donde eres                   │
 │                                         │        │                                         │
 └─────────────────────────────────────────┘        └─────────────────────────────────────────┘
    odpověď 2: zdvořilé ne (ťuk ►)                 odpověď 3: doplňující otázka
```

## Obsah

- [Funkce](#funkce)
- [Jak to funguje](#jak-to-funguje)
- [Požadavky](#požadavky)
- [Rychlý start](#rychlý-start)
- [Použití s brýlemi](#použití-s-brýlemi)
- [Ovládání](#ovládání)
- [Nastavení](#nastavení)
- [Offline režim a náklady](#offline-režim-a-náklady)
- [Řešení potíží](#řešení-potíží)
- [Licence](#licence)

## Funkce

- 🌍 **Automatické rozpoznání jazyka** – zhruba 100 jazyků, přepne se samo, když začne mluvit někdo jiný jinou řečí.
- 💬 **Živý překlad** po větách, s ohledem na předchozí průběh rozhovoru.
- 🏷️ **Název jazyka** u první věty.
- ✅ **Tři návrhy odpovědí**, když mluvčí domluví: *ano / souhlas*, *zdvořilé ne* a *doplňující otázka* (nebo „zopakujte to prosím pomaleji“, když řeč nebyla srozumitelná).
- 🗣️ **Výslovnost zapsaná česky** – nemusíte vědět, jak se cizí slova píšou.
- 🙊 **Vaše řeč se nepřekládá** – čeština se ignoruje a aplikace pozná, když nahlas přečtete jeden z návrhů.
- 🔒 **Rozpoznávání řeči běží lokálně** na Macu (Whisper); k dispozici je i **úplně offline režim**.
- 🧪 **Simulátor v terminálu** – vývoj a testování bez brýlí.

## Jak to funguje

```
 mikrofon ─► rozdělení na věty ─► Whisper (text + jazyk)
                                      │
                                      ├─► LLM: překlad ───────────────────► displej G1 (Bluetooth LE)
                                      │
                    mluvčí domluvil ──┴─► LLM: 3 odpovědi + výslovnost ───► displej G1
```

Aplikace komunikuje s G1 přímo přes **Bluetooth Low Energy** (Nordic UART, obě stranice) podle
oficiálního protokolu z [EvenDemoApp](https://github.com/even-realities/EvenDemoApp).

## Požadavky

- **macOS** s Bluetooth (ideálně čip Apple Silicon kvůli rychlému lokálnímu přepisu)
- **Python 3.11+**
- Brýle **Even Realities G1** (pro simulátor nejsou potřeba)
- Jazykový model: API klíč **Anthropic** nebo **OpenAI**, případně **Ollama** pro úplný offline

## Rychlý start

```bash
git clone https://github.com/Thominho/even-g1-translator.git
cd even-g1-translator

python3 -m venv .venv && source .venv/bin/activate
pip install -e .
pip install mlx-whisper              # Apple Silicon  (Intel: pip install faster-whisper)

cp config.example.toml config.toml   # nastavte [llm] backend a model
export ANTHROPIC_API_KEY="..."       # nebo OPENAI_API_KEY – trvale do ~/.zshrc
```

Test překladu a odpovědí bez mikrofonu:

```bash
python -m g1preklad demo "¿Te gusta vivir en Paraguay?"
```

Celá aplikace se **simulovaným displejem** v terminálu (mikrofon Macu – pusťte si video v cizím jazyce):

```bash
python -m g1preklad run --sim
```

Při prvním spuštění macOS požádá o přístup k **mikrofonu** a **Bluetooth** a jednorázově se stáhne
model Whisper (~1,5 GB).

## Použití s brýlemi

1. **Zavřete aplikaci Even Realities** v telefonu – G1 přijme vždy jen jedno připojení.
2. Vyndejte brýle z pouzdra a nasaďte je.
3. Spusťte:

```bash
python -m g1preklad run
```

## Ovládání

| Gesto na TouchBaru | Akce |
|---|---|
| Ťuk vpravo / vlevo | Další / předchozí návrh odpovědi |
| Dvojťuk | Zavřít návrhy · podruhé: nový rozhovor |
| Podržet vpravo / zvednout hlavu | Znovu ukázat návrhy |
| Ťuk vlevo (bez návrhů) | Zobrazit / skrýt originál nad překladem |
| Trojťuk | Pauza / pokračovat |

Simulátor (napsat + Enter): `d` / `a` ťuk vpravo / vlevo · `aa` dvojťuk · `ttt` trojťuk · `H` podržet vpravo · `q` konec.

## Nastavení

Vše je v `config.toml` (viz [`config.example.toml`](config.example.toml)).

| Nastavení | Výchozí | Popis |
|---|---|---|
| `translator.replies` | `true` | Nabízet návrhy odpovědí |
| `translator.turn_end_s` | `1.5` | Ticho (s), po kterém mluvčí „domluvil“ |
| `translator.sentence_pause_s` | `0.7` | Pauza mezi větami – menší = rychlejší titulky |
| `translator.show_spelling` | `false` | Pod výslovností i psaná podoba odpovědi |
| `translator.ignore_languages` | `["cs"]` | Jazyky, které se nepřekládají |
| `stt.backend` | `mlx-whisper` | `mlx-whisper`, `faster-whisper` nebo `openai` |
| `llm.backend` | `anthropic` | `anthropic`, `openai` nebo `ollama` |
| `audio.source` | `mac` | `mac` (mikrofon Macu/AirPods) nebo `glasses` (mikrofon G1, potřebuje [liblc3](https://github.com/google/liblc3)) |
| `glasses.chars_per_line` | `38` | Šířka řádku na displeji G1 |

## Offline režim a náklady

| Část | Výchozí | Cena |
|---|---|---|
| Rozpoznání řeči | Whisper, **lokálně** | Zdarma |
| Překlad + odpovědi | Cloudový LLM (rychlý, levný model) | Zlomky haléře až haléře za větu |
| Úplně offline | [Ollama](https://ollama.com) + `qwen2.5:7b` | Zdarma, nižší kvalita |

```bash
brew install ollama && ollama pull qwen2.5:7b
# config.toml →  [llm] backend = "ollama"   model = "qwen2.5:7b"
```

## Řešení potíží

| Potíž | Řešení |
|---|---|
| Brýle se nenajdou | Zavřete aplikaci Even / vypněte Bluetooth v telefonu; spusťte `python -m g1preklad -v run` |
| Divné zalomení řádků | Upravte `glasses.chars_per_line` |
| Titulky se zpožďují | Snižte `sentence_pause_s`, použijte menší model Whisper |
| Návrhy přichází moc brzo / pozdě | Upravte `turn_end_s` |
| Překládá okolní hluk | Zvyšte `audio.threshold` |
| Spojení vypadává | Snižte `glasses.heartbeat_s` |

> **Stav projektu:** první verze. Implementace BLE vychází z oficiální dokumentace protokolu,
> ale na skutečném hardwaru byla zatím testována jen omezeně. Hlášení chyb s výpisem `-v` vítám.

## Přispívání

Issues i pull requesty jsou vítané – hlavně zkušenosti z reálných brýlí, podpora dalších rodných
jazyků a testování na Linuxu / Windows.

## ⭐ Podpořte projekt

Pokud vám projekt pomohl domluvit se nebo vás zachránil z trapné chvíle v zahraničí,
**budu moc rád za hvězdičku** – pomůže, aby ho našli i další. Předem děkuji! 🙏

## Licence

[MIT](LICENSE)

*Projekt není spojen se společností Even Realities ani jí schválen. „Even Realities“ a „G1“ jsou ochranné známky příslušného vlastníka.*
