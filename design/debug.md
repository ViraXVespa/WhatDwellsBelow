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

Hitch log is `scripts/debug/hitch_log.gd`. On editor, desktop, and localhost web it is on by default. GitHub Pages does not hook it. A frame at least four times the 60 FPS budget appends one JSONL line to `user://hitch/hitch.jsonl`. Newest 256 hitch rows are kept. Session and hitch rows stamp `ver` from `scripts/data/version.json`. Debug chrome can copy or clear the file. On localhost web each row is also POSTed (fire-and-forget) to `/_wdb/hitch`; `tools/perf.py hitch` and `perf.py web` append it to `_logs/web-perf/hitch.jsonl`. Not part of the playtest journal. To log smaller frames in a normal localhost web session, serve a `Web Debug` export with `perf.py hitch` and open `index.html?wdb-hitch-mult=1` (URL args reach `CliArgs`; `HitchLog.begin` reads `--wdb-hitch-mult`). The 256-row cap stays, and outside the bench each row is its own POST.

## Release vs debug builds

Release and web presets (`Web`, `release.py export-web`) exclude `scripts/debug/*` from the PCK; `Web Debug` (`release.py export-web --debug --out DIR`) and the editor binary keep it. Shared code never preloads `scripts/debug/`: it calls `scripts/app/dbg.gd` (`Dbg`), whose `on()` is `OS.has_feature("debug")` and the folder present and no `--wdb-release`. Off, every `Dbg.*` call is a no-op and `App.debug` / `App.playtest` / `App.anim_browser` stay null. `cli_args.gd` and `telemetry.gd` (recap reads it) live in `scripts/app/` and ship. New instrumentation is born in `scripts/debug/` behind `Dbg`.

Always on in a debug build: hitch log (not on Pages), debug menu and its input chord, the smoke/scenario router check at boot, the idle playtester node (does nothing until a run starts).
Opt-in per scenario: phase smokes (`--wdb-phaseN-smoke`), load/open timing (`--wdb-*-timing`), hub bench (`--wdb-hub-bench`), shot tool and flows, playtest runs and journal (`--wdb-pt-*`, debug menu), web hook (`?wdb-playtest`), anim browser (built on first open), dungeon map dump.

`gate.py release` proves release: title to hub to dungeon with `--wdb-release` and with the folder deleted, no debug node, no script error; `--pck DIR` / `--pck-debug DIR` check an export's PCK. `web_perf` hitch rows and `wdb-playtest` flows need the debug export.
