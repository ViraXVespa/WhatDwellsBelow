# WDB bug-report relay

Cloudflare Worker `wdb-bug-relay`; D1 holds private report/outbox state, KV screenshots. Selected provider: **Resend**, not Cloudflare Paid Email Sending. Application sender: `WDB Bug Reports <bugs@mail.viraxvespa.com>`; this is an outbound identity, not a receiving-inbox promise.

## Sending and credentials

The User authorized activation on 2026-11-07; configuration is `EMAIL_SEND="on"`. Only that exact flag enables sending. The domain-scoped key is Worker secret **`RESEND_API_KEY`** on **`wdb-bug-relay`**. Provision write-only through sanctioned setup; never put values in source, vars, fixtures or logs. Wrangler declares the secret name for generated types, not its value. No `send_email` binding or Workers Paid upgrade is needed.

Official `POST https://api.resend.com/emails` uses stable `Idempotency-Key: wdb-bug-relay/outbox/<id>`, plain text plus escaped HTML, an eight-second timeout and a bounded response. Successful JSON with a nonempty Resend `id` means acceptance, **not delivery**. Failures/timeouts/quota errors leave the row queued with private sanitized status. No automatic retry/drain exists; enabling cannot silently flush old rows. Resend idempotency retention is 24 hours. Existing ingress limits, webhook dedupe and opt-in/unsubscribe remain. The inherited outbox has no aggregate pending-row cap; no arbitrary cap or deletion was introduced.

## Live validation

Read outbox counts/last id before activation, deploy off, verify binding names/health, then use only the approved live test. The GitHub webhook derives its subject and appends issue/unsubscribe links; it cannot carry a footer-free test unchanged. No public arbitrary-mail endpoint exists. Public test issues/comments and resulting messages require explicit approval. Closing an opted-in test issue triggers another email; do not clean it up unasked.

Health shape checks are not upstream authorization proof. Private attempt records and single-row recovery: [outbox operations](outbox-ops.md). Apply the additive migration before deploying the diagnostic dispatcher.

## Client contract

Managed workers.dev can reject library-default User-Agent headers with Cloudflare Error 1010 before the Worker runs. Official guidance is a truthful application identifier, not browser impersonation; the test uses `WDB-Relay-Integration-Test/0.10.9` on the same public route/network. No cookies, policy changes or alternate routes. The game sends JSON through HTTPRequest; `/report` requires no Origin header or application auth. Managed-zone blocks do not appear in this account's Worker logs/security events.

Reference: https://developers.cloudflare.com/support/troubleshooting/http-status-codes/cloudflare-1xxx-errors/error-1010/

## Deployment and tests

JSON-compatible `wrangler.jsonc` owns bindings/vars for Wrangler and `deploy-payload.mjs`. Both payload modes retain existing `secret_text`, including independently provisioned Resend keys, while upserting supplied named secrets. Even `--with-secrets` preserves `GITHUB_TOKEN`; only explicit `--rotate-github-token` replaces it from `WDB_ISSUES_TOKEN`. Importing the builder reads no credentials. Never use real secrets mode as a test.

Run `npm test`, `npm run typecheck`, `npm run dry-run` here: mocked requests and upload-free compilation, not delivery proof. Both payload modes have temporary fake-secret tests. `node deploy-payload.mjs` generates the normal connector payload without reading secrets.

API: https://resend.com/docs/api-reference/emails/send-email
Idempotency: https://resend.com/docs/dashboard/emails/idempotency-keys
