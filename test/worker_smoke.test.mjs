import test from 'node:test';
import assert from 'node:assert/strict';
import worker from '../worker.js';

function fakeDb() {
  return {
    prepare() {
      return {
        bind() { return this; },
        async run() { return { success: true }; },
        async first() { return null; },
        async all() { return { results: [] }; },
      };
    },
  };
}

test('config is healthy and does not block clients until Cloudflare sets a minimum build', async () => {
  const response = await worker.fetch(
    new Request('https://worker.test/v1/config?app_build=255'),
    { DB: fakeDb() },
  );
  assert.equal(response.status, 200);
  const config = await response.json();
  assert.equal(config.blocking.min_version_code, 0);
  assert.deepEqual(config.blocking.blocked_version_codes, []);
  assert.equal(config.app_version, '2.5.4');
});

test('download endpoint fails clearly until a public APK URL is configured', async () => {
  const response = await worker.fetch(
    new Request('https://worker.test/v1/download'),
    { DB: fakeDb() },
  );
  assert.equal(response.status, 503);
  assert.equal((await response.json()).code, 'UPDATE_NOT_CONFIGURED');
});

test('download endpoint redirects to the configured Cloudflare/R2 artifact', async () => {
  const target = 'https://cdn.example.test/LIVE_STREAM_PRO.apk';
  const response = await worker.fetch(
    new Request('https://worker.test/v1/download'),
    { DB: fakeDb(), UPDATE_APK_URL: target },
  );
  assert.equal(response.status, 302);
  assert.equal(response.headers.get('location'), target);
});
