import assert from 'node:assert/strict';
import {afterEach, test} from 'node:test';
import gateway from '../src/index.js';
import {configuredKeys, hash} from '../src/gemini.js';

const originalFetch = globalThis.fetch;
afterEach(() => { globalThis.fetch = originalFetch; });
const body = {utterance: 'I went shopping yesterday.', mode: 'conversation',
  difficulty: 'intermediate', corrections: 'gentle', storyState: '', recentTurns: []};
const reply = {spokenText: 'What a busy afternoon.', nextQuestion: 'What did you buy?',
  corrections: [], storyState: '', chapterCompleted: false, newVocabulary: [], difficulty: 'intermediate'};
const baseEnv = {GEMINI_API_KEY: 'primary-secret', GEMINI_API_KEY_2: 'backup-secret',
  TALKMILE_ACCESS_TOKEN: 'shared-code', GEMINI_MODEL: 'test-model'};
const success = (value = reply) => Response.json({candidates: [{content: {parts: [{text: JSON.stringify(value)}]}}]});
const request = (headers = {authorization: 'Bearer shared-code'}, path = '/v1/reply', data = body) =>
  new Request(`https://talkmile.example${path}`, {method: 'POST', headers, body: JSON.stringify(data)});
function storage() {
  const values = new Map();
  const writes = [];
  return {values, writes, async get(key) { return values.get(key) ?? null; },
    async put(key, value, options) { writes.push({key, value, options}); values.set(key, value); }};
}

test('quota failover sends the identical conversation to the next key exactly once', async () => {
  const calls = [];
  const usage = storage();
  globalThis.fetch = async (_url, options) => {
    calls.push(options);
    return calls.length === 1 ? new Response('', {status: 429}) : success();
  };
  const response = await gateway.fetch(request(), {...baseEnv, USAGE: usage});
  assert.equal(response.status, 200);
  assert.deepEqual(await response.json(), reply);
  assert.deepEqual(calls.map(call => call.headers['x-goog-api-key']), ['primary-secret', 'backup-secret']);
  assert.equal(calls[0].body, calls[1].body);
  assert.equal(calls[0].signal, calls[1].signal, 'all attempts share one time budget');
  assert.equal(usage.writes.filter(write => write.key.endsWith(':all-users')).length, 1);
  for (const secret of ['primary-secret', 'backup-secret', 'shared-code']) {
    assert.ok(!JSON.stringify([...usage.values]).includes(secret));
  }
});

test('exhausted pool returns a safe explicit limit message with no retry loop', async () => {
  const calls = [];
  globalThis.fetch = async (_url, options) => {
    calls.push(options.headers['x-goog-api-key']);
    return Response.json({error: {message: options.headers['x-goog-api-key']}}, {status: 429});
  };
  const response = await gateway.fetch(request(), {...baseEnv, GEMINI_API_KEY_3: 'third-secret'});
  assert.equal(response.status, 429);
  assert.equal(response.headers.get('retry-after'), '60');
  const result = await response.json();
  assert.equal(result.code, 'AI_QUOTA_EXHAUSTED');
  assert.equal(result.scope, 'shared');
  assert.match(result.error, /All available Gemini keys/);
  assert.deepEqual(calls, ['primary-secret', 'backup-secret', 'third-secret']);
  assert.ok(!JSON.stringify(result).includes('secret'));
});

test('a single key also gives the limit message', async () => {
  let calls = 0;
  globalThis.fetch = async () => { calls++; return new Response('', {status: 429}); };
  const response = await gateway.fetch(request(), {...baseEnv, GEMINI_API_KEY_2: ''});
  assert.equal(response.status, 429);
  assert.equal(calls, 1);
});

test('cooldown skips exhausted keys, honors RetryInfo, and permits a newly added key', async (t) => {
  let now = Date.parse('2026-11-22T12:00:00Z');
  t.mock.method(Date, 'now', () => now);
  const usage = storage();
  const env = {...baseEnv, USAGE: usage};
  const calls = [];
  globalThis.fetch = async (_url, options) => {
    const key = options.headers['x-goog-api-key'];
    calls.push(key);
    return key === 'new-secret' ? success() : Response.json({error: {details: [{
      '@type': 'type.googleapis.com/google.rpc.RetryInfo', retryDelay: '120.1s',
    }]}}, {status: 429});
  };
  assert.equal((await gateway.fetch(request(), env)).status, 429);
  const second = await gateway.fetch(request(), env);
  assert.equal(second.status, 429);
  assert.equal(second.headers.get('retry-after'), '121');
  assert.equal(calls.length, 2, 'cooldown must not burn more provider requests');
  env.GEMINI_API_KEY_3 = 'new-secret';
  assert.equal((await gateway.fetch(request(), env)).status, 200);
  assert.deepEqual(calls, ['primary-secret', 'backup-secret', 'new-secret']);
  now += 122000;
  globalThis.fetch = async (_url, options) => { calls.push(options.headers['x-goog-api-key']); return success(); };
  assert.equal((await gateway.fetch(request(), env)).status, 200);
  assert.equal(calls.at(-1), 'primary-secret', 'expired keys become eligible again');
});

