# TalkMile architecture

## Design system

Material 3 uses a warm paper, charcoal, and muted green palette, with system, light, and dark appearance choices. Copy stays concise and the home screen keeps vocabulary, topics, stories, and partner selection one tap away.

## Screens

`/welcome` introduces the product with an optional spoken guide. `/companion` offers ten conversational personas and runtime voice previews. `/` links to daily vocabulary, 40 conversation topics, 20 story starters, progress, and settings. `/conversation` reflects session phases and exposes an explicit Stop control. `/progress` shows actual locally recorded totals. `/settings` manages appearance, voice, pace, difficulty, corrections, privacy, and gateway setup.

## Boundaries

- **View:** Flutter pages and reusable brand components. Widgets dispatch actions and render state.
- **ViewModel:** `SettingsCubit` and `ConversationCubit` own user actions and state transitions.
- **Model:** `ConversationState`, `CoachResponse`, and `VoiceCommand` describe the domain.
- **Data:** `VoiceService`, `AiGateway`, `LocalStore`, Android `SessionService`, and the Cloudflare Worker isolate platform, network, and storage behavior. The conversation coordinator depends on `VoicePort` and `AiGatewayPort` so its stop and silence paths can be tested without device or network services.
- **Dependency injection:** `get_it` provides single application-scoped service instances; pages obtain BLoCs from `BlocProvider`.

## Conversation states

```text
idle → initializing → processing → speaking → listening
                           ↑                     │
                           └──── user answer ────┘
any active state → stopped (explicit Stop)
active state → error (technical failure) → initializing (visible retry)
```

The domain enum also reserves `temporarilyPaused` and `recovering` for Android interruption recovery. Those transitions are not yet implemented and must not be advertised as working. Each recognition turn is bounded. Silence triggers a spoken prompt and another turn; it never ends the session. TTS is awaited before listening starts. The coordinator uses a generation counter and Dio cancellation token to discard work after Stop.

## Data flow

Speech recognition returns text to `ConversationCubit`. The gateway receives a short recent history and compact story summary, with a versioned system prompt stored only on the Worker. Gemini returns structured JSON. The client validates it, speaks only the text fields, and saves compact story context. Progress counters are updated when a session ends or fails.

No transcript or audio is written to SQLite. Story context, vocabulary, and meaningful corrections are stored through `flutter_secure_storage`; practice totals use Drift/SQLite. Deleting learning data clears both.
