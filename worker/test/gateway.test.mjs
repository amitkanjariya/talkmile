import assert from 'node:assert/strict';
import {afterEach, test} from 'node:test';
import gateway from '../src/index.js';

const originalFetch = globalThis.fetch;
afterEach(() => { globalThis.fetch = originalFetch; });

function request(body, token = 'private-token', path = '/v1/reply') {
  return new Request(`https://talkmile.example${path}`, {
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

test('accepts a friend token while retaining the original token', async () => {
  globalThis.fetch = async () => Response.json({candidates: [{content: {parts: [{text: JSON.stringify({
    spokenText: 'Thanks for sharing.', nextQuestion: 'What happened next?',
    corrections: [], storyState: '', chapterCompleted: false,
    newVocabulary: [], difficulty: 'intermediate',
  })}]}}]});
  const envWithFriend = {...env, TALKMILE_ACCESS_TOKENS: 'friend-private-token, another-token'};

  const ownerResponse = await gateway.fetch(request(validBody, 'private-token'), envWithFriend);
  const friendResponse = await gateway.fetch(request(validBody, 'friend-private-token'), envWithFriend);
  const unknownResponse = await gateway.fetch(request(validBody, 'unregistered-token'), envWithFriend);

  assert.equal(ownerResponse.status, 200);
  assert.equal(friendResponse.status, 200);
  assert.equal(unknownResponse.status, 401);
});

test('rejects oversized or malformed payloads', async () => {
  const invalid = {...validBody, utterance: 'a'.repeat(2001)};
  assert.equal((await gateway.fetch(request(invalid), env)).status, 400);
  const oversized = {...validBody, utterance: 'a'.repeat(20001)};
  assert.equal((await gateway.fetch(request(oversized), env)).status, 413);
});

test('returns validated structured answer without leaking the provider key', async () => {
  let sent;
  globalThis.fetch = async (_url, options) => {
    sent = options;
    return Response.json({candidates: [{content: {parts: [{text: JSON.stringify({
      spokenText: 'Hello there.', nextQuestion: 'How was your day?',
      corrections: [], storyState: '', chapterCompleted: false,
      newVocabulary: [], difficulty: 'intermediate',
    })}]}}]});
  };
  const response = await gateway.fetch(request(validBody), env);
  assert.equal(response.status, 200);
  const body = await response.json();
  assert.equal(body.spokenText, 'Hello there.');
  assert.equal(sent.headers['x-goog-api-key'], 'test-only');
  const prompt = JSON.parse(sent.body).systemInstruction.parts[0].text;
  assert.match(prompt, /Answer the learner's personal/);
  assert.match(prompt, /answer honestly that you are an AI/);
  assert.match(prompt, /Never repeat or/);
  assert.match(prompt, /Track each clear grammar/);
  assert.equal(response.headers.get('cache-control'), 'no-store');
  assert.equal(JSON.stringify(body).includes('test-only'), false);
});

test('replaces a repeated question and supplies recent corrections to Gemini', async () => {
  let sent;
  globalThis.fetch = async (_url, options) => {
    sent = options;
    return Response.json({candidates: [{content: {parts: [{text: JSON.stringify({
      spokenText: 'That sounds like a busy day.',
      nextQuestion: 'How do you manage energy during a busy workday?',
      corrections: [{original: 'I go yesterday', improved: 'I went yesterday',
        explanation: 'Use the past form for yesterday.'}],
      storyState: '', chapterCompleted: false, newVocabulary: [], difficulty: 'intermediate',
    })}]}}]});
  };
  const body = {...validBody,
    recentTurns: [{user: 'I felt tired.',
      assistant: 'How do you usually manage your energy levels during a busy workday?'}],
    correctionReview: true,
    correctionHistory: [{original: 'I was in market', improved: 'I was at the market',
      explanation: 'Use “at” for this place.'}],
  };
  const response = await gateway.fetch(request(body), env);
  assert.equal(response.status, 200);
  const result = await response.json();
  assert.notEqual(result.nextQuestion, body.recentTurns[0].assistant);
  assert.ok(result.nextQuestion.endsWith('?'));
  const prompt = JSON.parse(sent.body).contents[0].parts[0].text;
  const serialized = JSON.parse(prompt);
  assert.equal(serialized.correctionReview, true);
  assert.equal(serialized.correctionHistory.length, 1);
  assert.equal(result.corrections[0].improved, 'I went yesterday');
});

test('generates and caches ten daily vocabulary words', async () => {
  const values = new Map();
  const usage = {
    async get(key) { return values.get(key) ?? null; },
    async put(key, value) { values.set(key, value); },
  };
  let upstreamCalls = 0;
  globalThis.fetch = async () => {
    upstreamCalls++;
    const words = Array.from({length: 10}, (_, i) => ({
      word: `word${i}`, meaning: 'A useful meaning.', example: 'A short example.',
    }));
    return Response.json({candidates: [{content: {parts: [{text: JSON.stringify({words})}]}}]});
  };
  const body = {date: '2026-11-21', difficulty: 'intermediate'};
  const first = await gateway.fetch(request(body, 'private-token', '/v1/vocabulary'), {...env, USAGE: usage});
  const second = await gateway.fetch(request(body, 'private-token', '/v1/vocabulary'), {...env, USAGE: usage});
  assert.equal(first.status, 200);
  assert.equal((await first.json()).words.length, 10);
  assert.equal(second.status, 200);
  assert.equal(upstreamCalls, 1);
});

test('daily vocabulary requests practical B1-B2 stretch words', async () => {
  let sent;
  globalThis.fetch = async (_url, options) => {
    sent = options;
    const words = Array.from({length: 10}, (_, i) => ({
      word: `word${i}`, meaning: 'A useful meaning.', example: 'A short example.',
    }));
    return Response.json({candidates: [{content: {parts: [{text: JSON.stringify({words})}]}}]});
  };
  const body = {date: '2026-11-22', difficulty: 'intermediate'};
  const response = await gateway.fetch(request(body, 'private-token', '/v1/vocabulary'), env);
  assert.equal(response.status, 200);
  const prompt = JSON.parse(sent.body).systemInstruction.parts[0].text;
  assert.match(prompt, /B1-B2/);
  assert.match(prompt, /A1-A2/);
  assert.match(prompt, /overwhelmed/);
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
