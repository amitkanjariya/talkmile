# TalkMile personal gateway setup

This Worker keeps the Gemini API key off the phone. It is intentionally a **personal-use gateway**: one manually entered access token protects the endpoint, and Workers KV provides a best-effort daily quota. Do not expose a shared token to a public app audience.

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

7. Copy the Worker URL from Wrangler, append `/v1/reply`, and enter it with the access token in TalkMile Settings. Never enter the Gemini key into the app.

The `TALKMILE_ACCESS_TOKEN` should be a long, random value unique to this deployment. The Worker rejects missing/incorrect tokens, oversized bodies, invalid fields, and malformed model responses. Its default quota is 100 requests per UTC day when `USAGE` is bound. KV increments are eventually consistent; this is a guardrail, not a strict public rate limiter.

Run `npm test` for the gateway's local tests. Tests stub Gemini and do not consume API quota.

Cloudflare commands: [KV namespace creation](https://developers.cloudflare.com/workers/wrangler/commands/kv/), [secret management](https://developers.cloudflare.com/workers/wrangler/commands/workers/). Gemini references: [models](https://ai.google.dev/gemini-api/docs/models), [rate limits](https://ai.google.dev/gemini-api/docs/rate-limits), [pricing](https://ai.google.dev/gemini-api/docs/pricing).
