# g1preklad – překladač do češtiny s návrhy odpovědí (Even G1)

[English](README.md) | **Čeština**

Když na tebe někdo mluví **jiným jazykem než česky**, brýle ukazují český překlad.
U první věty uvidíš, **jakým jazykem mluví**. Až **domluví**, nabídnou se 3 odpovědi
**v jeho jazyce** – nahoře česky, co říkáš, pod tím výslovnost, jak to přečíst nahlas.

```
┌────────────────────────────────────────┐      ┌────────────────────────────────────────┐
│ [ŠPANĚLŠTINA]                          │      │ ANO 1/3: Ano, moc se mi tam líbí.      │
│ Ahoj, odkud jsi? Líbí se ti Paraguay?  │  →   │ > sí, me gusta mučo                    │
│                                        │      │                                        │
└────────────────────────────────────────┘      └────────────────────────────────────────┘
        mluví…                                          domluvil → ťuk vpravo = další návrh
```

Návrhy odpovědí: **ANO** (souhlas/poděkování) · **NE** (zdvořilé odmítnutí) ·
**OTÁZKA** (doplňující otázka, nebo „zopakujte to prosím pomaleji“, když řeč nedává smysl).

## Ovládání

| Gesto | Co udělá |
|---|---|
| ťuk vpravo / vlevo | další / předchozí návrh odpovědi |
| dvojťuk | zavřít návrhy · podruhé = nový rozhovor (zapomene jazyk a kontext) |
| podržet vpravo / zvednout hlavu | znovu ukázat návrhy |
| ťuk vlevo (bez návrhů) | zapnout/vypnout originál nad překladem |
| trojťuk | pauza / pokračovat |

Chytré drobnosti:
- **Čeština se ignoruje**, takže tvoje vlastní věty se nepřekládají (`ignore_languages`, můžeš přidat i `"sk"`).
- Když **nahlas přečteš jeden z návrhů**, aplikace to pozná a nepřekládá ho, jen ukáže „Řekl jsi: …“.
- U krátkých vět, kde si Whisper není jistý jazykem, drží jazyk rozhovoru.
- Jazyk se přepne sám, když začne mluvit někdo jiný jinou řečí.
- Překlad i odpovědi berou ohled na předchozí průběh rozhovoru.

## Instalace (macOS)

```bash
git clone https://github.com/Thominho/even-g1-translator.git
cd even-g1-translator
python3 -m venv .venv && source .venv/bin/activate
pip install -e .
pip install mlx-whisper            # Mac M1–M4 (na Intel Macu: pip install faster-whisper a v configu backend = "faster-whisper")
cp config.example.toml config.toml
echo 'export ANTHROPIC_API_KEY="sk-ant-..."' >> ~/.zshrc && source ~/.zshrc
```

macOS při prvním spuštění chce přístup k mikrofonu a Bluetooth pro Terminál – povol.
První spuštění stáhne model Whisper (~1,5 GB pro large-v3-turbo), pak běží přepis offline.

## Vyzkoušení

```bash
python -m g1preklad demo "¿Te gusta vivir en Paraguay?"     # test Claude bez mikrofonu
python -m g1preklad run --sim                              # mikrofon Macu, displej v terminálu
```

V simulátoru: pusť si na YouTube video ve španělštině nebo angličtině a sleduj terminál.
Klávesy + Enter: `d`/`a` ťuk vpravo/vlevo, `aa` dvojťuk, `ttt` trojťuk, `H` podržet vpravo, `q` konec.

## S brýlemi

1. Ukonči aplikaci Even Realities v telefonu (brýle umí jen jedno připojení naráz).
2. `python -m g1preklad run`

## Kolik to stojí / offline

- **Přepis řeči** (Whisper) běží **offline na Macu** – zdarma.
- **Překlad a návrhy** dělá Claude Haiku – zhruba haléře za větu (celý večerní rozhovor řádově jednotky Kč).
- **Úplně offline**: `brew install ollama && ollama pull qwen2.5:7b` a v configu `[llm] backend = "ollama"`,
  `model = "qwen2.5:7b"`. Kvalita překladu i výslovnosti bude znatelně horší.
- Bezplatný překlad v aplikaci Even zůstává – jen neumí návrhy odpovědí.

## Doladění

- Titulky moc pomalé → `sentence_pause_s = 0.5`, menší Whisper model.
- Návrhy skáčou moc brzo / pozdě → `turn_end_s` (výchozí 1,5 s ticha).
- Chytá okolní hluk → zvyš `[audio] threshold`.
- Řádky se lámou divně → `[glasses] chars_per_line`.

S reálnými brýlemi to zatím nebylo vyzkoušené (BLE protokol je podle oficiálního EvenDemoApp);
když něco nepůjde, spusť `python -m g1preklad -v run` a pošli výpis.

Testy bez hardwaru: `python -m pytest`
