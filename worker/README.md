# TalkMile gateway

TalkMile uses a Worker-managed Gemini key pool when the optional personal key field is blank. If a user enters a Gemini API key in Settings, requests use only that key. The Worker URL is fixed in the app. Provider keys for shared access stay in Worker secrets.

## Deploy

1. In [Google AI Studio](https://aistudio.google.com/), create an API key in the Google project you want to use. Confirm the selected model is available to that project and review its [current pricing and free-tier eligibility](https://ai.google.dev/gemini-api/docs/pricing) and [rate limits](https://ai.google.dev/gemini-api/docs/rate-limits). Free access has limits and can change; projects on paid tiers may incur charges. Multiple API keys in one project share that project's quotas.
2. Sign in to Cloudflare Wrangler: `npx wrangler login`.
3. Create a KV namespace: `npx wrangler kv namespace create USAGE`.
4. Copy `wrangler.toml.example` to `wrangler.toml`. Put the returned namespace ID in the `USAGE` binding. `wrangler.toml` is ignored by Git.
5. Set `GEMINI_MODEL` as a Worker environment variable to a supported model identifier, then run `npx wrangler deploy`.

## Shared key pool

In this directory, set the first key if it is not already configured:

```powershell
npx wrangler secret put GEMINI_API_KEY
```

Paste each value at Wrangler's hidden prompt. Keep `GEMINI_API_KEY` when adding backups. Add each backup as a new secret:

```powershell
npx wrangler secret put GEMINI_API_KEY_2
npx wrangler secret put GEMINI_API_KEY_3
```

Continue with `_4`, `_5`, etc. The Worker reads the first 20 unique nonblank keys: `GEMINI_API_KEY` first, followed by numbered secrets in numeric order. Duplicate values are ignored. Do not put keys in `wrangler.toml`, Git, or the APK. `wrangler secret put` publishes the updated secret; once this Worker version is deployed, adding keys needs no code change or APK rebuild. In the Cloudflare dashboard, use **Workers & Pages → talkmile-gateway → Settings → Variables and Secrets**, add a **Secret** with the numbered name, and deploy that change.

On the phone, leave the optional Gemini API key field blank to use the shared pool. The shared endpoint does not require a user-specific access code. This makes the Worker endpoint public; the Worker global daily cap is the main usage guardrail, so monitor it and increase protection with per-user authentication if the app is shared widely.

Both `/v1/reply` and `/v1/vocabulary` try the next key after a Gemini **429** or the current key's local daily cap. The full conversation payload stays identical and each key is tried at most once per request, under one 28-second timeout. Successful requests, invalid credentials, malformed output, network failures and other provider errors do not trigger key rotation. If every key is exhausted, the Worker returns HTTP 429 with `code: AI_QUOTA_EXHAUSTED`, `scope: shared`, a clear limit message and `Retry-After`.

KV stores only key fingerprints, counts and cooldown timestamps. A rate-limited key is skipped for at least 60 seconds, respects a longer Google `RetryInfo`/`Retry-After`, and is checked no more often than every 15 minutes when Google identifies a daily quota error. Cooldowns are best-effort because KV is eventually consistent. The app shows the limit message without speaking repeated prompts and polls once per minute while the session remains open; the Worker continues skipping keys in cooldown. Newly added keys can be used on the next poll. Only the user ends the session.

Adding keys does not change `GEMINI_MODEL` or create unlimited quota. Google enforces quotas per project; keys in the same project share limits. Keys from billed projects can incur charges. The Worker's global cap and Cloudflare hosting limits also still apply.

## Personal keys and older apps

The optional Gemini key field uses the caller's key over HTTPS in `X-Gemini-API-Key`. It is saved in device secure storage, never logged or persisted as plaintext by the Worker. That request uses only the supplied key; on quota exhaustion the Worker does not fall back to the shared pool. Leave the field blank to use the shared key pool. Older app versions with saved TalkMile access codes remain supported.

For compatibility, an app already presenting a key that matches one of the configured Worker keys can use the shared pool immediately. Removing a provider key from the pool also removes this compatibility access for that key.

## Usage and hosting limits

`/v1/vocabulary` generates ten practical B1-B2 stretch words and expressions for everyday speech, then caches the set by date and difficulty in KV. Returning to the words screen reuses the cached set. Conversation replies carry recent question context to discourage repeats and track learner mistakes for a five-minute review. Weekly word review remains part of the learner's normal reply request.

When KV is bound, the Worker applies a default 450 daily provider attempts per Gemini API key and a default 45,000 daily app requests across all keys (UTC day). Override these with `DAILY_REQUEST_LIMIT` and `GLOBAL_DAILY_REQUEST_LIMIT`. Each actual provider attempt, including a 429, consumes that key's allowance. The global count increases once for the app request even if it tries several keys. A global cap returns `GATEWAY_DAILY_LIMIT`; adding keys cannot bypass it. KV is eventually consistent, so these are best-effort guardrails, not strict atomic limits. Google's own project quota and Pacific-time daily reset still apply.

The existing KV counters use two writes for a normal uncached request, plus an extra per-key count and cooldown write for each rate-limited fallback. Vocabulary caching also uses writes. Cloudflare KV Free's 1,000 writes/day can therefore limit the service to fewer than about 500 uncached requests/day across the entire pool. Adding Gemini keys does not increase that hosting allowance. KV's one-write-per-second limit on the shared global counter also limits concurrency; use an atomic counter service such as a Durable Object before scaling to many simultaneous users. See [KV limits](https://developers.cloudflare.com/kv/platform/limits/) and [KV pricing](https://developers.cloudflare.com/kv/platform/pricing/).

Run `npm test` in this directory for local gateway tests. Tests stub Gemini and do not consume API quota. Cloudflare references: [KV namespaces](https://developers.cloudflare.com/workers/wrangler/commands/kv/), [secrets](https://developers.cloudflare.com/workers/wrangler/commands/workers/). Gemini references: [models](https://ai.google.dev/gemini-api/docs/models), [rate limits](https://ai.google.dev/gemini-api/docs/rate-limits), [pricing](https://ai.google.dev/gemini-api/docs/pricing).
