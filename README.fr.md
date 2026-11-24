<div align="center">

<img src="docs/app-icon.svg" width="120" alt="G1 Translator">

# Even G1 Live Translator

**Traduction vocale en temps réel avec réponses prêtes à dire pour les lunettes connectées Even Realities G1**

[![iOS 17+](https://img.shields.io/badge/iOS-17%2B-black.svg)](ios)
[![macOS](https://img.shields.io/badge/macOS-Python%203.11%2B-blue.svg)](#-app-mac)
[![License: MIT](https://img.shields.io/badge/license-MIT-green.svg)](LICENSE)
[![Even Realities G1](https://img.shields.io/badge/device-Even%20Realities%20G1-black.svg)](https://www.evenrealities.com/g1)
[![GitHub stars](https://img.shields.io/github/stars/Thominho/even-g1-translator?style=social)](https://github.com/Thominho/even-g1-translator/stargazers)

⭐ *Le projet vous a aidé ? Une étoile aide les autres à le trouver – merci !*

[🇬🇧 English](README.md) · [🇨🇿 Čeština](README.cs.md) · [🇸🇰 Slovenčina](README.sk.md) · [🇩🇪 Deutsch](README.de.md) · [🇪🇸 Español](README.es.md)<br>
**🇫🇷 Français** · [🇮🇹 Italiano](README.it.md) · [🇵🇹 Português](README.pt.md) · [🇵🇱 Polski](README.pl.md) · [🇳🇱 Nederlands](README.nl.md)

</div>

---

Quelqu'un vous parle dans une langue que vous ne connaissez pas. Vos lunettes **Even Realities G1**
affichent une **traduction en direct**, vous indiquent **de quelle langue** il s'agit et, dès que la personne
a fini, proposent **trois réponses prêtes à dire dans sa langue** avec la prononciation. Lisez-en une à voix
haute : les lunettes suggèrent **quoi demander en retour**. Envie de dire autre chose ? **Dites-le dans votre
langue** et voyez-le traduit. Le téléphone reste dans la poche.

<p align="center"><img src="docs/demo.svg" alt="Traduction en direct et trois suggestions de réponse avec prononciation" width="900"></p>

## Sommaire

- [Fonctionnalités](#fonctionnalités)
- [Comment ça marche](#comment-ça-marche)
- [📱 App iPhone](#-app-iphone) – recommandée
- [Commandes](#commandes)
- [Choisir votre langue](#choisir-votre-langue)
- [💻 App Mac](#-app-mac)
- [Coûts et confidentialité](#coûts-et-confidentialité)
- [Dépannage](#dépannage)
- [Structure du projet](#structure-du-projet)
- [Contribuer](#contribuer)

## Fonctionnalités

- 💬 **Traduction en direct** phrase par phrase, avec la conversation précédente comme contexte.
- 🏷️ **Indication de la langue** dès la première phrase.
- ✅ **Trois réponses sur un seul écran** quand la personne a fini – *oui*, *non poli*, *question* (ou « pouvez-vous répéter plus lentement ? »).
- 🗣️ **Prononciation écrite pour vous** – telle qu'on la lit dans votre langue.
- 🔁 **Fait vivre la conversation** – après votre réponse, les lunettes suggèrent quoi demander en retour (*« Et vous ? »* plus deux questions pertinentes).
- 🎙️ **Dites n'importe quoi** – maintenez le TouchBar gauche, dites-le dans votre langue et voyez-le dans la sienne avec la prononciation.
- 🙌 **Mains libres** – tout s'affiche tout seul ; les gestes sont facultatifs.
- 🎧 **Micro intelligent** – écoute avec les lunettes G1 *et* l'iPhone et utilise celui qui entend le mieux la personne, avec gain automatique. Le téléphone peut rester dans la poche.
- ⚡ **Rapide** – réponses et questions sont préparées en arrière-plan et s'affichent dès que la personne se tait.
- 🙊 **Vous reconnaît** – votre propre langue n'est jamais traduite et l'app sait quand vous lisez une suggestion à voix haute.
- 🌍 **Votre langue** – traductions, prononciation et affichage des lunettes en en, cs, sk, de, es, fr, it, pt, pl, nl ; interface de l'app dans les mêmes 10 langues.

## Comment ça marche

<p align="center"><img src="docs/how-it-works.svg" alt="Micro → parole en texte → traduction via l'API Claude → écran G1 ; réponses préparées après chaque phrase" width="900"></p>

Les lunettes sont un écran et des micros – c'est le téléphone qui réfléchit. La parole est transcrite
sur l'iPhone (reconnaissance vocale iOS) ou le Mac (Whisper) ; traductions, réponses et prononciation
viennent de l'**API Claude** (Claude Haiku par défaut – rapide et peu coûteux). L'app communique
directement avec les G1 en **Bluetooth LE**, selon le protocole de l'app officielle
[EvenDemoApp](https://github.com/even-realities/EvenDemoApp) d'Even Realities.

## 📱 App iPhone

App SwiftUI native dans [`ios/`](ios) – tout tourne sur l'iPhone, aucun ordinateur n'est nécessaire à l'usage.

**Installation** (une fois, nécessite un Mac avec Xcode – un identifiant Apple gratuit suffit) :

```bash
brew install xcodegen
git clone https://github.com/Thominho/even-g1-translator.git
cd even-g1-translator/ios && xcodegen && open G1Translator.xcodeproj
```

Dans Xcode : **Signing & Capabilities** → choisissez votre **Team** (votre identifiant Apple) et un **Bundle Identifier** unique,
sélectionnez votre iPhone et appuyez sur **▶ Run**. Sur l'iPhone, faites confiance au certificat développeur
(*Réglages → Général → VPN et gestion de l'appareil*) et activez le *Mode développeur*.

> Avec un identifiant Apple gratuit, l'app fonctionne **7 jours** – reconnectez ensuite l'iPhone et appuyez de nouveau sur Run.

**Premier lancement** – ouvrez *Réglages* dans l'app :

| Réglage | |
|---|---|
| Ils parlent | La langue de la conversation (la reconnaissance iOS doit la connaître à l'avance) |
| Votre langue | Traductions, prononciation et affichage des lunettes |
| Langue de l'app | Langue de l'interface – anglais par défaut, 10 langues |
| Clé API | Depuis l'[Anthropic Console](https://console.anthropic.com) ; la liste des modèles se charge seule, Claude Haiku présélectionné |
| Micro | **Automatique (le meilleur)** (le meilleur des lunettes et de l'iPhone), Lunettes G1 ou iPhone / AirPods |
| Meilleure reconnaissance (en ligne) | Reconnaissance sur les serveurs d'Apple – plus précise dans le bruit, nécessite internet |

Ensuite **fermez l'app Even Realities** (les G1 n'acceptent qu'une connexion à la fois), mettez les lunettes et touchez **Démarrer**.

## Commandes

<p align="center"><img src="docs/controls.svg" alt="Maintenir à gauche : dites-le dans votre langue. Double tap : masquer les suggestions / nouvelle conversation. Triple tap : pause." width="900"></p>

Lever les yeux réaffiche les suggestions. Dans l'app iPhone, les mêmes actions existent sous forme de boutons.

## Choisir votre langue

Réglez **Votre langue** (iPhone) ou `native_language` (Mac). Tout en découle :

| | Ce qui change |
|---|---|
| Traduction | Tout est traduit dans votre langue |
| Parole ignorée | Votre propre langue n'est jamais traduite |
| Prononciation | Écrite pour vous – un anglophone voit `see, meh GOOS-tah`, un Tchèque `sí, me gusta` |
| Dites-le | Vous dictez dans votre langue |
| Affichage des lunettes | en, cs, sk, de, es, fr, it, pt, pl, nl (les autres langues utilisent l'anglais) |

Votre langue manque ? Ajoutez-la dans [`g1preklad/i18n.py`](g1preklad/i18n.py) et [`ios/G1Translator/I18n.swift`](ios/G1Translator/I18n.swift) – les pull requests sont les bienvenues.

## 💻 App Mac

La version Python d'origine – fonctionne sur un Mac avec Bluetooth et reconnaît la langue automatiquement (Whisper).

```bash
git clone https://github.com/Thominho/even-g1-translator.git && cd even-g1-translator
python3 -m venv .venv && source .venv/bin/activate
pip install -e . && pip install mlx-whisper      # Intel Mac: pip install faster-whisper
cp config.example.toml config.toml                # par défaut : API Claude avec Claude Haiku
export ANTHROPIC_API_KEY="..."
python -m g1preklad demo "¿Te gusta vivir en Paraguay?"   # test sans micro
python -m g1preklad run --sim                            # affichage simulé dans le terminal
python -m g1preklad run                                  # avec les lunettes
```

Réglages principaux dans `config.toml` : `native_language`, `replies`, `follow_up_questions`, `reply_layout`,
`turn_end_s`, `prefetch_replies`, `[stt] backend`, `[llm] backend` (`anthropic`, `openai` ou `ollama`
pour un usage entièrement hors ligne). Voir [`config.example.toml`](config.example.toml).

## Coûts et confidentialité

| Partie | Où | Coût |
|---|---|---|
| Parole → texte | Sur l'iPhone / le Mac (reconnaissance en ligne facultative) | Gratuit |
| Traduction, réponses | API Claude (Claude Haiku) | Fractions de centime par phrase |
| Entièrement hors ligne (Mac) | Whisper + [Ollama](https://ollama.com) | Gratuit, qualité moindre |

Seul du texte est envoyé à l'API – aucun audio n'est conservé. La clé API est stockée dans le trousseau iOS.

## Dépannage

| Problème | Solution |
|---|---|
| Lunettes introuvables | Fermez l'app Even Realities ; sortez les lunettes de l'étui |
| Personne difficile à comprendre | Micro → *Automatique (le meilleur)* ou *iPhone / AirPods*, activez *Meilleure reconnaissance (en ligne)* |
| Suggestions trop tôt / trop tard | Ajustez *Pause avant les réponses* |
| Retours à la ligne bizarres | Ajustez *Caractères par ligne* |
| L'app ne marche plus après une semaine | Limite de l'identifiant Apple gratuit – appuyez de nouveau sur ▶ Run dans Xcode |

> **État :** version précoce – se compile et tourne sur iPhone ; les tests avec de vraies lunettes au quotidien sont en cours.
> Les rapports de bugs sont les bienvenus.

## Structure du projet

| | |
|---|---|
| [`ios/`](ios) | App iPhone (SwiftUI) : Bluetooth G1, micro des lunettes (LC3 via Google liblc3), reconnaissance vocale, API Claude |
| [`g1preklad/`](g1preklad) | App Mac (Python) : protocole, lunettes, audio, Whisper, backends LLM |
| [`tests/`](tests) | Tests Python sans matériel : `python -m pytest` |
| [`docs/`](docs) | Illustrations |

## Contribuer

Issues et pull requests bienvenues – surtout des retours d'usage réel, d'autres langues et une version Android.

## ⭐ Soutenez le projet

Si ce projet vous a aidé à comprendre quelqu'un ou vous a évité un moment gênant à l'étranger,
**une étoile me ferait très plaisir** – elle aide les autres à le trouver. Merci d'avance ! 🙏

## Licence

[MIT](LICENSE) · Décodeur LC3 : Google liblc3 (Apache 2.0)

*Non affilié à Even Realities ni approuvé par Even Realities. « Even Realities » et « G1 » sont des marques de leur propriétaire respectif.*
