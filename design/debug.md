# Debug tools (door)

Status: current plan  
Read when: secret console, playtest, journal, smoke
Code: `scripts/debug/` (menu helpers in `scripts/debug/debug_menu/`)

| Job | Open |
|-----|------|
| balance sliders, profile banks | `design/debug-menu.md` |
| sim walker, recommended config | `design/debug-playtest.md` |
| timeline scrubber, review queue | `design/debug-anim-browser.md` |
| phase assertions, runner summary | `design/debug-smokes.md` |

When running smokes, use the listed runner and read only that runner's `_logs` summary.

Hitch log is `scripts/debug/hitch_log.gd`. On editor, desktop, and localhost web it is on by default. GitHub Pages does not hook it. A frame at least four times the 60 FPS budget appends one JSONL line to `user://hitch/hitch.jsonl`. Newest 256 hitch rows are kept. Session and hitch rows stamp `ver` from `scripts/data/version.json`. Debug chrome can copy or clear the file. Not part of the playtest journal.
