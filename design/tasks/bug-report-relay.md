# In-game bug reports via pause menu and a GitHub issue relay

id: bug-report-relay
owner: web
status: active
done-when: Pause-menu Report Bug opens a GitHub issue on ViraXVespa/WhatDwellsBelow through the relay (no player GitHub account, no token in any build), with rate limit and spam filter live.
resume: Vira names this task in a web session, which reads this file whole.

Vira approved 2026-10-25 (t601u). Server side is live; game side not started.

## Decisions (Vira, 2026-10-25)
- Report Bug shows in **all** builds (web, desktop; release and debug).
- Identity: optional player email plus an "email me updates" opt-in. The email never appears in any public record (issue, comment, log); issues carry a reporter code `R-xxxx`.
- No log lines unless the report is a crash (`crash: true`); otherwise the game sends its own state report. No other user data.
- Labels: `bug-report`, `door:<door>` and `job:<door>.<job>` from `design/routes.yaml` doors (`triage` when unset), `build:<release|debug|dev>`, `platform:<windows|linux|macos|web|android|ios>`, `crash`.
- GitHub issues are public, so private data (emails, opt-in, outbound mail) lives in Cloudflare D1, not GitHub.

## Relay (live)
Worker `wdb-bug-relay` at `https://wdb-bug-relay.viraxvespa.workers.dev` on Vira's Cloudflare account, free tier only. Source and tests: `tools/relay/` (`npm test`; `node tools/relay/gen-doors.mjs` after a door/job change, a test fails when stale; redeploy via `node tools/relay/deploy-payload.mjs` and the Cloudflare connector). D1 `wdb-bug-relay` (tables in `tools/relay/schema.sql`); KV `wdb-bug-relay-shots` holds screenshots (R2 needs dashboard enabling, so not used). Secrets: `GITHUB_TOKEN`, `GH_WEBHOOK_SECRET`, `RELAY_SALT`; var `EMAIL_SEND=off`.

| Endpoint | Does |
|---|---|
| `GET /health` | config flags, no secrets |
| `POST /report` | JSON: `install_id`, `description` (10-4000), `category` (door or door.job), `title`?, `email`?, `opt_in`?, `crash`?, `log`? (crash only, last 16KB), `screenshot`? (base64 png/jpeg/webp, 1.5MB), `state` (keys: version, platform, build, scene, floor, seed, pos, loadout, recent, perf, settings, run, uptime_s; others dropped), `dry_run`? (returns the would-be issue, stores nothing). Limits: 10/h and 30/day per IP, 5/h and 15/day per install, 300 issues/day total; link, repetition and spam-word filter; same text from one install within 24h is refused. Anything email-shaped is scrubbed from public text; `@` mentions are defanged. |
| `GET /shot/<key>` | screenshot by unguessable key (365-day TTL) |
| `POST /github-webhook` | HMAC-verified. Maintainer comment queues an update, `/ask <text>` a question, `/quiet` nothing; close/reopen queue a note. Only for opted-in reporters; messages wait in D1 `outbox`. |
| `GET\|POST /unsubscribe?r=&t=` | signed link in every email; turns opt-in off and drops queued mail |

## Left
- **Game side** (needs Vira's go-ahead on layout): pause-menu Report Bug entry (description, category picker, optional email + opt-in, screenshot toggle), the state report builder, a stable `install_id` in `user://`, crash-log capture, relay URL constant. Prove with a dry run from web and desktop.
- **Email sending:** Cloudflare Email Sending needs a domain Vira owns; then wire `sendEmail` in `tools/relay/src/hooks.js` and flip `EMAIL_SEND`. Player replies to `/ask` need the same domain.
- **Webhook:** Vira adds it in repo Settings, Webhooks: URL `https://wdb-bug-relay.viraxvespa.workers.dev/github-webhook`, JSON, the secret handed over by the Bot, events Issues and Issue comments.

## Intent
Players report bugs from inside the game without a GitHub account. Logged 2026-10-24.

## Shape (as asked)
- Pause menu gains a **Report Bug** entry (description box, optional screenshot, send).
- The game posts to a small relay: a Cloudflare Worker on Vira's account (free tier). The Worker holds a fine-grained GitHub token limited to creating issues on `ViraXVespa/WhatDwellsBelow` and opens the issue.
- The game never ships the token (web build included); it only knows the relay URL.
- Payload: player description, optional email/screenshot, the game's own state report; log lines on crash only.
- The endpoint is public: the relay does per-player rate limiting and basic spam filtering before opening an issue.

## Likely paths
Source: `scripts/ui/pause_menu/` (`menu_flow.gd`, `pause_menu_view.gd`), crash-log capture must not live under `scripts/debug/` (release exports drop it). Docs: `design/ui-pause.md`, `design/versioning.md`.

## Proves it
A report sent from the web build and a desktop build opens one labelled issue with every payload field; a burst past the limit is refused by the relay; the shipped export contains no token.
