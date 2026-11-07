// @ts-check
import { normEmail } from "./report.js";

/**
 * One bounded Resend attempt. Acceptance is not proof of delivery; failures stay queued.
 * @param {Pick<Env, "RESEND_API_KEY" | "EMAIL_SEND" | "EMAIL_FROM">} env
 * @param {string} to
 * @param {string} subject
 * @param {string} body
 * @param {string} idempotencyKey Stable outbox identity; never an address or fresh retry UUID.
 * @param {typeof fetch} request
 */
export async function sendEmail(env, to, subject, body, idempotencyKey, request = fetch) {
  if (env.EMAIL_SEND !== "on") return { sent: false, reason: "email_send_off" };
  if (!env.RESEND_API_KEY?.trim()) return { sent: false, reason: "email_key_missing" };
  if (!idempotencyKey || idempotencyKey.length > 256 || /[\r\n]/.test(idempotencyKey))
    return { sent: false, reason: "email_idempotency_missing" };
  const from = env.EMAIL_FROM?.trim();
  let recipient;
  try {
    const mailbox = from?.match(/^[^<>\r\n]+<([^<>\r\n]+)>$/)?.[1] || from;
    if (!from || /[\r\n]/.test(from) || !normEmail(mailbox)) return { sent: false, reason: "email_address_missing" };
    recipient = normEmail(to);
    if (/[\s<>,;]/.test(mailbox || "") || /[<>,;]/.test(recipient || "")) return { sent: false, reason: "email_address_invalid" };
  } catch { return { sent: false, reason: "email_address_invalid" }; }
  if (!recipient) return { sent: false, reason: "email_address_missing" };
  const escaped = body.replaceAll("&", "&amp;").replaceAll("<", "&lt;").replaceAll(">", "&gt;")
    .replaceAll('"', "&quot;").replaceAll("'", "&#39;");
  try {
    const response = await request("https://api.resend.com/emails", {
      method: "POST", redirect: "error", signal: AbortSignal.timeout(8000),
      headers: { Authorization: `Bearer ${env.RESEND_API_KEY}`, "Content-Type": "application/json", "Idempotency-Key": idempotencyKey },
      body: JSON.stringify({ from, to: recipient, subject, text: body, html: `<pre>${escaped}</pre>` }),
    });
    if (!response.ok) {
      await response.body?.cancel(); // Provider errors may contain addresses; do not log or expose them.
      return { sent: false, reason: "email_send_failed" };
    }
    if (!response.body) return { sent: false, reason: "email_not_accepted" };
    const reader = response.body.getReader();
    const decoder = new TextDecoder();
    let json = "", size = 0;
    try {
      while (true) {
        const { done, value } = await reader.read();
        if (done) break;
        size += value.byteLength;
        if (size > 4096) { await reader.cancel(); return { sent: false, reason: "email_not_accepted" }; }
        json += decoder.decode(value, { stream: true });
      }
      json += decoder.decode();
    } finally { reader.releaseLock(); }
    const accepted = JSON.parse(json);
    return typeof accepted?.id === "string" && accepted.id.trim()
      ? { sent: true, providerId: accepted.id } : { sent: false, reason: "email_not_accepted" };
  } catch { return { sent: false, reason: "email_send_failed" }; }
}