test('daily quota errors receive a longer cooldown', async () => {
  globalThis.fetch = async () => Response.json({error: {details: [{
    '@type': 'type.googleapis.com/google.rpc.QuotaFailure',
    violations: [{quotaId: 'GenerateRequestsPerDayPerProjectPerModel-FreeTier'}],
  }]}}, {status: 429});
  const response = await gateway.fetch(request(), baseEnv);
  assert.equal(response.headers.get('retry-after'), '900');
});

test('private BYOK quota failure cannot consume the owner pool', async () => {
  const keys = [];
  globalThis.fetch = async (_url, options) => {
    keys.push(options.headers['x-goog-api-key']);
    return new Response('', {status: 429});
  };
  const response = await gateway.fetch(request({'x-gemini-api-key': 'private-user-key'}), baseEnv);
  assert.equal(response.status, 429);
  assert.equal((await response.json()).scope, 'personal');
  assert.deepEqual(keys, ['private-user-key']);
});

test('existing app with a configured owner key uses the pool without an app update', async () => {
  const keys = [];
  globalThis.fetch = async (_url, options) => {
    keys.push(options.headers['x-goog-api-key']);
    return keys.length === 1 ? new Response('', {status: 429}) : success();
  };
  assert.equal((await gateway.fetch(request({'x-gemini-api-key': 'primary-secret'}), baseEnv)).status, 200);
  assert.deepEqual(keys, ['primary-secret', 'backup-secret']);
});

test('blank and duplicate secrets are ignored; numbered secrets sort numerically', async () => {
  assert.deepEqual(configuredKeys({...baseEnv, GEMINI_API_KEY_2: ' primary-secret ',
    GEMINI_API_KEY_3: '   ', GEMINI_API_KEY_10: 'tenth', GEMINI_API_KEY_9: 'ninth',
    GEMINI_API_KEYS: 'not-a-numbered-secret'}), ['primary-secret', 'ninth', 'tenth']);
  const many = Object.fromEntries(Array.from({length: 30}, (_, i) => [`GEMINI_API_KEY_${i + 1}`, `key-${i}`]));
  assert.equal(configuredKeys(many).length, 20);
});

test('local daily key cap switches keys; global cap cannot be bypassed', async () => {
  const usage = storage();
  const day = new Date().toISOString().slice(0, 10);
  usage.values.set(`requests:${day}:${await hash('primary-secret')}`, '1');
  const env = {...baseEnv, USAGE: usage, DAILY_REQUEST_LIMIT: '1', GLOBAL_DAILY_REQUEST_LIMIT: '1'};
  const keys = [];
  globalThis.fetch = async (_url, options) => { keys.push(options.headers['x-goog-api-key']); return success(); };
  assert.equal((await gateway.fetch(request(), env)).status, 200);
  assert.deepEqual(keys, ['backup-secret']);
  const response = await gateway.fetch(request(), {...env, GEMINI_API_KEY_3: 'extra'});
  assert.equal(response.status, 429);
  assert.equal((await response.json()).code, 'GATEWAY_DAILY_LIMIT');
  assert.equal(keys.length, 1);
});

test('vocabulary uses the same fallback and caches the successful result', async () => {
  const usage = storage();
  const env = {...baseEnv, USAGE: usage};
  const keys = [];
  const words = Array.from({length: 10}, (_, i) => ({word: `word${i}`, meaning: 'Meaning', example: 'Example'}));
  globalThis.fetch = async (_url, options) => {
    keys.push(options.headers['x-goog-api-key']);
    return keys.length === 1 ? new Response('', {status: 429}) : success({words});
  };
  const vocabRequest = () => request(undefined, '/v1/vocabulary', {date: '2026-11-22', difficulty: 'intermediate'});
  const first = await gateway.fetch(vocabRequest(), env);
  assert.equal(first.status, 200);
  assert.deepEqual((await first.json()).words, words);
  assert.equal((await gateway.fetch(vocabRequest(), env)).status, 200);
  assert.deepEqual(keys, ['primary-secret', 'backup-secret']);
});

for (const status of [400, 401, 403, 500, 503]) {
  test(`HTTP ${status} does not rotate keys or misreport a quota limit`, async () => {
    let calls = 0;
    globalThis.fetch = async () => { calls++; return new Response('private provider error', {status}); };
    const response = await gateway.fetch(request(), baseEnv);
    assert.equal(response.status, [401, 403].includes(status) ? 401 : 502);
    assert.equal(calls, 1);
    assert.ok(!(await response.text()).includes('private provider error'));
  });
}

test('network exceptions never cause speculative duplicate requests on another key', async () => {
  let calls = 0;
  globalThis.fetch = async () => { calls++; throw new Error('network private-key'); };
  const response = await gateway.fetch(request(), baseEnv);
  assert.equal(response.status, 502);
  assert.equal(calls, 1);
  assert.ok(!(await response.text()).includes('private-key'));
});

test('missing pool config and wrong access codes do not call Gemini', async () => {
  globalThis.fetch = () => { throw new Error('must not call upstream'); };
  assert.equal((await gateway.fetch(request(), {...baseEnv, GEMINI_API_KEY: '', GEMINI_API_KEY_2: ''})).status, 503);
  assert.equal((await gateway.fetch(request({authorization: 'Bearer wrong'}), baseEnv)).status, 401);
});
