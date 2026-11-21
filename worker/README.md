# TalkMile personal gateway setup

This Worker keeps the Gemini API key off the phone. It is intended for a small, trusted group: the existing `TALKMILE_ACCESS_TOKEN` and up to 20 additional app tokens in `TALKMILE_ACCESS_TOKENS` protect the endpoints. Workers KV provides a shared, best-effort daily quota. Do not expose these tokens in a public app audience.

## Deploy

1. In [Google AI Studio](https://aistudio.google.com/), choose a Gemini text model that currently has free-tier access for your project and supports structured JSON output. Check the model identifier and quota in AI Studio; this repository does not assume a permanent model or allowance.
2. Sign in to Cloudflare Wrangler: `npx wrangler login`.
3. Create a KV namespace: `npx wrangler kv namespace create USAGE`.
4. Copy `wrangler.toml.example` to `wrangler.toml`. Put the returned namespace ID in the `USAGE` binding. `wrangler.toml` is ignored by Git.
5. Run `npx wrangler deploy` once to create the Worker.
6. Set the secrets interactively, without putting their values in source or shell history:

   ```text
   npx wrangler secret put GEMINI_API_KEY
   npx wrangler secret put TALKMILE_ACCESS_TOKEN
   npx wrangler secret put GEMINI_MODEL
   ```

   To authorize additional users, set `TALKMILE_ACCESS_TOKENS` to their comma-separated, randomly generated app tokens. Keep each token private and enter each user's own token in TalkMile Settings. The original `TALKMILE_ACCESS_TOKEN` continues to work. Updating `TALKMILE_ACCESS_TOKENS` replaces that additional-token list; include all additional users you want to keep authorized.

7. TalkMile uses the fixed `talkmile-gateway` Worker URL for `/v1/reply` and `/v1/vocabulary`. Enter only the Worker access token in Settings. Never enter the Gemini key into the app.

`/v1/vocabulary` generates ten practical B1-B2 stretch words and expressions for everyday speech, then caches the set by date and difficulty in KV. Returning to the words screen reuses the cached set; this adds at most one Gemini call per date and difficulty. If the gateway or model quota is unavailable, the app shows a bundled intermediate offline set. Conversation replies carry recent question context to discourage repeats and track each clear learner mistake for a detailed five-minute review. Weekly word review remains part of the learner's normal reply request.

All app access tokens should be long, random values. The Worker rejects missing/incorrect tokens, oversized bodies, invalid fields, and malformed model responses. Its default quota is 450 requests per UTC day shared across users when `USAGE` is bound, leaving room below the 500 daily requests in the current project allowance. KV increments are eventually consistent; this is a guardrail, not a strict public rate limiter.

Run `npm test` for the gateway's local tests. Tests stub Gemini and do not consume API quota.

Cloudflare commands: [KV namespace creation](https://developers.cloudflare.com/workers/wrangler/commands/kv/), [secret management](https://developers.cloudflare.com/workers/wrangler/commands/workers/). Gemini references: [models](https://ai.google.dev/gemini-api/docs/models), [rate limits](https://ai.google.dev/gemini-api/docs/rate-limits), [pricing](https://ai.google.dev/gemini-api/docs/pricing).
