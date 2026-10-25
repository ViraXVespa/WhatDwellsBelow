// wdb-bug-relay: in-game bug reports -> GitHub issues on env.REPO. Emails stay in D1, never in issues or logs.
// Endpoints: GET /health, POST /report, GET /shot/:key, POST /github-webhook, GET|POST /unsubscribe.
import { json, err, CORS, now, sha256, randomToken, hit, sweepRate } from "./util.js";
import { Bad, LIMITS, validate, spamReason, labels, issueTitle, issueBody } from "./report.js";
import { githubWebhook, unsubscribe } from "./hooks.js";

export const VERSION = "1";
export const RATE = { ipHour: 10, ipDay: 30, installHour: 5, installDay: 15, globalDay: 300 };

async function reporterFor(env, r, installHash) {
  const db = env.DB;
  const emailHash = r.email ? await sha256(env.RELAY_SALT, r.email) : null;
  const found = emailHash
    ? await db.prepare("SELECT reporter_code FROM reporters WHERE email_hash=?1").bind(emailHash).first()
    : await db.prepare("SELECT reporter_code FROM reporters WHERE install_hash=?1 AND email IS NULL").bind(installHash).first();
  if (found) {
    if (emailHash) await db.prepare("UPDATE reporters SET opt_in=?1, unsub_at=CASE WHEN ?1=1 THEN NULL ELSE unsub_at END WHERE reporter_code=?2")
      .bind(r.optIn ? 1 : 0, found.reporter_code).run();
    return found.reporter_code;
  }
  for (let i = 0; i < 8; i++) {
    const n = i < 5 ? 2 : 3;
    const code = "R-" + [...crypto.getRandomValues(new Uint8Array(n))].map((b) => b.toString(16).padStart(2, "0")).join("");
    const ins = await db.prepare("INSERT OR IGNORE INTO reporters (reporter_code, email, email_hash, install_hash, opt_in, created) VALUES (?1,?2,?3,?4,?5,?6)")
      .bind(code, r.email, emailHash, installHash, r.optIn ? 1 : 0, now()).run();
    if (ins.meta && ins.meta.changes === 1) return code;
  }
  throw new Bad(503, "busy", "could not allocate a reporter code");
}

async function createIssue(env, title, body, labelList) {
  const res = await fetch(`https://api.github.com/repos/${env.REPO}/issues`, {
    method: "POST",
    headers: { Authorization: `Bearer ${env.GITHUB_TOKEN}`, Accept: "application/vnd.github+json",
      "X-GitHub-Api-Version": "2022-11-28", "User-Agent": "wdb-bug-relay", "Content-Type": "application/json" },
    body: JSON.stringify({ title, body, labels: labelList }),
  });
  if (!res.ok) throw new Bad(502, "github_error", `GitHub returned ${res.status}`);
  const j = await res.json();
  return { number: j.number, url: j.html_url };
}

