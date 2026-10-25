import test from "node:test";
import assert from "node:assert/strict";
import { readFileSync } from "node:fs";
import worker, { RATE } from "../src/worker.js";
import { hmacHex } from "../src/util.js";
import { unsubToken, classify } from "../src/hooks.js";
import { scrub, spamReason, category } from "../src/report.js";
import { parseDoors, render, renderGd, ROUTES, OUT, GD_OUT } from "../gen-doors.mjs";
import { fakeD1, fakeKV } from "./fakes.mjs";

const EMAIL = "Player.One+wdb@Example.com";
const PNG = Buffer.from([0x89, 0x50, 0x4e, 0x47, 13, 10, 26, 10, 0, 0, 0, 0]).toString("base64");

function setup(extra = {}) {
  const env = { DB: fakeD1(), SHOTS: fakeKV(), REPO: "ViraXVespa/WhatDwellsBelow", RELAY_SALT: "salt", GH_WEBHOOK_SECRET: "whsec",
    GITHUB_TOKEN: "tok", EMAIL_SEND: "off", ...extra };
  const calls = [];
  let n = 100;
  globalThis.fetch = async (url, init) => {
    calls.push({ url, body: JSON.parse(init.body), auth: init.headers.Authorization });
    n += 1;
    return new Response(JSON.stringify({ number: n, html_url: `https://github.com/x/y/issues/${n}` }), { status: 201 });
  };
  return { env, calls };
}

const base = (o = {}) => ({ install_id: "inst-12345678", description: "Fell through the floor near the anvil on floor 3.",
  category: "dungeon", state: { version: "0.9.1", platform: "web", build: "release", scene: "dungeon", floor: 3, seed: 42,
    pos: [1, 2], recent: ["dodge", "attack"], perf: { fps: 58 } }, ...o });

const post = (env, body, ip = "1.2.3.4", path = "/report", headers = {}) => worker.fetch(new Request(`https://relay.test${path}`,
  { method: "POST", headers: { "Content-Type": "application/json", "CF-Connecting-IP": ip, ...headers }, body: typeof body === "string" ? body : JSON.stringify(body) }), env);

async function hook(env, event, payload, delivery = String(Math.random()), secret = "whsec") {
  const raw = JSON.stringify(payload);
  const sig = "sha256=" + (await hmacHex(secret, new TextEncoder().encode(raw)));
  return post(env, raw, "9.9.9.9", "/github-webhook", { "X-GitHub-Event": event, "X-Hub-Signature-256": sig, "X-GitHub-Delivery": delivery });
}

test("doors.js matches design/routes.yaml", () => {
  assert.equal(readFileSync(OUT, "utf8"), render(parseDoors(readFileSync(ROUTES, "utf8"))));
  assert.equal(readFileSync(GD_OUT, "utf8"), renderGd(parseDoors(readFileSync(ROUTES, "utf8"))));
});

test("health", async () => {
  const { env } = setup({ GITHUB_TOKEN: undefined });
  const j = await (await worker.fetch(new Request("https://relay.test/health"), env)).json();
  assert.equal(j.ok, true); assert.equal(j.github_token, false); assert.equal(j.email_send, "off");
});

test("dry run builds issue without creating one or storing anything", async () => {
  const { env, calls } = setup();
  const r = await post(env, base({ dry_run: true, email: EMAIL, opt_in: true, category: "ui.pause", state: { ...base().state, ssn: "x" } }));
  const j = await r.json();
  assert.equal(r.status, 200); assert.equal(j.dry_run, true); assert.equal(calls.length, 0);
  assert.deepEqual(j.labels, ["bug-report", "door:ui", "job:ui.pause", "build:release", "platform:web"]);
  assert.deepEqual(j.dropped_state_keys, ["ssn"]);
  assert.ok(!JSON.stringify(j).toLowerCase().includes("player.one"));
  assert.equal(env.DB.rows("SELECT COUNT(*) FROM reporters")[0][0], 0);
});

