import test from "node:test";
import assert from "node:assert/strict";
import { readFileSync, mkdtempSync, cpSync, rmSync, writeFileSync } from "node:fs";
import { tmpdir } from "node:os";
import { join } from "node:path";
import { spawnSync } from "node:child_process";
import { runInNewContext } from "node:vm";
import { buildMetadata, CONFIG } from "../deploy-payload.mjs";
import { sendEmail } from "../src/hooks.js";
import worker from "../src/worker.js";


// Fixtures only: no real credentials, network, mail or deployment.
const sender = "relay@example.test", to = "player@example.test", key = "wdb-bug-relay/outbox/1";
const ready = { EMAIL_SEND: "on", EMAIL_FROM: sender, RESEND_API_KEY: "re_fixture" };
const reply = (value, status = 200) => new Response(JSON.stringify(value), { status });
const send = (env = ready, request = async () => reply({ id: "mock-accepted" }), recipient = to, id = key) =>
  sendEmail(env, recipient, "Update", "<test> & text", id, request);

test("off, incomplete config, invalid addresses and missing identity never fetch", async () => {
  let calls = 0;
  const request = async () => { calls++; return reply({ id: "mock" }); };
  for (const flag of [undefined, "off", "1", "true", "ON"])
    assert.equal((await send({ ...ready, EMAIL_SEND: flag }, request)).reason, "email_send_off");
  for (const from of ["", undefined, "bad", "x@example.test,y@example.test"])
    assert.equal((await send({ ...ready, EMAIL_FROM: from }, request)).sent, false);
  assert.equal((await send({ ...ready, RESEND_API_KEY: "" }, request)).reason, "email_key_missing");
  for (const recipient of ["bad", "x@example.test,y@example.test"])
    assert.equal((await send(ready, request, recipient)).sent, false);
  for (const id of ["", "x".repeat(257)])
    assert.equal((await send(ready, request, to, id)).reason, "email_idempotency_missing");
  assert.equal(calls, 0);
});

test("HTTPS request uses stable idempotency and preserves text with escaped HTML", async () => {
  const calls = [];
  const request = async (url, init) => { calls.push({ url, init }); return reply({ id: "mock-accepted" }); };
  const text = "<script>& text</script>";
  for (let i = 0; i < 2; i++)
    assert.deepEqual(await sendEmail({ ...ready, EMAIL_FROM: `WDB <${sender}>` }, to, "Update", text, key, request), { sent: true, providerId: "mock-accepted", stage: "accepted", httpStatus: 200 });
  assert.equal(calls[0].url, "https://api.resend.com/emails");
  const init = calls[0].init, message = JSON.parse(init.body);
  assert.equal(init.method, "POST"); assert.equal(init.redirect, "manual"); assert.ok(init.signal instanceof AbortSignal);
  assert.equal(init.headers.Authorization, "Bearer re_fixture");
  assert.equal(init.headers["Idempotency-Key"], key); assert.equal(calls[1].init.headers["Idempotency-Key"], key);
  assert.equal(message.text, text); assert.equal(message.to, to); assert.equal(message.from, `WDB <${sender}>`);
  assert.equal(message.html, "<pre>&lt;script&gt;&amp; text&lt;/script&gt;</pre>");
});

test("only Resend id means accepted; quota, timeout, malformed and oversized replies stay unsent", async () => {
  for (const value of [null, {}, { messageId: "obsolete-api" }, { id: "" }, { id: " " }, { id: 7 }])
    assert.deepEqual(await send(ready, async () => reply(value)), { sent: false, reason: "email_not_accepted", stage: "decode", httpStatus: 200 });
  for (const status of [301, 302, 307, 308, 400, 401, 403, 409, 429, 500]) {
    let calls = 0;
    assert.deepEqual(await send(ready, async () => { calls++; return reply({ private: to }, status); }), { sent: false, reason: "email_send_failed", stage: "response", httpStatus: status });
    assert.equal(calls, 1, "no blind retries, including quota errors");
  }
  assert.equal((await send(ready, async () => reply({ id: "x".repeat(5000) }))).sent, false);
  for (const [request, stage, httpStatus] of [[async () => { throw new Error(`private ${to}`); }, "fetch", null], [async () => new Response("bad-json"), "decode", 200]]) {
    const failure = await send(ready, request);
    assert.deepEqual(failure, { sent: false, reason: "email_send_failed", stage, httpStatus });
    assert.ok(!JSON.stringify(failure).includes(to));
  }
});

