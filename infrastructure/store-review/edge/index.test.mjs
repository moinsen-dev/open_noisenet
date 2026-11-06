import test from 'node:test';
import assert from 'node:assert/strict';
import worker from './index.mjs';

const origin = 'https://example.org';
const request = (path, init) => new Request(origin + path, init);

test('review proxy cannot reach other services or send large audio bodies', async () => {
  const noUpstream = { REVIEW_API: { fetch() { assert.fail('unexpected upstream request'); } } };
  for (const path of ['/admin', '/api/v1/snippets/', '/api/v1/public/map', '/api/v1/devices/id/private']) {
    assert.equal((await worker.fetch(request(path), noUpstream)).status, 404);
  }
  assert.equal((await worker.fetch(request('/api/v1/auth/login', {method:'POST', body:new Uint8Array(131073)}), noUpstream)).status, 413);
});

test('web deletion preserves the origin, rejects spoofed proxy headers and is never cached', async () => {
  const upstream = { REVIEW_API:{ async fetch(url, init) {
    assert.equal(url, 'http://example.org/api/v1/auth/account-deletion/web');
    assert.equal(init.method, 'POST');
    assert.equal(init.headers.get('origin'), 'https://wrong.example');
    assert.equal(init.headers.get('x-forwarded-proto'), 'https');
    assert.equal(init.headers.has('x-forwarded-for'), false);
    assert.equal(init.headers.has('cookie'), false);
    assert.equal(new TextDecoder().decode(init.body), 'synthetic');
    return new Response(null, {status:403});
  } } };
  const out = await worker.fetch(request('/api/v1/auth/account-deletion/web', {
    method:'POST', body:'synthetic', headers:{origin:'https://wrong.example',cookie:'synthetic=1',
      'x-forwarded-proto':'http','x-forwarded-for':'spoof'}
  }), upstream);
  assert.equal(out.status, 403);
  assert.equal(out.headers.get('cache-control'), 'no-store');
});
