# AI Tutor MVP

This branch converts LexiLingo from an English-only chat experience into a tutor-first language-learning MVP.

## Product flow

1. Welcome / account setup
2. Native language
3. Target language
4. Learning goal
5. CEFR level (A1-C2)
6. Select AI Tutor
7. Course / lesson
8. Live AI Tutor conversation
9. Progress, corrections, pronunciation and spaced repetition
10. Premium paywall

## Tutor experience

The AI Tutor tab now opens a tutor selector inspired by modern AI speaking-coach apps.

Initial tutor catalog:
- Emma — American English / General conversation
- Hazel — British English / Academic
- Darius — Business / Job interview
- Mateo — Spanish / Travel
- Aiko — Japanese / Academic
- Nova — adaptive multilingual coach

Each tutor has:
- visual avatar
- persona prompt
- teaching style
- accent / voice locale
- specialities
- target-language context passed into TraceCAG

The tutor remains visible while the learner talks, and the existing STT/TTS/corrections pipeline is reused.

## Premium model

Recommended initial pricing:
- Monthly: **USD 7.99**
- Annual: **USD 69.99**

Free access:
- onboarding + placement
- first lesson of the first unit
- 3 AI Tutor turns as a product demo

Premium:
- remaining lessons
- full A1-C2 path
- unlimited AI Tutor
- voice practice
- grammar corrections
- pronunciation analysis
- role-play
- vocabulary / review
- progress and gamification

Actual billing prices must be created in Google Play / App Store and mapped to RevenueCat. The Flutter app intentionally displays the store-provided localized price.

## Nara / NVIDIA / OpenAI-compatible LLM

The AI service supports an optional primary OpenAI-compatible provider before the existing Groq -> Gemini fallback.

Set in `ai-service/.env`:

```env
PRIMARY_LLM_PROVIDER=nara
PRIMARY_LLM_BASE_URL=https://YOUR-NARA-OPENAI-COMPATIBLE-ENDPOINT/v1
PRIMARY_LLM_API_KEY=YOUR_KEY
PRIMARY_LLM_MODEL=YOUR_MODEL_ID
```

For NVIDIA NIM:

```env
PRIMARY_LLM_PROVIDER=nvidia
PRIMARY_LLM_BASE_URL=https://integrate.api.nvidia.com/v1
PRIMARY_LLM_API_KEY=YOUR_NVIDIA_KEY
PRIMARY_LLM_MODEL=YOUR_NIM_MODEL_ID
```

Never put these keys in Flutter assets or the APK.

## Android build alignment

The branch updates:
- Gradle: 8.14
- Android Gradle Plugin: 8.11.1
- Kotlin: 2.2.20
- NDK: 28.2.13676358

Install NDK 28.2.13676358 from Android Studio > SDK Manager > SDK Tools > Show Package Details.

## Firebase

The upstream repository Firebase configuration is disabled by default.

```env
FIREBASE_ENABLED=false
```

When your own Firebase project is ready:
1. add your own `android/app/google-services.json`
2. regenerate `lib/firebase_options.dart` with FlutterFire
3. restore the Google Services plugin lines in the two Android Gradle files
4. set `FIREBASE_ENABLED=true`

Do not ship using the upstream author's Firebase project.

## RevenueCat

Set public RevenueCat SDK keys in the Flutter public config only after creating your project:

```env
REVENUECAT_API_KEY_ANDROID=...
REVENUECAT_API_KEY_IOS=...
```

Create entitlement:
```
premium
```

Create monthly and annual packages in the current offering.

## Current scope

This is the first functional MVP layer. Tutor personalities, multilingual onboarding, the free-preview gate and OpenAI-compatible LLM routing are implemented without removing the existing course, CEFR, TraceCAG, STT, TTS, pronunciation, gamification or admin systems.

Photorealistic / lip-synced avatars should be added as a separate media layer after the core voice loop is stable. The current SVG avatars are local, lightweight placeholders so the product builds without external image dependencies.
