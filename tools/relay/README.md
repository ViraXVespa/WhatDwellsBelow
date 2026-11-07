# Bug relay email prep

The live relay remains **free-tier-only**. This checkout prepares, but does not deploy or enable, the optional Cloudflare sender. Reports/webhooks still work with email disabled and outbox mail stays queued.

## Deployment blockers — not permission to enable

Cloudflare Email Sending beta requires **Workers Paid for arbitrary recipients**. Free Workers can send only to account-verified Email Routing destinations; arbitrary opted-in bug reporters are not those destinations. Thus this prepared integration cannot fulfil reporter mail under the existing free-only decision. No plan upgrade, provider change, domain onboarding, deployment or sending is authorized by these files. Keep `EMAIL_SEND="off"`, `EMAIL_FROM=""` until the owner resolves the plan/provider decision and explicitly approves activation.

The parent separately handles domain/service verification. Authentication failure alone does not prove its cause. A verified domain, a confirmed sender and an enabled/authorized service are still prerequisites; do not route around an authentication failure. Player replies are not implemented.

If this optional sender is later approved: set `EMAIL_FROM` to the chosen verified address and `send_email[0].allowed_sender_addresses` to exactly that address. Keep email off through validation; only a separately approved activation uses the exact string `"on"` (not `1`). No recipient or sender has been chosen here. `remote:false` keeps local development from using real sending.

## Contract and checks

`wrangler.jsonc` (JSON-compatible) owns binding/var configuration for both Wrangler and `deploy-payload.mjs`. The generator retains existing secrets by default; importing its metadata builder neither reads secrets nor generates a deploy payload. Do not run its secrets mode as a test.

`src/email.js` calls the structured `env.EMAIL.send({from,to,subject,text,html})` API. HTML is escaped, plain text and unsubscribe remain, and only a nonempty `messageId` marks the outbox sent. Missing configuration, rejection or malformed acceptance leaves mail queued; raw provider errors/addresses are not logged or returned. No background retry/drain was added.

From `tools/relay`: `npm ci`, `npm test`, `npm run typecheck`, `npm run dry-run` (compile only, no upload). Type checking covers the new sender against Wrangler-generated config/runtime types, not a wholesale typing of legacy relay JavaScript. Node tests use fake D1/provider and a fully mocked upload request; no mail, issue or deploy is sent. Generated types and local runtime state are ignored. Existing compatibility date is retained; no unrelated runtime upgrade. Missing production logs/traces remain an existing review finding, not changed here.

Official sources checked 2026-11-07: [Workers API](https://developers.cloudflare.com/email-service/api/send-emails/workers-api/), [bindings](https://developers.cloudflare.com/email-service/configuration/send-bindings/), [plan limits](https://developers.cloudflare.com/email-service/). Installed Wrangler schema/types validate the supported API, not account entitlement or successful delivery.