test("metadata preserves independently provisioned secrets even with named upserts", () => {
  const config = JSON.parse(readFileSync(new URL("../wrangler.jsonc", import.meta.url), "utf8"));
  assert.equal(CONFIG.script, "wdb-bug-relay"); assert.equal(CONFIG.vars.EMAIL_SEND, "on");
  assert.equal(CONFIG.vars.EMAIL_FROM, "WDB Bug Reports <bugs@mail.viraxvespa.com>");
  assert.deepEqual(config.secrets.required, ["RESEND_API_KEY"]); assert.equal(config.send_email, undefined);
  for (const supplied of [[], [{ type: "secret_text", name: "RELAY_SALT", text: "fixture" }]]) {
    const metadata = buildMetadata(supplied);
    assert.deepEqual(metadata.keep_bindings, ["secret_text"]);
    assert.ok(!metadata.bindings.some((b) => b.type === "send_email" || b.name === "RESEND_API_KEY"));
    assert.deepEqual(metadata.bindings.filter((b) => b.type === "secret_text"), supplied);
  }
});

test("all payload CLI modes retain unknown secrets using temporary fake credentials only", async () => {
  const dir = mkdtempSync(join(tmpdir(), "wdb-relay-payload-"));
  try {
    for (const name of ["src", "deploy-payload.mjs", "wrangler.jsonc"])
      cpSync(new URL(`../${name}`, import.meta.url), join(dir, name), { recursive: true });
    const { mkdirSync } = await import("node:fs");
    mkdirSync(join(dir, ".secrets"));
    writeFileSync(join(dir, ".secrets/gh_webhook_secret"), "fixture-webhook");
    writeFileSync(join(dir, ".secrets/relay_salt"), "fixture-salt");
    for (const mode of [[], ["--with-secrets"], ["--with-secrets", "--rotate-github-token"]]) {
      const result = spawnSync(process.execPath, [join(dir, "deploy-payload.mjs"), ...mode], {
        encoding: "utf8", env: { ...process.env, WDB_ISSUES_TOKEN: "fixture-github" },
      });
      assert.equal(result.status, 0, result.stderr);
      const code = readFileSync(join(dir, ".secrets/deploy.js"), "utf8");
      const calls = [];
      await runInNewContext(`(${code})()`, { accountId: "mock-account", cloudflare: { request: async (req) => {
        calls.push(req); return { success: true, result: {} };
      } } });
      assert.equal(calls.length, 2); assert.match(calls[0].body, /filename="email.js"/);
      const header = calls[0].body.split(String.fromCharCode(13,10,13,10))[1].split(String.fromCharCode(13,10))[0];
      const metadata = JSON.parse(header);
      assert.deepEqual(metadata.keep_bindings, ["secret_text"]);
      assert.equal(metadata.bindings.find((b) => b.name === "EMAIL_SEND").text, "on");
      assert.ok(!metadata.bindings.some((b) => b.name === "RESEND_API_KEY"));
      assert.equal(metadata.bindings.filter((b) => b.type === "secret_text").length, mode.length ? (mode.includes("--rotate-github-token") ? 3 : 2) : 0);
      assert.equal(metadata.bindings.some((b) => b.name === "GITHUB_TOKEN"), mode.includes("--rotate-github-token"), "stale legacy env must not silently rotate the deployed key");
    }
    for (const args of [["--rotate-github-token"], ["--with-secrets", "--rotate-github-token"]]) {
      const result = spawnSync(process.execPath, [join(dir, "deploy-payload.mjs"), ...args], {
        encoding: "utf8", env: { ...process.env, WDB_ISSUES_TOKEN: "" },
      });
      assert.notEqual(result.status, 0, "rotation must fail without explicit mode and source");
      assert.ok(!result.stderr.includes("fixture-github"));
    }
  } finally { rmSync(dir, { recursive: true, force: true }); }
});


test("existing health checks credential shape without disclosing value, length or hash or fetching", async () => {
  for (const value of [undefined, {}, "github_pat_fixture", "ghp_fixture", "github_pat_fixture\n", '"github_pat_fixture"', "Bearer github_pat_fixture", "$file:/fixture"]) {
    const response = await worker.fetch(new Request("https://relay.example.test/health"), { GITHUB_TOKEN: value });
    const health = await response.json();
    assert.equal(health.github_token_string, typeof value === "string");
    assert.equal(health.github_token_trimmed, typeof value === "string" && value === value.trim());
    assert.equal(health.github_token_pat_shape, value === "github_pat_fixture" || value === "ghp_fixture");
    const serialized = JSON.stringify(health);
    assert.ok(!serialized.includes("fixture"));
    assert.ok(!/hash|length/.test(serialized));
  }
});
