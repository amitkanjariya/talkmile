# Security and platform limits

## Credential and privacy decisions

The Gemini key is a Cloudflare Worker secret. The app stores only the gateway access token in Android-backed secure storage. Requests use HTTPS and include no location or account identifier. The Worker limits request size and validates each field before calling Gemini. Gemini output is validated again on the client. Conversations are not logged by the app or Worker. Android's speech engine may send captured audio to its provider; this depends on the installed engine and is disclosed in Settings.

The Worker token is a single manually provisioned bearer secret for personal use. It is not embedded in the APK. KV quotas are eventually consistent and can race. Public release requires a proper identity or attestation system, per-client credentials, an atomic quota store, replay controls, and operational monitoring. The current gateway must not be exposed for broad public use.

## Android limitations

The foreground service is started only after the visible app receives microphone permission and notification permission where Android requires it. It shows an ongoing notification and a Stop action. Settings reports both permission states and links to Android app settings. The service keeps the session process visible to Android, but speech recognition remains owned by the Flutter plugin. **Locked-screen recognition is not verified and may stop on some devices or engines.** A persistent notification alone does not guarantee that recognition works under screen lock. The implementation does not bypass battery restrictions or silently restart the microphone.

Android `SpeechRecognizer` is intended for bounded recognition turns, not perpetual capture. Bluetooth audio routing, audio focus during calls, process-death recovery, and Android 13–15 physical-device lock-screen behavior still need implementation and real-device validation. The app should be used while parked for setup. During a ride, the learner should not read or touch the screen.

The `en-IN` locale is a preference, not a guarantee of accent. TTS engines expose vendor-specific voice names but no reliable male/female field. TalkMile makes a best-effort choice and reports fallback voices.

## Android 16 device check (CPH2731)

The debug APK installed and opened on a physical Android 16 phone. The onboarding microphone request displayed the Android permission dialog; denying it left a usable Continue path. After granting microphone access, Settings reported **Microphone: Allowed**. Home, Settings, the companion selector, the unconfigured-gateway conversation state, and the empty Progress screen were inspected through the device UI. The conversation state showed a setup message and an Open settings action. After installing the updated APK, the Mira voice preview completed and reported the installed `en-IN-language` voice with no reliable gender label. Audible voice quality was not assessed. Notifications remained **Not allowed**; without a configured gateway, the foreground-session permission prompt and live speech loop could not be reached. No Bluetooth, call-interruption, or locked-screen claim is based on this check.

## Learning data limits

The progress page reports measured session time, speaking turns, practice days, AI-marked completed story chapters, and vocabulary/correction items from actual AI responses. A chapter count depends on the structured AI signal and should be treated as a learning activity count, not an independently verified educational assessment. Pronunciation scores are not computed. Spoken settings changes remain pending.

## Costs

The Worker and Gemini model are deliberately configurable. Free allowances, model names, and quotas can change. Check the current [Gemini pricing](https://ai.google.dev/gemini-api/docs/pricing), [Gemini rate limits](https://ai.google.dev/gemini-api/docs/rate-limits), and [Cloudflare Workers limits](https://developers.cloudflare.com/workers/platform/limits/) before deployment. The Worker defaults to at most 100 requests per UTC day when KV is configured. No paid service is enabled by this repository.

## Threats to address before release

Shared-token leakage, scripted quota exhaustion, rooted-device token extraction, prompt injection through recognized speech, provider data retention, and notification/service desynchronization are primary risks. The current code limits payloads, separates trusted system instructions from utterances, avoids raw audio persistence, and keeps the Gemini key server-side. Those measures do not replace public client authentication or physical-device testing.
