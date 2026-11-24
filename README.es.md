<div align="center">

<img src="docs/app-icon.svg" width="120" alt="G1 Translator">

# Even G1 Live Translator

**Traducción de voz en tiempo real con respuestas listas para decir para las gafas inteligentes Even Realities G1**

[![iOS 17+](https://img.shields.io/badge/iOS-17%2B-black.svg)](ios)
[![macOS](https://img.shields.io/badge/macOS-Python%203.11%2B-blue.svg)](#-app-para-mac)
[![License: MIT](https://img.shields.io/badge/license-MIT-green.svg)](LICENSE)
[![Even Realities G1](https://img.shields.io/badge/device-Even%20Realities%20G1-black.svg)](https://www.evenrealities.com/g1)
[![GitHub stars](https://img.shields.io/github/stars/Thominho/even-g1-translator?style=social)](https://github.com/Thominho/even-g1-translator/stargazers)

⭐ *¿Te ha sido útil? Una estrella ayuda a que otros lo encuentren – ¡gracias!*

[🇬🇧 English](README.md) · [🇨🇿 Čeština](README.cs.md) · [🇸🇰 Slovenčina](README.sk.md) · [🇩🇪 Deutsch](README.de.md) · **🇪🇸 Español**<br>
[🇫🇷 Français](README.fr.md) · [🇮🇹 Italiano](README.it.md) · [🇵🇹 Português](README.pt.md) · [🇵🇱 Polski](README.pl.md) · [🇳🇱 Nederlands](README.nl.md)

</div>

---

Alguien te habla en un idioma que no conoces. Tus gafas **Even Realities G1** muestran una **traducción
en vivo**, te dicen **qué idioma** es y, en cuanto la persona termina, te ofrecen **tres respuestas listas
para decir en su idioma** con guía de pronunciación. Lee una en voz alta y las gafas te sugieren **qué
preguntar de vuelta**. ¿Quieres decir otra cosa? **Dilo en tu idioma** y míralo traducido. El móvil se
queda en el bolsillo.

<p align="center"><img src="docs/demo.svg" alt="Traducción en vivo y tres sugerencias de respuesta con pronunciación" width="900"></p>

## Contenido

- [Funciones](#funciones)
- [Cómo funciona](#cómo-funciona)
- [📱 App para iPhone](#-app-para-iphone) – recomendada
- [Controles](#controles)
- [Elegir tu idioma](#elegir-tu-idioma)
- [💻 App para Mac](#-app-para-mac)
- [Costes y privacidad](#costes-y-privacidad)
- [Solución de problemas](#solución-de-problemas)
- [Estructura del proyecto](#estructura-del-proyecto)
- [Contribuir](#contribuir)

## Funciones

- 💬 **Traducción en vivo** frase a frase, con la conversación previa como contexto.
- 🏷️ **Etiqueta de idioma** en la primera frase.
- ✅ **Tres respuestas en una pantalla** cuando la persona termina – *sí*, *no educado*, *pregunta* (o «¿puede repetirlo más despacio?»).
- 🗣️ **Pronunciación escrita para ti** – tal como se lee en tu propio idioma.
- 🔁 **Mantiene la conversación** – tras tu respuesta, las gafas sugieren qué preguntar de vuelta (*«¿Y usted?»* más dos preguntas sensatas).
- 🎙️ **Di cualquier cosa** – mantén el TouchBar izquierdo, dilo en tu idioma y míralo en el suyo con pronunciación.
- 🙌 **Manos libres** – todo aparece solo; los gestos son opcionales.
- 🎧 **Micrófono inteligente** – escucha con las gafas G1 *y* el iPhone y usa el que oye mejor a la persona, con ganancia automática. El móvil puede quedarse en el bolsillo.
- ⚡ **Rápido** – las respuestas y preguntas se preparan en segundo plano y aparecen en cuanto la persona se calla.
- 🙊 **Te reconoce** – tu propio idioma nunca se traduce y la app sabe cuándo lees una sugerencia en voz alta.
- 🌍 **Tu idioma** – traducciones, pronunciación y textos de las gafas en en, cs, sk, de, es, fr, it, pt, pl, nl; interfaz de la app en los mismos 10 idiomas.

## Cómo funciona

<p align="center"><img src="docs/how-it-works.svg" alt="Micrófono → voz a texto → traducción con la API de Claude → pantalla G1; respuestas preparadas tras cada frase" width="900"></p>

Las gafas son pantalla y micrófonos – el que piensa es el teléfono. La voz se convierte en texto en el
iPhone (reconocimiento de voz de iOS) o en el Mac (Whisper); las traducciones, respuestas y pronunciación
vienen de la **API de Claude** (Claude Haiku por defecto – rápido y económico). La app habla directamente
con las G1 por **Bluetooth LE**, siguiendo el protocolo de la app oficial
[EvenDemoApp](https://github.com/even-realities/EvenDemoApp) de Even Realities.

## 📱 App para iPhone

App nativa SwiftUI en [`ios/`](ios) – todo funciona en el iPhone, no necesitas ordenador mientras la usas.

**Instalación** (una vez, necesita un Mac con Xcode – basta un Apple ID gratuito):

```bash
brew install xcodegen
git clone https://github.com/Thominho/even-g1-translator.git
cd even-g1-translator/ios && xcodegen && open G1Translator.xcodeproj
```

En Xcode: **Signing & Capabilities** → elige tu **Team** (tu Apple ID) y un **Bundle Identifier** único,
selecciona tu iPhone y pulsa **▶ Run**. En el iPhone, confía en el certificado de desarrollador
(*Ajustes → General → VPN y gestión de dispositivos*) y activa el *Modo de desarrollador*.

> Con un Apple ID gratuito la app funciona **7 días** – luego conecta el iPhone y pulsa Run otra vez.

**Primer inicio** – abre *Ajustes* en la app:

| Ajuste | |
|---|---|
| Hablan | El idioma de la conversación (el reconocimiento de iOS lo necesita de antemano) |
| Tu idioma | Traducciones, pronunciación y textos de las gafas |
| Idioma de la app | Idioma de la interfaz – inglés por defecto, 10 idiomas |
| Clave API | De la [Anthropic Console](https://console.anthropic.com); la lista de modelos se carga sola, Claude Haiku preseleccionado |
| Micrófono | **Automático (el mejor)** (el mejor entre gafas e iPhone), Gafas G1 o iPhone / AirPods |
| Mejor reconocimiento (en línea) | Reconocimiento en servidores de Apple – más preciso con ruido, necesita internet |

Después **cierra la app de Even Realities** (las G1 aceptan una sola conexión), ponte las gafas y toca **Iniciar**.

## Controles

<p align="center"><img src="docs/controls.svg" alt="Mantener a la izquierda: dilo en tu idioma. Doble toque: ocultar sugerencias / nueva conversación. Triple toque: pausa." width="900"></p>

Mirar hacia arriba vuelve a mostrar las sugerencias. En la app del iPhone las mismas acciones están disponibles como botones.

## Elegir tu idioma

Configura **Tu idioma** (iPhone) o `native_language` (Mac). Todo se adapta a él:

| | Qué cambia |
|---|---|
| Traducción | Todo se traduce a tu idioma |
| Voz ignorada | Tu propio idioma nunca se traduce |
| Pronunciación | Escrita para ti – un angloparlante ve `see, meh GOOS-tah`, un checo `sí, me gusta` |
| Dilo | Dictas en tu idioma |
| Textos de las gafas | en, cs, sk, de, es, fr, it, pt, pl, nl (los demás usan inglés) |

¿Falta tu idioma? Añádelo en [`g1preklad/i18n.py`](g1preklad/i18n.py) y [`ios/G1Translator/I18n.swift`](ios/G1Translator/I18n.swift) – los pull requests son bienvenidos.

## 💻 App para Mac

La versión original en Python – funciona en un Mac con Bluetooth y reconoce el idioma automáticamente (Whisper).

```bash
git clone https://github.com/Thominho/even-g1-translator.git && cd even-g1-translator
python3 -m venv .venv && source .venv/bin/activate
pip install -e . && pip install mlx-whisper      # Intel Mac: pip install faster-whisper
cp config.example.toml config.toml                # por defecto: API de Claude con Claude Haiku
export ANTHROPIC_API_KEY="..."
python -m g1preklad demo "¿Te gusta vivir en Paraguay?"   # prueba sin micrófono
python -m g1preklad run --sim                            # pantalla simulada en la terminal
python -m g1preklad run                                  # con las gafas
```

Ajustes principales en `config.toml`: `native_language`, `replies`, `follow_up_questions`, `reply_layout`,
`turn_end_s`, `prefetch_replies`, `[stt] backend`, `[llm] backend` (`anthropic`, `openai` u `ollama`
para uso totalmente offline). Consulta [`config.example.toml`](config.example.toml).

## Costes y privacidad

| Parte | Dónde | Coste |
|---|---|---|
| Voz → texto | En el iPhone / Mac (reconocimiento online opcional) | Gratis |
| Traducción, respuestas | API de Claude (Claude Haiku) | Fracciones de céntimo por frase |
| Totalmente offline (Mac) | Whisper + [Ollama](https://ollama.com) | Gratis, menor calidad |

A la API solo se envía texto – no se guarda audio. La clave de API se guarda en el Llavero de iOS.

## Solución de problemas

| Problema | Solución |
|---|---|
| No se encuentran las gafas | Cierra la app de Even Realities; saca las gafas del estuche |
| Cuesta entender a la persona | Micrófono → *Automático (el mejor)* o *iPhone / AirPods*, activa *Mejor reconocimiento (en línea)* |
| Sugerencias demasiado pronto / tarde | Ajusta *Pausa antes de respuestas* |
| Las líneas se cortan raro | Ajusta *Caracteres por línea* |
| La app dejó de funcionar tras una semana | Límite del Apple ID gratuito – pulsa ▶ Run en Xcode otra vez |

> **Estado:** versión temprana – compila y funciona en el iPhone; las pruebas con gafas reales en el día a día están en curso.
> Los informes de errores son muy bienvenidos.

## Estructura del proyecto

| | |
|---|---|
| [`ios/`](ios) | App para iPhone (SwiftUI): Bluetooth G1, micrófono de las gafas (LC3 con Google liblc3), reconocimiento de voz, API de Claude |
| [`g1preklad/`](g1preklad) | App para Mac (Python): protocolo, gafas, audio, Whisper, backends LLM |
| [`tests/`](tests) | Tests de Python sin hardware: `python -m pytest` |
| [`docs/`](docs) | Ilustraciones |

## Contribuir

Issues y pull requests son bienvenidos – sobre todo experiencias de uso real, más idiomas y una versión para Android.

## ⭐ Apoya el proyecto

Si este proyecto te ayudó a entender a alguien o te ahorró un momento incómodo en el extranjero,
**te agradeceré una estrella** – ayuda a que otros lo encuentren. ¡Gracias de antemano! 🙏

## Licencia

[MIT](LICENSE) · Decodificador LC3: Google liblc3 (Apache 2.0)

*No está afiliado ni respaldado por Even Realities. «Even Realities» y «G1» son marcas de su respectivo propietario.*
