# In-game bug reports via pause menu and a GitHub issue relay

id: bug-report-relay
owner: web
status: active
done-when: Pause-menu Report Bug opens a GitHub issue on ViraXVespa/WhatDwellsBelow through the relay (no player GitHub account, no token in any build), with rate limit and spam filter live.
resume: Vira names this task in a web session, which reads this file whole.

Vira approved 2026-10-25 (t601u). Server side is live; game side built (2026-10-25). Desktop live UI proven 2026-11-09 (#81, #82); a live web-build send remains.

## Decisions (Vira, 2026-10-25)
- Report Bug shows in **all** builds (web, desktop; release and debug).
- Identity: optional player email plus an "email me updates" opt-in. The email never appears in any public record (issue, comment, log); issues carry a reporter code `R-xxxx`.
- No log lines unless the report is a crash (`crash: true`); otherwise the game sends its own state report. No other user data.
- Labels: `bug-report`, `door:<door>` and `job:<door>.<job>` from `design/routes.yaml` doors (`triage` when unset), `build:<release|debug|dev>`, `platform:<windows|linux|macos|web|android|ios>`, `crash`.
- GitHub issues are public, so private data (emails, opt-in, outbound mail) lives in Cloudflare D1, not GitHub.

## Relay (live)
Worker `wdb-bug-relay` at `https://wdb-bug-relay.viraxvespa.workers.dev` on Vira's Cloudflare account, free tier only. Source and tests: `tools/relay/` (`npm test`; `node tools/relay/gen-doors.mjs` after a door/job change, a test fails when stale; redeploy via `node tools/relay/deploy-payload.mjs` and the Cloudflare connector). D1 `wdb-bug-relay` (tables in `tools/relay/schema.sql`); KV `wdb-bug-relay-shots` holds screenshots (R2 needs dashboard enabling, so not used). Secrets: `GITHUB_TOKEN`, `GH_WEBHOOK_SECRET`, `RELAY_SALT`, plus selected-provider `RESEND_API_KEY`; activation var `EMAIL_SEND=on`. Deployments preserve installed secrets; `--with-secrets` does not rotate `GITHUB_TOKEN` unless explicitly requested. Never publish credentials or copy them into game builds. JavaScript is the one exception to the every-tool-is-Python rule (`tools.md` rule 2).

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
- **Desktop UI proof:** done 2026-11-09. Vira sent live in-game reports from a Windows dev build (`0.11.0 @cffcfb69`) through Pause > Settings > Report Bug: [#81](https://github.com/ViraXVespa/WhatDwellsBelow/issues/81) and [#82](https://github.com/ViraXVespa/WhatDwellsBelow/issues/82), each labelled `bug-report, door:dungeon, build:dev, platform:windows`, with screenshot and state report and no email in the issue.
- **Web proof:** dry run only (2026-10-31: `release.py export-web --debug --out DIR`, then `perf.py web --site DIR --flow bug-dry` returned 200 with labels `bug-report, door:triage, build:debug, platform:web`, email `none`; no GitHub token string in the export). A live web-build submission is the one item "Proves it" still lacks. It is Vira's to send; the Bot does not create reports.
- **Email sending:** live Resend delivery verified 2026-11-07 for [#78](https://github.com/ViraXVespa/WhatDwellsBelow/issues/78) (provider delivery, not inbox placement). See `tools/relay/README.md`. Player replies to `/ask` are a separate, unimplemented capability.
- **Abuse protection:** rate limits and spam filter live; mocked tests cover refusal. No live burst test is required.
- **Webhook:** live (id 703111592, issues + issue_comment, ping 200).
- **Backspace in the email field:** fixed 2026-11-09 (`report_page.gd` `guard_backspace`; Backspace is also `ui_cancel`, which LineEdit checked first). P1 `bug_report_ok` now covers it.
- **Vira's follow-ups (notes/wdb_todo_list.txt, not started):** Area as a combobox instead of a click toggle; separate door and job pickers with descriptions pulled from the design docs, ideally auto-populated; a summary input above the selector. These are new UI, for Build.

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
An actual Report Bug submission from the web build and a desktop build opens a labelled issue with the approved payload; automated tests retain rate-limit/spam refusal coverage; the shipped export contains no token. Record actual UI evidence separately from dry runs and provider-delivery evidence. Do not close this task on email delivery alone.
