// GitHub webhook -> outbox, unsubscribe, and the (stubbed) email sender.
import { json, err, now, hmacHex, safeEqual } from "./util.js";

const MAINTAINER = ["OWNER", "MEMBER", "COLLABORATOR"];

export async function unsubToken(env, code) {
  return (await hmacHex(env.RELAY_SALT, `unsub:${code}`)).slice(0, 32);
}

export async function unsubUrl(env, origin, code) {
  return `${origin}/unsubscribe?r=${encodeURIComponent(code)}&t=${await unsubToken(env, code)}`;
}

// TODO(email): wire a sender once Vira picks a domain (Cloudflare Email Sending needs one she owns).
// Until then EMAIL_SEND stays "off" and every message waits in outbox with state 'queued'.
export async function sendEmail(env, _to, _subject, _body) {
  if (env.EMAIL_SEND !== "on") return { sent: false, reason: "email_send_off" };
  return { sent: false, reason: "sender_not_implemented" };
}

async function queue(env, origin, rep, issue, kind, subject, text) {
  const unsub = await unsubUrl(env, origin, rep.reporter_code);
  const body = `${text}\n\nIssue: https://github.com/${env.REPO}/issues/${issue}\nStop these emails: ${unsub}`;
  const row = await env.DB.prepare(
    "INSERT INTO outbox (reporter_code, issue_number, kind, subject, body, created) VALUES (?1, ?2, ?3, ?4, ?5, ?6) RETURNING id"
  ).bind(rep.reporter_code, issue, kind, subject, body, now()).first();
  const res = await sendEmail(env, rep.email, subject, body);
  if (res.sent) await env.DB.prepare("UPDATE outbox SET state='sent', sent_at=?1 WHERE id=?2").bind(now(), row.id).run();
  return { queued: true, outbox_id: row.id, sent: res.sent };
}

// Classify a webhook event into an outbox message (or null). Pure: easy to test.
export function classify(event, p) {
  const n = p.issue && p.issue.number;
  if (!n) return null;
  if (event === "issues" && (p.action === "closed" || p.action === "reopened")) {
    const why = p.issue.state_reason === "not_planned" ? " (not planned)" : "";
    return p.action === "closed"
      ? { issue: n, kind: "closed", status: "closed", subject: `Your WhatDwellsBelow report #${n} was closed${why}`, text: `Thanks for the report. Issue #${n} is now closed${why}.` }
      : { issue: n, kind: "reopened", status: "open", subject: `Your WhatDwellsBelow report #${n} was reopened`, text: `Issue #${n} was reopened.` };
  }
  if (event === "issue_comment" && p.action === "created" && p.comment) {
    if (!MAINTAINER.includes(p.comment.author_association)) return null;
    const body = String(p.comment.body || "").trim();
    if (/^\/quiet\b/i.test(body) || !body) return null;
    const ask = body.match(/^\/ask\s+([\s\S]+)/i);
    return ask
      ? { issue: n, kind: "ask", subject: `A question about your WhatDwellsBelow report #${n}`, text: `The developer asks:\n\n${ask[1].trim()}` }
      : { issue: n, kind: "update", subject: `Update on your WhatDwellsBelow report #${n}`, text: `New comment on your report:\n\n${body}` };
  }
  return null;
}

export async function githubWebhook(req, env) {
  if (!env.GH_WEBHOOK_SECRET) return err(503, "not_configured", "webhook secret missing");
  const raw = await req.arrayBuffer();
  if (raw.byteLength > 1_000_000) return err(413, "too_big", "payload too large");
  const sig = req.headers.get("X-Hub-Signature-256") || "";
  const want = "sha256=" + (await hmacHex(env.GH_WEBHOOK_SECRET, new Uint8Array(raw)));
  if (!safeEqual(sig, want)) return err(401, "bad_signature", "signature mismatch");
  const event = req.headers.get("X-GitHub-Event") || "";
  if (event === "ping") return json({ ok: true, pong: true });
  const delivery = req.headers.get("X-GitHub-Delivery") || "";
  if (delivery) {
    const ins = await env.DB.prepare("INSERT OR IGNORE INTO hooks (delivery_id, created) VALUES (?1, ?2)").bind(delivery, now()).run();
    if (ins.meta && ins.meta.changes === 0) return json({ ok: true, duplicate: true });
  }
  let p;
  try { p = JSON.parse(new TextDecoder().decode(raw)); } catch { return err(400, "bad_json", "payload not JSON"); }
  if (p.repository && p.repository.full_name && p.repository.full_name.toLowerCase() !== env.REPO.toLowerCase()) return json({ ok: true, ignored: "other_repo" });
  const msg = classify(event, p);
  if (!msg) return json({ ok: true, ignored: "event" });
  const rep = await env.DB.prepare(
    "SELECT r.reporter_code, r.email, r.opt_in, r.unsub_at FROM reports x JOIN reporters r ON r.reporter_code = x.reporter_code WHERE x.issue_number = ?1"
  ).bind(msg.issue).first();
  if (!rep) return json({ ok: true, ignored: "not_a_relay_issue" });
  if (msg.status) await env.DB.prepare("UPDATE reports SET status=?1 WHERE issue_number=?2").bind(msg.status, msg.issue).run();
  if (!rep.email || !rep.opt_in || rep.unsub_at) return json({ ok: true, queued: false, reason: "no_opt_in" });
  const origin = new URL(req.url).origin;
  return json({ ok: true, kind: msg.kind, ...(await queue(env, origin, rep, msg.issue, msg.kind, msg.subject, msg.text)) });
}

export async function unsubscribe(req, env) {
  const u = new URL(req.url);
  const code = u.searchParams.get("r") || "", tok = u.searchParams.get("t") || "";
  const page = (status, text) => new Response(`<!doctype html><meta charset="utf-8"><title>WhatDwellsBelow</title><p>${text}</p>`, { status, headers: { "Content-Type": "text/html; charset=utf-8" } });
  if (!/^R-[0-9a-f]{4,8}$/.test(code) || !safeEqual(tok, await unsubToken(env, code))) return page(400, "That unsubscribe link is not valid.");
  await env.DB.prepare("UPDATE reporters SET opt_in=0, unsub_at=?1 WHERE reporter_code=?2").bind(now(), code).run();
  await env.DB.prepare("UPDATE outbox SET state='dropped' WHERE reporter_code=?1 AND state='queued'").bind(code).run();
  return page(200, "Done. You will not get more emails about your WhatDwellsBelow reports.");
}
