# TalkMile

TalkMile is an Android-first Flutter application for spoken English practice. It combines Android speech recognition and text-to-speech with a configurable Gemini gateway. The learner does not type during a conversation.

## Current implementation

- A quiet green-and-stone visual system with system, light, and dark appearances; short home copy and text-led navigation.
- 40 everyday speaking topics, 20 interactive story starters across nine genres, and 10 partner personas with age, gender, and relationship cues.
- Ten daily vocabulary words generated once per date and difficulty, then cached by the Worker; an offline word set is available if the gateway is unreachable.
- A learner-first coach that keeps normal turns brief, listens for longer turns, offers a short correction recap every five minutes, and revisits vocabulary weekly.
- BLoC-owned conversation lifecycle with repeated bounded speech turns, voice commands, cancellation, gentle silence prompts, and explicit stop.
- Runtime discovery of installed English TTS voices, preferring `en-IN` and then another installed English voice. Android does not provide a reliable voice-gender field, so partner selection uses voice-name hints and reports its actual fallback.
- Aggregate practice counts in Drift/SQLite; short story context, learned vocabulary, corrections, and each user's Gemini key in Android-backed secure storage. Raw audio is never stored by TalkMile.
- A visible microphone/media foreground service with a partial wake lock and retry-until-stopped session behavior; locked-screen recognition still depends on the Android speech engine.
- A Cloudflare Worker gateway that forwards each user's Gemini key, validates payloads, and applies configurable best-effort quotas. Legacy token-based installations remain supported.

## Setup

1. Install Flutter 3.41.2 or a compatible stable release, Android SDK, and an Android device with a speech recognition service and TTS engine.
2. Run `flutter pub get` and `flutter run` from this directory.
3. Deploy the Worker using the instructions in [worker/README.md](worker/README.md). Choose a Gemini model available to the users' AI Studio projects.
4. In TalkMile Settings, enter your own Gemini API key. The Worker address is fixed in the app. Google project quotas and billing apply.
5. Choose a companion, allow microphone access while the app is visible, approve Android's unrestricted battery-use prompt for screen-off conversations, and start a conversation while safely parked. On OnePlus, also enable **Allow background activity** under TalkMile's app battery settings if screen-off replies still pause.

## Build an installable release

On Windows, run `./tool/setup-release-signing.ps1` once to create a private release key in `%USERPROFILE%/.talkmile/signing`. Back up that directory securely: future updates must use the same signing key. The script refuses to overwrite existing signing material. The directory is restricted to the current Windows user and is outside the repository.

Then run `./tool/build-release.ps1`. It builds a universal APK, checks its Android signature and 16 KB ZIP alignment, and copies the verified package to `build/app/outputs/flutter-apk/TalkMile-<version>-build<number>-signed.apk` and `talkmile.apk`. Share the verified APK. The versioned file also gets a SHA-256 checksum. Release builds fail when signing credentials are missing instead of silently producing an unsigned package.

Other machines can set `TALKMILE_SIGNING_PROPERTIES` to an external properties file containing `storeFile` (absolute path), `storePassword`, `keyAlias`, and `keyPassword`. The existing `TALKMILE_KEYSTORE`, `TALKMILE_STORE_PASSWORD`, `TALKMILE_KEY_ALIAS`, and `TALKMILE_KEY_PASSWORD` environment variables also work and take precedence. Never commit or distribute signing credentials.

The first signed release cannot update an older debug-signed installation. If Android reports a signature conflict, remove that development install before installing the release; uninstalling deletes its local practice data and saved API key. Fresh installs have no such conflict. A successful build alone is not an installation test.

For public use, account for the shared Worker's quotas too. The current KV counter implementation uses two writes per uncached Gemini request and is not an atomic limiter. KV's same-key write limit affects the shared global counter. Review [Worker setup and limits](worker/README.md) before scaling to many simultaneous users.

## Architecture and implementation order

See [Architecture](docs/ARCHITECTURE.md) and [Security and platform limits](docs/SECURITY_AND_LIMITS.md). The implemented order is foundation → voice turn-taking → gateway → foreground service → progress → tests. Further release work is listed in the platform limits document.

## Verification

Run `flutter analyze`, `flutter test`, `flutter build apk --debug`, and `npm test` inside `worker/`. Tests use mock Gemini responses and do not consume real API quota.

Physical-device validation remains necessary for microphone behavior, Bluetooth, incoming calls, lock-screen continuation, and TTS voice quality on Android 13–15 and newer.
