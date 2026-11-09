# WDB bug-report relay

Cloudflare Worker `wdb-bug-relay`; D1 holds private report/outbox state, KV screenshots. Selected provider: **Resend**, not Cloudflare Paid Email Sending. Application sender: `WDB Bug Reports <bugs@mail.viraxvespa.com>`; this is an outbound identity, not a receiving-inbox promise.

## Reports and the game side

Players report from Pause > Settings > **Report Bug** in every build (web, desktop; release and debug) with no GitHub account; the game ships only the relay URL, never a token. Issues on `ViraXVespa/WhatDwellsBelow` carry a reporter code `R-xxxx`, never the email (that stays private in D1 with the opt-in), and labels `bug-report`, `door:<door>`, `job:<door>.<job>` (`triage` when no door), `build:<release|debug|dev>`, `platform:<...>`, `crash`. Log lines ride only with a crash; otherwise the game sends its own state report.

`POST /report` JSON: `install_id`, `description` (10-4000), `category` ("" / door / door.job), `title`? (80), `email`?, `opt_in`?, `crash`?, `log`? (crash only, last 16KB), `screenshot`? (base64, 1.5MB), `state` (version, platform, build, scene, floor, seed, pos, loadout, recent, perf, settings, run, uptime_s; others dropped), `dry_run`? (returns the would-be issue, stores nothing). Limits: 10/h and 30/day per IP, 5/h and 15/day per install, 300 issues/day; link, repetition and spam-word filter; the same text from one install within 24h is refused. Also `GET /health`, `GET /shot/<key>`, `POST /github-webhook` (HMAC; maintainer comments and close/reopen queue mail for opted-in reporters), `GET|POST /unsubscribe`.

Game page (`scripts/ui/pause_settings/report_page.gd`, pad-first): an optional one-line Summary (the issue `title`), then Door and Job comboboxes (`report_pick.gd`, OptionButton popups walked with the pad). Door first; Job lists that door's jobs and stays disabled and out of the pad ring until a door is picked, and a new door resets it. No door sends category "" (triage), a door alone sends the door. The line under the pickers shows the highlighted or selected door/job description. Then What happened (cycles on A, the title when there is no summary), optional Details and Email (Backspace deletes: it is also `ui_cancel`, `guard_backspace`), Email me, Attach a screenshot, Send Report. Typed keys stay in the field (`menu_pad.typing`). Client: `scripts/app/bug_report/` (`bug_send.gd` payload and POST, `bug_state.gd` state report, `crash_mark.gd` crash log).

Doors and jobs: `node gen-doors.mjs` writes `src/doors.js` (relay check), `scripts/data/bug_doors.gd` (game check) and `scripts/data/bug_doors.json` (picker names = each doc's H1, descriptions = the door's routes.yaml `read_when` and each job doc's "Read when:") from `design/routes.yaml`; run it after a door/job/doc-header change (`--check`, and `npm test` fails when stale). A new door or job changes `src/doors.js`, so redeploy. Smoke P1 `bug_report_ok` (`scripts/debug/smoke/bug_report_check.gd`); shots `camp-pause-pages` `settings-report*`.

Proof (closed 2026-11-09): desktop live reports [#81](https://github.com/ViraXVespa/WhatDwellsBelow/issues/81) and [#82](https://github.com/ViraXVespa/WhatDwellsBelow/issues/82) from a Windows dev build; web dry run only, and Vira accepted the desktop proof on 2026-11-09 (no live web send required). Live Resend delivery verified 2026-11-07 (#78).

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
