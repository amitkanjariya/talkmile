# TalkMile

TalkMile is an Android-first Flutter application for spoken English practice. It combines Android speech recognition and text-to-speech with a configurable Gemini gateway. The learner does not type during a conversation.

## Current implementation

- Onboarding, companion choice and preview, home, conversation, progress, and settings screens.
- BLoC-owned conversation lifecycle with repeated bounded speech turns, voice commands, cancellation, gentle silence prompts, and explicit stop.
- Runtime discovery of installed `en-IN` TTS voices. Android does not provide a reliable voice-gender field, so partner selection can fall back to the closest Indian English voice and shows that limitation.
- Aggregate practice counts in Drift/SQLite; short story context and gateway token in Android-backed secure storage. Raw audio is never stored by TalkMile.
- A visible Android microphone foreground service and notification Stop action.
- A Cloudflare Worker gateway with server-only Gemini credentials, strict payload checks, a bearer access token, and a configurable daily personal-use quota.

## Setup

1. Install Flutter 3.41.2 or a compatible stable release, Android SDK, and an Android device with a speech recognition service and TTS engine.
2. Run `flutter pub get` and `flutter run` from this directory.
3. Deploy the Worker in `worker/` using `worker/wrangler.toml.example` as a guide. Choose a currently available Gemini text model with a free tier in your own AI Studio project. Set `GEMINI_MODEL`, `GEMINI_API_KEY`, and `TALKMILE_ACCESS_TOKEN` on the Worker. The secret is never included in the Flutter app.
4. In TalkMile Settings, enter your HTTPS Worker endpoint ending in `/v1/reply` and the access token. This setup step is outside the voice-only learning flow.
5. Choose a companion, allow microphone access while the app is visible, and start a conversation while safely parked.

The Worker requires a private token, so this setup is for a personal MVP. **Do not publish this app and shared token for public use.** A public release needs per-user or per-installation authentication backed by device attestation, an atomic quota limiter, and abuse monitoring. There is no registration flow or release-safe token provisioning yet.

## Architecture and implementation order

See [Architecture](docs/ARCHITECTURE.md) and [Security and platform limits](docs/SECURITY_AND_LIMITS.md). The implemented order is foundation → voice turn-taking → gateway → foreground service → progress → tests. Further release work is listed in the platform limits document.

## Verification

Run `flutter analyze`, `flutter test`, and `flutter build apk --debug`. No real Gemini calls are made by Flutter tests.

Physical-device validation remains necessary for microphone behavior, Bluetooth, incoming calls, lock-screen continuation, and TTS voice quality on Android 13–15 and newer.