test("real report: issue has reporter code only, email private in D1, screenshot stored", async () => {
  const { env, calls } = setup();
  const desc = `Boss froze. Contact me at ${EMAIL} or other@mail.org please, @someone`;
  const r = await post(env, base({ description: desc, email: EMAIL, opt_in: true, screenshot: PNG,
    state: { ...base().state, settings: { note: EMAIL.toLowerCase() } } }));
  const j = await r.json();
  assert.equal(r.status, 201, JSON.stringify(j));
  assert.match(j.reporter, /^R-[0-9a-f]{4}$/);
  const sent = JSON.stringify(calls[0].body).toLowerCase();
  assert.ok(!sent.includes("player.one") && !sent.includes("other@mail.org"), "email leaked into issue");
  assert.ok(sent.includes(j.reporter.toLowerCase()));
  assert.ok(calls[0].body.body.includes("@\u200bsomeone"));
  assert.match(calls[0].body.body, /\/shot\/[A-Za-z0-9_-]{24}/);
  assert.equal(calls[0].auth, "Bearer tok");
  const [[code, email, opt]] = env.DB.rows("SELECT reporter_code, email, opt_in FROM reporters");
  assert.equal(code, j.reporter); assert.equal(email, EMAIL.toLowerCase()); assert.equal(opt, 1);
  const key = calls[0].body.body.match(/\/shot\/([A-Za-z0-9_-]+)/)[1];
  const img = await worker.fetch(new Request(`https://relay.test/shot/${key}`), env);
  assert.equal(img.headers.get("Content-Type"), "image/png");
  // Same email again reuses the code; duplicate text is refused.
  const again = await (await post(env, base({ description: "Another bug: chest won't open on floor 2.", email: EMAIL }))).json();
  assert.equal(again.reporter, j.reporter);
  const dup = await post(env, base({ description: desc, email: EMAIL }));
  assert.equal(dup.status, 409);
});

test("validation: logs only with crash, bad category, bad shot, state keys", async () => {
  const { env } = setup();
  assert.equal((await post(env, base({ log: "line" }))).status, 422);
  assert.equal((await post(env, base({ crash: true, log: "trace", dry_run: true }))).status, 200);
  assert.equal((await post(env, base({ category: "nope" }))).status, 422);
  assert.equal((await post(env, base({ category: "ui.nope" }))).status, 422);
  assert.equal((await post(env, base({ screenshot: btoa("GIF89a....") }))).status, 422);
  assert.equal((await post(env, base({ install_id: "x" }))).status, 422);
  assert.equal((await post(env, base({ description: "short" }))).status, 422);
  assert.equal((await post(env, "{nope")).status, 400);
  assert.equal((await post(env, base({ email: "not-an-email" }))).status, 422);
  assert.throws(() => category("a.b.c"));
});

test("crash report gets crash label and log", async () => {
  const { env, calls } = setup();
  const r = await post(env, base({ crash: true, log: "ERROR: null instance at foo.gd:12" }));
  assert.equal(r.status, 201);
  assert.ok(calls[0].body.labels.includes("crash"));
  assert.ok(calls[0].body.body.includes("foo.gd:12"));
});

test("spam heuristics", async () => {
  assert.equal(spamReason("see http://a http://b http://c now"), "too_many_links");
  assert.equal(spamReason("aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa"), "repetitive");
  assert.equal(spamReason("cheap casino bonus here today"), "spam_words");
  assert.equal(spamReason("The torch flickers when I dodge in the hub."), null);
  const { env } = setup();
  assert.equal((await post(env, base({ description: "buy now http://a.x http://b.x http://c.x" }))).status, 422);
  assert.equal(scrub("mail A@B.co now", null), "mail [email removed] now");
});

