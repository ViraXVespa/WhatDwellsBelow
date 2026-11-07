// @ts-check
import { normEmail } from "./report.js";

// Domain verification and a chosen EMAIL_FROM are deployment prerequisites, not bypassed here.
// The binding uses the current structured Workers API, not the legacy raw EmailMessage API.
/**
 * @param {Pick<Env, "EMAIL" | "EMAIL_SEND" | "EMAIL_FROM">} env
 * @param {string} to
 * @param {string} subject
 * @param {string} body
 */
export async function sendEmail(env, to, subject, body) {
  if (env.EMAIL_SEND !== "on") return { sent: false, reason: "email_send_off" };
  if (!env.EMAIL || typeof env.EMAIL.send !== "function") return { sent: false, reason: "email_binding_missing" };
  let from, recipient;
  try { from = normEmail(env.EMAIL_FROM); recipient = normEmail(to); }
  catch { return { sent: false, reason: "email_address_invalid" }; }
  if (!from || !recipient) return { sent: false, reason: "email_address_missing" };
  // Maintainer comments are untrusted HTML. Preserve the plain-text unsubscribe link too.
  const escaped = body.replaceAll("&", "&amp;").replaceAll("<", "&lt;").replaceAll(">", "&gt;")
    .replaceAll('"', "&quot;").replaceAll("'", "&#39;");
  try {
    const accepted = await env.EMAIL.send({ from, to: recipient, subject, text: body, html: `<pre>${escaped}</pre>` });
    return typeof accepted?.messageId === "string" && accepted.messageId.trim()
      ? { sent: true } : { sent: false, reason: "email_not_accepted" };
  } catch {
    // Provider messages may contain addresses or message content: never log or return them.
    return { sent: false, reason: "email_send_failed" };
  }
}
