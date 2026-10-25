import assert from 'node:assert/strict';
import {afterEach, test} from 'node:test';
import gateway from '../src/index.js';

const originalFetch = globalThis.fetch;
afterEach(() => { globalThis.fetch = originalFetch; });

function request(body, token = 'private-token') {
  return new Request('https://talkmile.example/v1/reply', {
    method: 'POST',
    headers: {'authorization': `Bearer ${token}`, 'content-type': 'application/json'},
    body: JSON.stringify(body),
  });
}

const validBody = {
  utterance: 'Start a friendly conversation.',
  mode: 'conversation',
  difficulty: 'intermediate',
  corrections: 'gentle',
  storyState: '',
  recentTurns: [],
};

const env = {
  TALKMILE_ACCESS_TOKEN: 'private-token',
  GEMINI_API_KEY: 'test-only',
  GEMINI_MODEL: 'test-model',
};

test('rejects missing authorization before calling Gemini', async () => {
  globalThis.fetch = () => { throw new Error('must not call upstream'); };
  const response = await gateway.fetch(request(validBody, 'wrong'), env);
  assert.equal(response.status, 401);
});

test('rejects oversized or malformed payloads', async () => {
  const invalid = {...validBody, utterance: 'a'.repeat(2001)};
  assert.equal((await gateway.fetch(request(invalid), env)).status, 400);
  const oversized = {...validBody, utterance: 'a'.repeat(12001)};
  assert.equal((await gateway.fetch(request(oversized), env)).status, 413);
});

test('returns validated structured answer without leaking the provider key', async () => {
  let sent;
  globalThis.fetch = async (_url, options) => {
    sent = options;
    return Response.json({candidates: [{content: {parts: [{text: JSON.stringify({
      spokenText: 'Hello there.', nextQuestion: 'How was your day?',
      storyState: '', chapterCompleted: false,
      newVocabulary: [], difficulty: 'intermediate',
    })}]}}]});
  };
  const response = await gateway.fetch(request(validBody), env);
  assert.equal(response.status, 200);
  const body = await response.json();
  assert.equal(body.spokenText, 'Hello there.');
  assert.equal(sent.headers['x-goog-api-key'], 'test-only');
  assert.equal(response.headers.get('cache-control'), 'no-store');
  assert.equal(JSON.stringify(body).includes('test-only'), false);
});

test('maps upstream rate limits to an explicit quota response', async () => {
  globalThis.fetch = async () => new Response('', {status: 429});
  const response = await gateway.fetch(request(validBody), env);
  assert.equal(response.status, 429);
});

test('rejects invalid Gemini output', async () => {
  globalThis.fetch = async () => Response.json({
    candidates: [{content: {parts: [{text: '{"spokenText":""}'}]}}],
  });
  const response = await gateway.fetch(request(validBody), env);
  assert.equal(response.status, 502);
});
