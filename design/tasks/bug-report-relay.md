# In-game bug reports via pause menu and a GitHub issue relay

id: bug-report-relay
owner: web
status: active
done-when: Pause-menu Report Bug opens a GitHub issue on ViraXVespa/WhatDwellsBelow through the relay (no player GitHub account, no token in any build), with rate limit and spam filter live.
resume: Vira names this task in a web session, which reads this file whole.

Vira approved 2026-10-25 (t601u). Server side is live; game side built (2026-10-25), waiting on a web-export send.

## Decisions (Vira, 2026-10-25)
- Report Bug shows in **all** builds (web, desktop; release and debug).
- Identity: optional player email plus an "email me updates" opt-in. The email never appears in any public record (issue, comment, log); issues carry a reporter code `R-xxxx`.
- No log lines unless the report is a crash (`crash: true`); otherwise the game sends its own state report. No other user data.
- Labels: `bug-report`, `door:<door>` and `job:<door>.<job>` from `design/routes.yaml` doors (`triage` when unset), `build:<release|debug|dev>`, `platform:<windows|linux|macos|web|android|ios>`, `crash`.
- GitHub issues are public, so private data (emails, opt-in, outbound mail) lives in Cloudflare D1, not GitHub.

## Relay (live)
Worker `wdb-bug-relay` at `https://wdb-bug-relay.viraxvespa.workers.dev` on Vira's Cloudflare account, free tier only. Source and tests: `tools/relay/` (`npm test`; `node tools/relay/gen-doors.mjs` after a door/job change, a test fails when stale; redeploy via `node tools/relay/deploy-payload.mjs` and the Cloudflare connector). D1 `wdb-bug-relay` (tables in `tools/relay/schema.sql`); KV `wdb-bug-relay-shots` holds screenshots (R2 needs dashboard enabling, so not used). Secrets: `GITHUB_TOKEN`, `GH_WEBHOOK_SECRET`, `RELAY_SALT`; var `EMAIL_SEND=off`. Local copies live in git-ignored `tools/relay/.secrets/` (the first deploy kept them in the `bot/bug-relay` worktree root; move them before a `--with-secrets` redeploy). JavaScript is the one exception to the every-tool-is-Python rule (`tools.md` rule 2).

| Endpoint | Does |
|---|---|
| `GET /health` | config flags, no secrets |
| `POST /report` | JSON: `install_id`, `description` (10-4000), `category` (door or door.job), `title`?, `email`?, `opt_in`?, `crash`?, `log`? (crash only, last 16KB), `screenshot`? (base64 png/jpeg/webp, 1.5MB), `state` (keys: version, platform, build, scene, floor, seed, pos, loadout, recent, perf, settings, run, uptime_s; others dropped), `dry_run`? (returns the would-be issue, stores nothing). Limits: 10/h and 30/day per IP, 5/h and 15/day per install, 300 issues/day total; link, repetition and spam-word filter; same text from one install within 24h is refused. Anything email-shaped is scrubbed from public text; `@` mentions are defanged. |
| `GET /shot/<key>` | screenshot by unguessable key (365-day TTL) |
| `POST /github-webhook` | HMAC-verified. Maintainer comment queues an update, `/ask <text>` a question, `/quiet` nothing; close/reopen queue a note. Only for opted-in reporters; messages wait in D1 `outbox`. |
| `GET\|POST /unsubscribe?r=&t=` | signed link in every email; turns opt-in off and drops queued mail |

## Game side (built)
- Pause > Settings > **Report Bug** page, every build (`scripts/ui/pause_settings/report_page.gd`): Area and What happened cycle on A (a pad-only player can send without typing), optional Details and Email fields, "Email me about this report", Attach a screenshot (menu hidden for two frames, JPEG <=1280 px), Send Report. Typed keys go to the field, not the tab binds (`menu_pad.typing`).
- `scripts/app/bug_report/`: `bug_send.gd` (`RELAY_URL`, install id in `user://install_id.txt`, payload, HTTPRequest POST under App), `bug_state.gd` (state report, the relay's keys only: version label + week-open commit, platform, build, scene, floor, seed, pos, loadout, recent, perf, settings, run, uptime), `crash_mark.gd` (session marker; an unclean exit offers the scrubbed tail of the previous `user://logs` file; off on web and in smokes).
- Areas map to doors; `scripts/data/bug_doors.gd` is generated with `src/doors.js` by `gen-doors.mjs` (the relay test fails when either is stale). Smoke: P1 `bug_report_ok` (`scripts/debug/smoke/bug_report_check.gd`). Shots: `camp-pause-pages` `settings-report`, `settings-report-open`.
- Live dry run (stores nothing; counts toward the 10/h IP limit): a `--script` SceneTree that waits two frames, `load()`s `bug_send.gd` and calls `post(payload(form, "", true), cb)`; desktop 2026-10-25 returned 200 with labels `bug-report, door:ui, build:dev, platform:linux` and no email in the response.

## Left
- **Web proof:** send one dry run from a web export (HTTPRequest is fetch there; the relay sends CORS `*`).
- **Email sending:** Cloudflare Email Sending needs a domain Vira owns (GoDaddy domain, "decide later"; mail stays stored, unsent); then wire `sendEmail` in `tools/relay/src/hooks.js` and flip `EMAIL_SEND`. Player replies to `/ask` need the same domain.
- **Webhook:** live (id 703111592, issues + issue_comment, ping 200).

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
