# In-game bug reports via pause menu and a GitHub issue relay

id: bug-report-relay
owner: web
status: open
done-when: Pause-menu Report Bug opens a GitHub issue on ViraXVespa/WhatDwellsBelow through the relay (no player GitHub account, no token in any build), with rate limit and spam filter live.
resume: Vira names this task in a web session, which reads this file whole.

**Do not start** until Vira gives the go-ahead and sets up her Cloudflare account (see Gate). `blocked`/`needs:` take task ids only, so the gate lives here.

## Intent
Players report bugs from inside the game without a GitHub account. Logged 2026-10-24 to set up later; no code yet.

## Shape (as asked)
- Pause menu gains a **Report Bug** entry (description box, optional screenshot, send).
- The game posts to a small relay: a Cloudflare Worker on Vira's account (free tier). The Worker holds a fine-grained GitHub token limited to creating issues on `ViraXVespa/WhatDwellsBelow` and opens the issue.
- The game never ships the token (web build included); it only knows the relay URL.
- Payload: game version, platform, scene, recent log lines, optional screenshot, player description.
- The endpoint is public: the relay does per-player rate limiting and basic spam filtering before opening an issue.

## Gate
New player-facing system plus a pause-menu change: needs Vira's go-ahead, and her Cloudflare account for the Worker and its secret, before any work starts.

## Open questions (Vira's)
- Screenshot hosting (issue attachment vs. Worker storage) and largest allowed upload; what counts as a "player" for rate limits (install id vs. IP).
- Labels on created issues; whether log lines need scrubbing before upload.
- Which builds show the entry (web, desktop, both).

## Likely paths
Source: `scripts/ui/pause_menu/` (`menu_flow.gd`, `pause_menu_view.gd`), `scripts/debug/hitch_log/` (recent log lines). Docs: `design/ui-pause.md`, `design/versioning.md`.

## Proves it
A report sent from the web build and a desktop build opens one labelled issue with every payload field; a burst past the limit is refused by the relay; the shipped export contains no token.
