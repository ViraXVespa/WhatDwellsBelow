import test from "node:test";
import assert from "node:assert/strict";
import { readFileSync, mkdtempSync, cpSync, rmSync, writeFileSync } from "node:fs";
import { tmpdir } from "node:os";
import { join } from "node:path";
import { spawnSync } from "node:child_process";
import { runInNewContext } from "node:vm";
import { buildMetadata, CONFIG } from "../deploy-payload.mjs";
import { sendEmail } from "../src/hooks.js";

// These are mocks only. No real recipient, provider, secret or network is involved.
const sender = "relay@example.test", to = "player@example.test";
const ready = (send) => ({ EMAIL_SEND: "on", EMAIL_FROM: sender, EMAIL: { send } });

test("off and incomplete config cannot call the binding", async () => {
  let calls = 0;
  const env = ready(async () => { calls++; return { messageId: "mock" }; });
  for (const flag of [undefined, "off", "1", "true", "ON"]) {
    assert.equal((await sendEmail({ ...env, EMAIL_SEND: flag }, to, "s", "b")).reason, "email_send_off");
  }
  for (const from of ["", undefined, "not-an-address", "x@example.test\r\nBcc: y@example.test"]) {
    assert.equal((await sendEmail({ ...env, EMAIL_FROM: from }, to, "s", "b")).sent, false);
  }
  assert.equal((await sendEmail({ ...env, EMAIL: undefined }, to, "s", "b")).reason, "email_binding_missing");
  assert.equal((await sendEmail(env, "not-an-address", "s", "b")).sent, false);
  assert.equal(calls, 0);
});

test("structured send has plain text and escaped HTML; acceptance requires messageId", async () => {
  const calls = [];
  const env = ready(async (message) => { calls.push(message); return { messageId: "mock-accepted" }; });
  const text = '<script a="x">& \'text\'</script>\nStop: https://relay.test/unsubscribe?r=R-1234&t=mock';
  assert.deepEqual(await sendEmail(env, to, "Report update", text), { sent: true });
  assert.deepEqual(Object.keys(calls[0]).sort(), ["from", "html", "subject", "text", "to"]);
  assert.equal(calls[0].from, sender); assert.equal(calls[0].to, to); assert.equal(calls[0].text, text);
  assert.match(calls[0].html, /&lt;script a=&quot;x&quot;&gt;&amp; &#39;text&#39;&lt;\/script&gt;/);
  assert.ok(!calls[0].html.includes("<script"));
  for (const result of [undefined, null, {}, { messageId: "" }, { messageId: " " }, { messageId: 9 }]) {
    assert.deepEqual(await sendEmail(ready(async () => result), to, "s", "b"), { sent: false, reason: "email_not_accepted" });
  }
  const failure = await sendEmail(ready(async () => { throw new Error(`private ${to} body`); }), to, "s", "b");
  assert.deepEqual(failure, { sent: false, reason: "email_send_failed" });
  assert.ok(!JSON.stringify(failure).includes(to));
});

test("Wrangler and pure connector metadata share the disabled, unchosen sender config", () => {
  const config = JSON.parse(readFileSync(new URL("../wrangler.jsonc", import.meta.url), "utf8"));
  const metadata = buildMetadata();
  assert.equal(CONFIG.script, config.name);
  assert.equal(CONFIG.vars.EMAIL_SEND, "off"); assert.equal(CONFIG.vars.EMAIL_FROM, "");
  assert.equal(config.send_email[0].remote, false, "local tests must never use real sending");
  assert.deepEqual(metadata.bindings.find((b) => b.type === "send_email"), { type: "send_email", name: "EMAIL" });
  assert.deepEqual(metadata.bindings.find((b) => b.type === "d1"), { type: "d1", name: "DB", database_id: config.d1_databases[0].database_id });
  assert.deepEqual(metadata.keep_bindings, ["secret_text"]);
});


test("legacy payload CLI bundles sender and restrictions without deploying or reading secrets", async () => {
  const dir = mkdtempSync(join(tmpdir(), "wdb-relay-payload-"));
  try {
    for (const name of ["src", "deploy-payload.mjs", "wrangler.jsonc"])
      cpSync(new URL(`../${name}`, import.meta.url), join(dir, name), { recursive: true });
    const config = JSON.parse(readFileSync(join(dir, "wrangler.jsonc"), "utf8"));
    config.send_email[0].allowed_sender_addresses = [sender]; // Fixture only, not the real config.
    writeFileSync(join(dir, "wrangler.jsonc"), JSON.stringify(config));
    const result = spawnSync(process.execPath, [join(dir, "deploy-payload.mjs")], { encoding: "utf8" });
    assert.equal(result.status, 0, result.stderr);
    const code = readFileSync(join(dir, ".secrets/deploy.js"), "utf8"); // Generated fixture has no secrets.
    const calls = [];
    await runInNewContext(`(${code})()`, { accountId: "mock-account", cloudflare: { request: async (req) => {
      calls.push(req); return { success: true, result: {} };
    } } });
    assert.equal(calls.length, 2);
    assert.equal(calls[0].method, "PUT"); assert.match(calls[0].body, /filename="email.js"/);
    const metadata = JSON.parse(calls[0].body.split("\r\n\r\n")[1].split("\r\n")[0]);
    assert.deepEqual(metadata.bindings.find((b) => b.type === "send_email"), {
      type: "send_email", name: "EMAIL", allowed_sender_addresses: [sender],
    });
    assert.equal(metadata.bindings.find((b) => b.name === "EMAIL_SEND").text, "off");
    assert.ok(!metadata.bindings.some((b) => b.type === "secret_text"));
  } finally { rmSync(dir, { recursive: true, force: true }); }
});
