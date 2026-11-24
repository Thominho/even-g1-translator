<div align="center">

<img src="docs/app-icon.svg" width="120" alt="G1 Translator">

# Even G1 Live Translator

**Tradução de fala em tempo real com respostas prontas para dizer para os óculos inteligentes Even Realities G1**

[![iOS 17+](https://img.shields.io/badge/iOS-17%2B-black.svg)](ios)
[![macOS](https://img.shields.io/badge/macOS-Python%203.11%2B-blue.svg)](#-app-para-mac)
[![License: MIT](https://img.shields.io/badge/license-MIT-green.svg)](LICENSE)
[![Even Realities G1](https://img.shields.io/badge/device-Even%20Realities%20G1-black.svg)](https://www.evenrealities.com/g1)
[![GitHub stars](https://img.shields.io/github/stars/Thominho/even-g1-translator?style=social)](https://github.com/Thominho/even-g1-translator/stargazers)

⭐ *O projeto ajudou você? Uma estrela ajuda outras pessoas a encontrá-lo – obrigado!*

[🇬🇧 English](README.md) · [🇨🇿 Čeština](README.cs.md) · [🇸🇰 Slovenčina](README.sk.md) · [🇩🇪 Deutsch](README.de.md) · [🇪🇸 Español](README.es.md)<br>
[🇫🇷 Français](README.fr.md) · [🇮🇹 Italiano](README.it.md) · **🇵🇹 Português** · [🇵🇱 Polski](README.pl.md) · [🇳🇱 Nederlands](README.nl.md)

</div>

---

Alguém fala com você num idioma que você não conhece. Os óculos **Even Realities G1** mostram uma
**tradução ao vivo**, dizem **qual é o idioma** e, assim que a pessoa termina, oferecem **três respostas
prontas para dizer no idioma dela** com guia de pronúncia. Leia uma em voz alta e os óculos sugerem **o que
perguntar de volta**. Quer dizer outra coisa? **Diga no seu idioma** e veja traduzido. O celular fica no
bolso.

<p align="center"><img src="docs/demo.svg" alt="Tradução ao vivo e três sugestões de resposta com pronúncia" width="900"></p>

## Conteúdo

- [Funcionalidades](#funcionalidades)
- [Como funciona](#como-funciona)
- [📱 App para iPhone](#-app-para-iphone) – recomendado
- [Controles](#controles)
- [Escolher seu idioma](#escolher-seu-idioma)
- [💻 App para Mac](#-app-para-mac)
- [Custos e privacidade](#custos-e-privacidade)
- [Solução de problemas](#solução-de-problemas)
- [Estrutura do projeto](#estrutura-do-projeto)
- [Contribuir](#contribuir)

## Funcionalidades

- 💬 **Tradução ao vivo** frase a frase, com a conversa anterior como contexto.
- 🏷️ **Indicação do idioma** na primeira frase.
- ✅ **Três respostas numa tela** quando a pessoa termina – *sim*, *não educado*, *pergunta* (ou «pode repetir mais devagar?»).
- 🗣️ **Pronúncia escrita para você** – como se lê no seu próprio idioma.
- 🔁 **Mantém a conversa** – depois da sua resposta, os óculos sugerem o que perguntar de volta (*«E você?»* mais duas perguntas sensatas).
- 🎙️ **Diga qualquer coisa** – segure o TouchBar esquerdo, diga no seu idioma e veja no dela com pronúncia.
- 🙌 **Mãos livres** – tudo aparece sozinho; os gestos são opcionais.
- 🎧 **Microfone inteligente** – ouve com os óculos G1 *e* o iPhone e usa o que ouve melhor a pessoa, com ganho automático. O celular pode ficar no bolso.
- ⚡ **Rápido** – respostas e perguntas são preparadas em segundo plano e aparecem assim que a pessoa para de falar.
- 🙊 **Reconhece você** – seu próprio idioma nunca é traduzido e o app sabe quando você lê uma sugestão em voz alta.
- 🌍 **Seu idioma** – traduções, pronúncia e textos dos óculos em en, cs, sk, de, es, fr, it, pt, pl, nl; interface do app nos mesmos 10 idiomas.

## Como funciona

<p align="center"><img src="docs/how-it-works.svg" alt="Microfone → fala em texto → tradução pela API do Claude → tela G1; respostas preparadas após cada frase" width="900"></p>

Os óculos são tela e microfones – quem pensa é o telefone. A fala vira texto no iPhone (reconhecimento
de fala do iOS) ou no Mac (Whisper); traduções, respostas e pronúncia vêm da **API do Claude** (Claude Haiku
por padrão – rápido e barato). O app fala diretamente com os G1 por **Bluetooth LE**, seguindo o protocolo
do app oficial [EvenDemoApp](https://github.com/even-realities/EvenDemoApp) da Even Realities.

## 📱 App para iPhone

App SwiftUI nativo em [`ios/`](ios) – tudo roda no iPhone, não é preciso computador durante o uso.

**Instalação** (uma vez, precisa de um Mac com Xcode – basta um Apple ID gratuito):

```bash
brew install xcodegen
git clone https://github.com/Thominho/even-g1-translator.git
cd even-g1-translator/ios && xcodegen && open G1Translator.xcodeproj
```

No Xcode: **Signing & Capabilities** → escolha seu **Team** (seu Apple ID) e um **Bundle Identifier** único,
selecione seu iPhone e pressione **▶ Run**. No iPhone, confie no certificado de desenvolvedor
(*Ajustes → Geral → VPN e Gerenciamento de Dispositivos*) e ative o *Modo de Desenvolvedor*.

> Com um Apple ID gratuito o app funciona por **7 dias** – depois conecte o iPhone e pressione Run de novo.

**Primeiro uso** – abra *Ajustes* no app:

| Ajuste | |
|---|---|
| Falam | O idioma da conversa (o reconhecimento do iOS precisa dele de antemão) |
| Seu idioma | Traduções, pronúncia e textos dos óculos |
| Idioma do app | Idioma da interface – inglês por padrão, 10 idiomas |
| Chave de API | Da [Anthropic Console](https://console.anthropic.com); a lista de modelos carrega sozinha, Claude Haiku pré-selecionado |
| Microfone | **Automático (o melhor)** (o melhor entre óculos e iPhone), Óculos G1 ou iPhone / AirPods |
| Melhor reconhecimento (online) | Reconhecimento nos servidores da Apple – mais preciso com ruído, precisa de internet |

Depois **feche o app da Even Realities** (os G1 aceitam uma conexão por vez), coloque os óculos e toque em **Iniciar**.

## Controles

<p align="center"><img src="docs/controls.svg" alt="Segurar à esquerda: diga no seu idioma. Toque duplo: ocultar sugestões / nova conversa. Toque triplo: pausa." width="900"></p>

Olhar para cima mostra as sugestões de novo. No app do iPhone as mesmas ações estão disponíveis como botões.

## Escolher seu idioma

Defina **Seu idioma** (iPhone) ou `native_language` (Mac). Tudo segue essa escolha:

| | O que muda |
|---|---|
| Tradução | Tudo é traduzido para o seu idioma |
| Fala ignorada | Seu próprio idioma nunca é traduzido |
| Pronúncia | Escrita para você – quem fala inglês vê `see, meh GOOS-tah`, um tcheco `sí, me gusta` |
| Diga | Você dita no seu idioma |
| Textos dos óculos | en, cs, sk, de, es, fr, it, pt, pl, nl (os demais usam inglês) |

Falta seu idioma? Adicione em [`g1preklad/i18n.py`](g1preklad/i18n.py) e [`ios/G1Translator/I18n.swift`](ios/G1Translator/I18n.swift) – pull requests são bem-vindos.

## 💻 App para Mac

A versão original em Python – roda num Mac com Bluetooth e reconhece o idioma automaticamente (Whisper).

```bash
git clone https://github.com/Thominho/even-g1-translator.git && cd even-g1-translator
python3 -m venv .venv && source .venv/bin/activate
pip install -e . && pip install mlx-whisper      # Intel Mac: pip install faster-whisper
cp config.example.toml config.toml                # padrão: API do Claude com Claude Haiku
export ANTHROPIC_API_KEY="..."
python -m g1preklad demo "¿Te gusta vivir en Paraguay?"   # teste sem microfone
python -m g1preklad run --sim                            # tela simulada no terminal
python -m g1preklad run                                  # com os óculos
```

Principais ajustes em `config.toml`: `native_language`, `replies`, `follow_up_questions`, `reply_layout`,
`turn_end_s`, `prefetch_replies`, `[stt] backend`, `[llm] backend` (`anthropic`, `openai` ou `ollama`
para uso totalmente offline). Veja [`config.example.toml`](config.example.toml).

## Custos e privacidade

| Parte | Onde | Custo |
|---|---|---|
| Fala → texto | No iPhone / Mac (reconhecimento online opcional) | Grátis |
| Tradução, respostas | API do Claude (Claude Haiku) | Frações de centavo por frase |
| Totalmente offline (Mac) | Whisper + [Ollama](https://ollama.com) | Grátis, qualidade menor |

Apenas texto é enviado à API – nenhum áudio é armazenado. A chave da API fica no Porta-chaves do iOS.

## Solução de problemas

| Problema | Solução |
|---|---|
| Óculos não encontrados | Feche o app da Even Realities; tire os óculos do estojo |
| Difícil entender a pessoa | Microfone → *Automático (o melhor)* ou *iPhone / AirPods*, ative *Melhor reconhecimento (online)* |
| Sugestões cedo / tarde demais | Ajuste *Pausa antes das respostas* |
| Quebras de linha estranhas | Ajuste *Caracteres por linha* |
| O app parou de funcionar após uma semana | Limite do Apple ID gratuito – pressione ▶ Run no Xcode de novo |

> **Status:** versão inicial – compila e roda no iPhone; os testes com óculos reais no dia a dia estão em andamento.
> Relatos de bugs são muito bem-vindos.

## Estrutura do projeto

| | |
|---|---|
| [`ios/`](ios) | App para iPhone (SwiftUI): Bluetooth G1, microfone dos óculos (LC3 via Google liblc3), reconhecimento de fala, API do Claude |
| [`g1preklad/`](g1preklad) | App para Mac (Python): protocolo, óculos, áudio, Whisper, backends de LLM |
| [`tests/`](tests) | Testes Python sem hardware: `python -m pytest` |
| [`docs/`](docs) | Ilustrações |

## Contribuir

Issues e pull requests são bem-vindos – principalmente relatos de uso real, mais idiomas e uma versão para Android.

## ⭐ Apoie o projeto

Se este projeto ajudou você a entender alguém ou evitou um momento constrangedor no exterior,
**ficarei feliz com uma estrela** – ajuda outras pessoas a encontrá-lo. Obrigado desde já! 🙏

## Licença

[MIT](LICENSE) · Decodificador LC3: Google liblc3 (Apache 2.0)

*Não afiliado nem endossado pela Even Realities. «Even Realities» e «G1» são marcas de seu respectivo proprietário.*
