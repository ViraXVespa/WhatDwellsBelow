// Private existing-row dispatch. No HTTP entry point, backlog scan or implicit retries.
import { now } from "./util.js";
import { sendEmail } from "./email.js";

export async function dispatchOutbox(env, id, retry = false) {
  if (!Number.isSafeInteger(id) || id < 1) return { sent: false };
  const row = await env.DB.prepare("SELECT * FROM outbox WHERE id=?1").bind(id).first();
  if (!row || row.state !== "queued") return { sent: false };
  // Provider idempotency expires after 24h; never automatically risk a duplicate beyond it.
  if (retry && now() - row.created >= 86400) {
    await env.DB.prepare("UPDATE outbox SET last_stage='preflight',last_error='retry_window_expired' WHERE id=?1 AND state='queued'").bind(id).run();
    return { sent: false };
  }
  const rep = await env.DB.prepare("SELECT email,opt_in,unsub_at FROM reporters WHERE reporter_code=?1").bind(row.reporter_code).first();
  if (!rep?.email || !rep.opt_in || rep.unsub_at) return { sent: false };
  const claim = await env.DB.prepare(`UPDATE outbox SET state='sending',attempt_count=attempt_count+1,
    last_attempt_at=?1,last_stage='started',last_error=NULL,last_http_status=NULL
    WHERE id=?2 AND state='queued' AND EXISTS(SELECT 1 FROM reporters WHERE reporter_code=outbox.reporter_code AND opt_in=1 AND unsub_at IS NULL)
    RETURNING id`).bind(now(), id).first();
  if (!claim) return { sent: false };
  const result = await sendEmail({ ...env, EMAIL_FROM: row.sender }, rep.email, row.subject, row.body, `wdb-bug-relay/outbox/${id}`);
  await env.DB.prepare(`UPDATE outbox SET state=?1,sent_at=?2,last_stage=?3,last_error=?4,
    last_http_status=?5,provider_id=?6 WHERE id=?7 AND state='sending'`)
    .bind(result.sent ? "sent" : "queued", result.sent ? now() : null, result.stage || "preflight",
      result.reason || null, result.httpStatus ?? null, result.providerId || null, id).run();
  return { sent: result.sent };
}

export async function retryAuthorizedOutbox(env) {
  // One singleton permit, not a queue drain. Consume before even eligibility checks.
  const permit = await env.DB.prepare(`UPDATE outbox_retry SET armed=0,consumed_at=?1
    WHERE slot=1 AND armed=1 RETURNING outbox_id`).bind(now()).first();
  if (!permit) return;
  await dispatchOutbox(env, permit.outbox_id, true);
}
