'use strict';

const assert = require('node:assert/strict');
const os = require('node:os');
const { after, before, test } = require('node:test');
const { createApp } = require('../server');

let server;
let baseUrl;

before(async () => {
  server = createApp({ version: 'v1' }).listen(0, '127.0.0.1');
  await new Promise((resolve, reject) => {
    server.once('listening', resolve);
    server.once('error', reject);
  });
  baseUrl = `http://127.0.0.1:${server.address().port}`;
});

after(async () => {
  await new Promise((resolve, reject) => {
    server.close((error) => (error ? reject(error) : resolve()));
  });
});

test('GET /api/fortune returns a fortune and the serving Pod metadata', async () => {
  const response = await fetch(`${baseUrl}/api/fortune`);
  const body = await response.json();

  assert.equal(response.status, 200);
  assert.equal(typeof body.fortune, 'string');
  assert.ok(body.fortune.length > 0);
  assert.equal(body.pod, os.hostname());
  assert.equal(body.version, 'v1');
});

test('v2 fortunes identify the new version', async () => {
  const app = createApp({ version: 'v2' });
  const v2Server = app.listen(0, '127.0.0.1');
  await new Promise((resolve, reject) => {
    v2Server.once('listening', resolve);
    v2Server.once('error', reject);
  });

  try {
    const response = await fetch(`http://127.0.0.1:${v2Server.address().port}/api/fortune`);
    const body = await response.json();

    assert.equal(body.version, 'v2');
    assert.match(body.fortune, /^\[v2\]/);
  } finally {
    await new Promise((resolve, reject) => {
      v2Server.close((error) => (error ? reject(error) : resolve()));
    });
  }
});

test('GET /healthz returns a healthy status', async () => {
  const response = await fetch(`${baseUrl}/healthz`);
  assert.equal(response.status, 200);
  assert.deepEqual(await response.json(), { status: 'ok' });
});