test("rate limits per install and per IP", async () => {
  const { env } = setup();
  let last;
  for (let i = 0; i <= RATE.installHour; i++) last = await post(env, base({ dry_run: true }), `10.0.0.${i}`);
  assert.equal(last.status, 429);
  const e2 = setup().env;
  for (let i = 0; i <= RATE.ipHour; i++) last = await post(e2, base({ dry_run: true, install_id: `install-${i}0000000` }), "5.5.5.5");
  assert.equal(last.status, 429);
});

test("no token: real report refused, dry run still works", async () => {
  const { env } = setup({ GITHUB_TOKEN: "" });
  assert.equal((await post(env, base())).status, 503);
  assert.equal((await post(env, base({ dry_run: true }))).status, 200);
});

test("webhook: signature, comment/ask/close queue for opted-in reporter, dedupe, unsubscribe", async () => {
  const { env } = setup();
  const rep = await (await post(env, base({ email: EMAIL, opt_in: true }))).json();
  const issue = { number: rep.issue, state_reason: "completed" };
  const repo = { full_name: "ViraXVespa/WhatDwellsBelow" };
  assert.equal((await hook(env, "issues", { action: "closed", issue, repository: repo }, "d0", "wrong")).status, 401);
  assert.equal((await (await hook(env, "ping", { zen: "x" })).json()).pong, true);
  const c1 = await (await hook(env, "issue_comment", { action: "created", issue, repository: repo, comment: { author_association: "OWNER", body: "/ask Which floor was it?" } }, "d1")).json();
  assert.equal(c1.kind, "ask"); assert.equal(c1.queued, true); assert.equal(c1.sent, false);
  assert.equal((await (await hook(env, "issue_comment", { action: "created", issue, repository: repo, comment: { author_association: "OWNER", body: "/ask again" } }, "d1")).json()).duplicate, true);
  assert.equal((await (await hook(env, "issue_comment", { action: "created", issue, repository: repo, comment: { author_association: "NONE", body: "me too" } })).json()).ignored, "event");
  assert.equal((await (await hook(env, "issue_comment", { action: "created", issue, repository: repo, comment: { author_association: "OWNER", body: "/quiet internal" } })).json()).ignored, "event");
  const c3 = await (await hook(env, "issues", { action: "closed", issue, repository: repo })).json();
  assert.equal(c3.kind, "closed");
  assert.equal(env.DB.rows(`SELECT status FROM reports WHERE issue_number=${rep.issue}`)[0][0], "closed");
  const out = env.DB.rows("SELECT kind, body, state FROM outbox ORDER BY id");
  assert.deepEqual(out.map((r) => r[0]), ["ask", "closed"]);
  assert.ok(out.every((r) => !r[1].toLowerCase().includes("player.one")));
  assert.match(out[0][1], /Which floor was it\?/);
  // unsubscribe
  const bad = await worker.fetch(new Request(`https://relay.test/unsubscribe?r=${rep.reporter}&t=nope`), env);
  assert.equal(bad.status, 400);
  const t = await unsubToken(env, rep.reporter);
  assert.equal((await worker.fetch(new Request(`https://relay.test/unsubscribe?r=${rep.reporter}&t=${t}`), env)).status, 200);
  assert.deepEqual(env.DB.rows("SELECT opt_in FROM reporters")[0], [0]);
  const c4 = await (await hook(env, "issues", { action: "reopened", issue, repository: repo })).json();
  assert.equal(c4.reason, "no_opt_in");
  assert.equal(classify("issues", { action: "labeled", issue }), null);
});

test("webhook ignores issues the relay did not file and other repos", async () => {
  const { env } = setup();
  assert.equal((await (await hook(env, "issues", { action: "closed", issue: { number: 5 }, repository: { full_name: "ViraXVespa/WhatDwellsBelow" } })).json()).ignored, "not_a_relay_issue");
  assert.equal((await (await hook(env, "issues", { action: "closed", issue: { number: 5 }, repository: { full_name: "a/b" } })).json()).ignored, "other_repo");
});
