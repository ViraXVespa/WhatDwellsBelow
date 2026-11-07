# WDB bug-report relay

Cloudflare Worker `wdb-bug-relay`; report/GitHub webhook state stays in D1, screenshots in KV. Selected outbound provider: **Resend**, not Cloudflare Paid Email Sending. The verified application domain is `mail.viraxvespa.com`; the configured sender is `WDB Bug Reports <bugs@mail.viraxvespa.com>`. This is an outbound identity, not a promise that replies reach an inbox.

## Sending and readiness

The User authorized live activation on 2026-11-07; deployment configuration is now `EMAIL_SEND="on"`. The sender itself still fails closed unless the exact flag is on and the key is present. Only the exact value `"on"` enables future opted-in webhook notifications. Provision the restricted domain-scoped Resend key as Worker secret **`RESEND_API_KEY`** on **`wdb-bug-relay`** through the sanctioned write-only setup; never put it in source, vars, local fixtures or logs. `wrangler.jsonc` declares the required secret name for generated types, not its value. No Cloudflare `send_email` binding or paid Workers upgrade is needed.

The sender uses the official `POST https://api.resend.com/emails` HTTPS API, a stable `Idempotency-Key` (`wdb-bug-relay/outbox/<id>`), plain text plus escaped HTML, an eight-second timeout and a bounded acceptance response. Only successful JSON with a nonempty Resend `id` means provider acceptance, **not delivery**. Failures, timeouts and quota errors leave the row queued and expose no provider details. There is no automatic retry/drain, so enabling cannot silently flush old rows; idempotency retention at Resend is 24 hours. Existing report ingress limits, webhook delivery dedupe and opt-in/unsubscribe handling remain. The inherited outbox has no aggregate pending-row cap; this patch does not invent one or delete old records.

Before live activation, read state counts and last outbox id without reading message contents, deploy off, verify required binding names and health, then use only a separately approved exact test. The normal GitHub webhook derives its own subject and appends issue/unsubscribe links: it **cannot carry a footer-free arbitrary test unchanged**. Do not send a transformed test or substitute a direct provider call for proving the deployed relay. No public arbitrary-mail endpoint is provided here.

## Configuration, deployment and tests

`wrangler.jsonc` is JSON-compatible and owns bindings/vars for both Wrangler and `deploy-payload.mjs`. The payload always retains existing `secret_text` bindings, including independently provisioned `RESEND_API_KEY`, even when `--with-secrets` upserts named legacy secrets. Importing the metadata builder never reads credentials or writes a payload. Never inspect real credential files as tests. Both payload modes are tested using temporary fake credentials only.

From this directory: `npm test`, `npm run typecheck`, `npm run dry-run`. These use mocked provider requests and upload-free compilation; they neither send mail nor prove live delivery. `node deploy-payload.mjs` creates the normal connector payload without reading secrets. Deployment, enablement and the exact single approved live test are separately tracked; this source update alone does not claim any of them happened.

Official API: https://resend.com/docs/api-reference/emails/send-email ; idempotency: https://resend.com/docs/dashboard/emails/idempotency-keys .