export async function report(req, env) {
  const len = Number(req.headers.get("Content-Length") || 0);
  if (len > LIMITS.body) return err(413, "too_big", `body over ${LIMITS.body} bytes`);
  const ip = req.headers.get("CF-Connecting-IP") || "unknown";
  const ipHash = await sha256(env.RELAY_SALT, `ip:${ip}`);
  await sweepRate(env.DB);
  if ((await hit(env.DB, "ip1h", ipHash, 3600)) > RATE.ipHour || (await hit(env.DB, "ip1d", ipHash, 86400)) > RATE.ipDay)
    return err(429, "rate_limited", "too many reports from this network; try later");
  const text = await req.text();
  if (text.length > LIMITS.body) return err(413, "too_big", `body over ${LIMITS.body} bytes`);
  let payload;
  try { payload = JSON.parse(text); } catch { return err(400, "bad_json", "body must be JSON"); }
  try {
    const r = validate(payload);
    const installHash = await sha256(env.RELAY_SALT, `install:${r.installId}`);
    if ((await hit(env.DB, "in1h", installHash, 3600)) > RATE.installHour || (await hit(env.DB, "in1d", installHash, 86400)) > RATE.installDay)
      return err(429, "rate_limited", "too many reports from this game; try later");
    const spam = spamReason(r.desc);
    if (spam) return err(422, "spam", "report looks like spam", { reason: spam });
    const descHash = await sha256(env.RELAY_SALT, `desc:${r.desc.toLowerCase().replace(/\s+/g, " ")}`);
    const dupe = await env.DB.prepare("SELECT issue_number FROM reports WHERE desc_hash=?1 AND created>?2 AND install_hash=?3")
      .bind(descHash, now() - 86400, installHash).first();
    if (dupe) return err(409, "duplicate", "same report already filed", { issue: dupe.issue_number });
    const labelList = labels(r);
    const title = issueTitle(r);
    if (r.dryRun) {
      return json({ ok: true, dry_run: true, title, labels: labelList, body: issueBody(r, "R-dry0", r.shot ? "https://example.invalid/shot" : null),
        email: r.email ? "provided (private)" : "none", opt_in: r.optIn, dropped_state_keys: r.dropped });
    }
    if (!env.GITHUB_TOKEN) return err(503, "not_configured", "relay has no GitHub token yet");
    if ((await hit(env.DB, "g1d", "all", 86400)) > RATE.globalDay) return err(503, "busy", "daily report limit reached; try tomorrow");
    const code = await reporterFor(env, r, installHash);
    let shotKey = null, shotUrl = null;
    if (r.shot && env.SHOTS) {
      shotKey = randomToken(18);
      await env.SHOTS.put(shotKey, r.shot.bytes, { metadata: { type: r.shot.type }, expirationTtl: 60 * 60 * 24 * 365 });
      shotUrl = `${new URL(req.url).origin}/shot/${shotKey}`;
    }
    const issue = await createIssue(env, title, issueBody(r, code, shotUrl), labelList);
    await env.DB.prepare("INSERT INTO reports (issue_number, reporter_code, created, door, desc_hash, install_hash, shot_key) VALUES (?1,?2,?3,?4,?5,?6,?7)")
      .bind(issue.number, code, now(), r.job ? `${r.door}.${r.job}` : r.door, descHash, installHash, shotKey).run();
    return json({ ok: true, issue: issue.number, url: issue.url, reporter: code, dropped_state_keys: r.dropped }, 201);
  } catch (e) {
    if (e instanceof Bad) return err(e.status, e.code, e.message);
    return err(500, "internal", "relay error");   // deliberately no payload in logs
  }
}

async function shot(key, env) {
  if (!/^[A-Za-z0-9_-]{20,40}$/.test(key) || !env.SHOTS) return new Response("not found", { status: 404 });
  const { value, metadata } = await env.SHOTS.getWithMetadata(key, "arrayBuffer");
  if (!value) return new Response("not found", { status: 404 });
  return new Response(value, { headers: { "Content-Type": (metadata && metadata.type) || "image/png", "Cache-Control": "public, max-age=31536000, immutable", "X-Content-Type-Options": "nosniff" } });
}

export default {
  async fetch(req, env) {
    const { pathname } = new URL(req.url);
    if (req.method === "OPTIONS") return new Response(null, { status: 204, headers: CORS });
    if (pathname === "/health" && req.method === "GET")
      return json({ ok: true, service: "wdb-bug-relay", version: VERSION, repo: env.REPO, github_token: !!env.GITHUB_TOKEN,
        webhook_secret: !!env.GH_WEBHOOK_SECRET, email_send: env.EMAIL_SEND || "off", screenshots: !!env.SHOTS });
    if (pathname === "/report" && req.method === "POST") return report(req, env);
    if (pathname.startsWith("/shot/") && req.method === "GET") return shot(pathname.slice(6), env);
    if (pathname === "/github-webhook" && req.method === "POST") return githubWebhook(req, env);
    if (pathname === "/unsubscribe" && (req.method === "GET" || req.method === "POST")) return unsubscribe(req, env);
    return err(404, "not_found", "unknown endpoint");
  },
};
