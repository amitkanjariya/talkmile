# TalkMile gateway

TalkMile supports bring-your-own-key (BYOK): each user enters their own Gemini API key in Settings. The Android app stores it in secure storage and sends it to this Worker over HTTPS in the `X-Gemini-API-Key` header. The Worker forwards the key to Google for that request; the Worker code does not persist or log it. The Worker URL is fixed in the app.

## Deploy

1. In [Google AI Studio](https://aistudio.google.com/), create an API key in the Google project you want to use. Confirm the selected model is available to that project and review its [current pricing and free-tier eligibility](https://ai.google.dev/gemini-api/docs/pricing) and [rate limits](https://ai.google.dev/gemini-api/docs/rate-limits). Free access has limits and can change; projects on paid tiers may incur charges. Multiple API keys in one project share that project's quotas.
2. Sign in to Cloudflare Wrangler: `npx wrangler login`.
3. Create a KV namespace: `npx wrangler kv namespace create USAGE`.
4. Copy `wrangler.toml.example` to `wrangler.toml`. Put the returned namespace ID in the `USAGE` binding. `wrangler.toml` is ignored by Git.
5. Set `GEMINI_MODEL` as a Worker environment variable to a supported model identifier, then run `npx wrangler deploy`.

New app installs do not need a shared TalkMile access token or a Worker-side Gemini key. Users create their own Gemini API key in Google AI Studio and paste it in TalkMile Settings. Do not ask users to send keys to you; the app sends them directly to the fixed Worker over HTTPS. The UI warns that Google free-tier limits apply and paid Google projects can be billed.

`GEMINI_API_KEY`, `TALKMILE_ACCESS_TOKEN`, and `TALKMILE_ACCESS_TOKENS` remain optional compatibility settings for older app versions. Those older clients authenticate with their TalkMile token while the Worker uses its configured Gemini key. New BYOK requests use the caller's key and do not require those secrets.

`/v1/vocabulary` generates ten practical B1-B2 stretch words and expressions for everyday speech, then caches the set by date and difficulty in KV. Returning to the words screen reuses the cached set. Conversation replies carry recent question context to discourage repeats and track learner mistakes for a five-minute review. Weekly word review remains part of the learner's normal reply request.

When KV is bound, the Worker applies a default 450 daily requests per Gemini API key and a default 45,000 daily requests across all keys. Override these with `DAILY_REQUEST_LIMIT` and `GLOBAL_DAILY_REQUEST_LIMIT`. KV is eventually consistent, so these counts are best-effort guardrails, not strict atomic limits. Gemini's own project-level quota and billing rules still apply.

Run `npm test` in this directory for local gateway tests. Tests stub Gemini and do not consume API quota. Cloudflare references: [KV namespaces](https://developers.cloudflare.com/workers/wrangler/commands/kv/), [secrets](https://developers.cloudflare.com/workers/wrangler/commands/workers/). Gemini references: [models](https://ai.google.dev/gemini-api/docs/models), [rate limits](https://ai.google.dev/gemini-api/docs/rate-limits), [pricing](https://ai.google.dev/gemini-api/docs/pricing).
