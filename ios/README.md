<p align="center"><img src="../docs/app-icon.svg" width="120" alt="G1 Translator app icon"></p>

# G1 Translator for iPhone

The same hands-free translator as the desktop app – running on your **iPhone**, no Mac needed while you use it.

| Step | Runs on | Cost |
|---|---|---|
| Speech → text | iOS built-in speech recognition (on-device where supported) | Free |
| Translation, replies, questions | Claude API (Claude Haiku by default) | Your API credit |
| Display | Even Realities G1 over Bluetooth LE | Free |

## Build and install (once, needs a Mac with Xcode)

```bash
brew install xcodegen
cd ios
xcodegen                      # creates G1Translator.xcodeproj
open G1Translator.xcodeproj
```

1. In Xcode select the **G1Translator** target → **Signing & Capabilities** → choose your **Team**
   (your Apple ID is enough) and change the bundle ID to something unique, e.g. `com.yourname.g1translator`.
2. Connect your iPhone, select it as the run destination and press **▶ Run**.
3. On the iPhone: **Settings → General → VPN & Device Management** → trust your developer certificate.
   The first time, also enable **Developer Mode** (Settings → Privacy & Security).

> With a free Apple ID the app works for **7 days**, then just press Run again.
> A paid Apple Developer account ($99/year) extends this to a year.

## First start

1. Open **G1 Translator** → Settings:
   - **They speak** – the language of the conversation (e.g. Spanish (Spain)).
   - **Your language** – translations, pronunciation and the glasses UI use it.
   - **API key** from the Anthropic Console – the model list loads automatically and the fastest low-cost model is preselected.
2. **Close the Even Realities app** – the G1 accepts only one connection at a time.
3. Take the glasses out of the case and press **Start**. Allow microphone, speech recognition and Bluetooth.

The phone screen mirrors what the glasses show. The app keeps working with the screen locked.

## Notes

- App interface: English by default; Czech, Slovak, German, Spanish, French, Italian, Portuguese, Polish and Dutch in Settings → App language.

- iOS speech recognition needs the conversation language chosen in advance (no automatic detection).
- Your own speech in your native language is filtered out by the translation step.
- Microphone: the **G1 glasses** by default (your iPhone can stay in your pocket), or iPhone / AirPods – switch in Settings. The G1 audio (LC3) is decoded with Google liblc3 (Apache 2.0, `G1Translator/lc3`).
- Not yet tested on real hardware – if something doesn't work, please open an issue.
