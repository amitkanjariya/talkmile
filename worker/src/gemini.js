export function json(body, status = 200, headers = {}) {
  return new Response(JSON.stringify(body), {
    status,
    headers: {'content-type': 'application/json; charset=utf-8',
      'cache-control': 'no-store', ...headers},
  });
}

export async function hash(input) {
  const digest = await crypto.subtle.digest('SHA-256', new TextEncoder().encode(input));
  return [...new Uint8Array(digest)].map(b => b.toString(16).padStart(2, '0')).join('');
}

export function configuredKeys(env) {
  // Keep the existing secret first. Numbered secrets can be added independently.
  const names = Object.keys(env).filter(name => /^GEMINI_API_KEY_([1-9]\d*)$/.test(name))
    .sort((a, b) => Number(a.split('_').at(-1)) - Number(b.split('_').at(-1)));
  return [...new Set([env.GEMINI_API_KEY, ...names.map(name => env[name])]
    .filter(value => typeof value === 'string').map(value => value.trim()).filter(Boolean))]
    .slice(0, 20);
}

function quotaResponse(shared, retryAfterSeconds = 60, global = false) {
  return json({
    code: global ? 'GATEWAY_DAILY_LIMIT' : 'AI_QUOTA_EXHAUSTED',
    scope: shared ? 'shared' : 'personal',
    error: global ? 'TalkMile daily service limit reached. Try again later.'
      : shared ? 'AI limit reached. All available Gemini keys are at their limit. Try again later.'
        : 'Your Gemini API limit is reached. Try again later or update your key in Settings.',
    retryAfterSeconds,
  }, 429, {'retry-after': String(retryAfterSeconds)});
}

function positiveLimit(value, fallback) {
  const number = Number(value);
  return Number.isSafeInteger(number) && number > 0 ? number : fallback;
}

async function retryDelay(response) {
  // Read only structured retry metadata. Never return or log provider errors/keys.
  let payload;
  try { payload = await response.json(); } catch (_) {}
  const details = Array.isArray(payload?.error?.details) ? payload.error.details : [];
  const retryInfo = details.find(item => item?.['@type'] === 'type.googleapis.com/google.rpc.RetryInfo');
  const delay = /^(\d+(?:\.\d+)?)s$/.exec(retryInfo?.retryDelay || '');
  const header = response.headers.get('retry-after');
  const headerSeconds = header && /^\d+$/.test(header) ? Number(header)
    : header ? Math.ceil((Date.parse(header) - Date.now()) / 1000) : 0;
  const daily = details.some(item => Array.isArray(item?.violations) &&
    item.violations.some(violation => /per.?day|daily/i.test(violation?.quotaId || '')));
  return Math.min(86400, Math.max(60, daily ? 900 : 0,
    delay ? Math.ceil(Number(delay[1])) : 0, Number.isFinite(headerSeconds) ? headerSeconds : 0));
}

// Both conversation and vocabulary use this path. A request visits each unique
// key at most once, and only a quota response permits trying another key.
export async function generateContent(env, credentials, payload) {
  if (!env.GEMINI_MODEL || credentials.keys.length === 0) {
    return {error: json({error: 'TalkMile shared access is not configured.'}, 503)};
  }
  const controller = new AbortController();
  const timeout = setTimeout(() => controller.abort(), 28000);
  try {
    const day = new Date().toISOString().slice(0, 10);
    const globalUsageKey = `requests:${day}:all-users`;
    let globalCount = 0;
    if (env.USAGE) {
      globalCount = Number(await env.USAGE.get(globalUsageKey) || 0);
      if (globalCount >= positiveLimit(env.GLOBAL_DAILY_REQUEST_LIMIT, 45000)) {
        return {error: quotaResponse(credentials.shared, 60, true)};
      }
    }
    let earliestRetry = Infinity;
    let countedRequest = false;
    const encodedPayload = JSON.stringify(payload);
    const model = encodeURIComponent(env.GEMINI_MODEL);
    for (const key of credentials.keys) {
      if (controller.signal.aborted) throw new Error('Request timed out');
      const fingerprint = await hash(key);
      const usageKey = `requests:${day}:${fingerprint}`;
      const cooldownKey = `gemini-cooldown:v1:${model}:${fingerprint}`;
      if (env.USAGE) {
        const cooldownUntil = Number(await env.USAGE.get(cooldownKey) || 0);
        if (cooldownUntil > Date.now()) {
          earliestRetry = Math.min(earliestRetry, Math.ceil((cooldownUntil - Date.now()) / 1000));
          continue;
        }
        const count = Number(await env.USAGE.get(usageKey) || 0);
        if (count >= positiveLimit(env.DAILY_REQUEST_LIMIT, 450)) {
          const reset = Date.parse(`${day}T00:00:00Z`) + 86400000;
          earliestRetry = Math.min(earliestRetry, Math.ceil((reset - Date.now()) / 1000));
          continue;
        }
        // Count each provider attempt per key, but only one global request.
        // A fallback must not rewrite the same global KV key within one second.
        await env.USAGE.put(usageKey, String(count + 1), {expirationTtl: 172800});
        if (!countedRequest) {
          await env.USAGE.put(globalUsageKey, String(globalCount + 1), {expirationTtl: 172800});
          countedRequest = true;
        }
      }
      const response = await fetch(
        `https://generativelanguage.googleapis.com/v1beta/models/${model}:generateContent`, {
          method: 'POST', signal: controller.signal,
          headers: {'content-type': 'application/json', 'x-goog-api-key': key},
          body: encodedPayload,
        });
      if (response.status === 429) {
        const seconds = await retryDelay(response);
        earliestRetry = Math.min(earliestRetry, seconds);
        // Failed cooldown writes must not prevent trying a healthy backup key.
        if (env.USAGE) {
          try {
            await env.USAGE.put(cooldownKey, String(Date.now() + seconds * 1000),
              {expirationTtl: seconds});
          } catch (_) {}
        }
        continue;
      }
      if (response.status === 401 || response.status === 403) {
        return {error: json({code: 'AI_KEY_REJECTED', error: credentials.shared
          ? 'A shared Gemini key was rejected. Ask the TalkMile owner to check it.'
          : 'Gemini API key was rejected. Check your key in Settings.'}, 401)};
      }
      if (!response.ok) return {error: json({error: 'AI service unavailable'}, 502)};
      return {data: await response.json()};
    }
    return {error: quotaResponse(credentials.shared,
      Number.isFinite(earliestRetry) ? Math.max(1, earliestRetry) : 60)};
  } catch (_) {
    return {error: json({error: 'AI service unavailable'}, 502)};
  } finally {
    clearTimeout(timeout);
  }
}
