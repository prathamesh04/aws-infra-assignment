const { test } = require("node:test");
const assert = require("node:assert");

test("health endpoint returns 200 and status healthy", async () => {
  const app = require("../src/server");
  const server = app.listen(0);

  const { port } = server.address();
  const res = await fetch(`http://127.0.0.1:${port}/health`);
  const body = await res.json();

  assert.strictEqual(res.status, 200);
  assert.strictEqual(body.status, "healthy");
  server.close();
});

test("root endpoint returns ok", async () => {
  const app = require("../src/server");
  const server = app.listen(0);
  const { port } = server.address();

  const res = await fetch(`http://127.0.0.1:${port}/`);
  const body = await res.json();

  assert.strictEqual(res.status, 200);
  assert.strictEqual(body.status, "ok");
  server.close();
});

test("error endpoint returns 500", async () => {
  const app = require("../src/server");
  const server = app.listen(0);
  const { port } = server.address();

  const res = await fetch(`http://127.0.0.1:${port}/error`);
  assert.strictEqual(res.status, 500);
  server.close();
});
