# Debug tools (door)

Status: current plan  
Read when: secret console, playtest, journal, smoke
Code: `scripts/debug/` (code map row Debug; gdhealth group `debug`); live code reaches it only through `scripts/app/dbg.gd` (`Dbg`)

| Job | Open |
|-----|------|
| balance sliders, profile banks | `design/debug-menu.md` |
| sim walker, recommended config | `design/debug-playtest.md` |
| scored legs, continuous sweep | `design/debug-bench.md` |
| timeline scrubber, review queue | `design/debug-anim-browser.md` |
| phase assertions, runner summary | `design/debug-smokes.md` |
| spike jsonl, localhost | `design/debug-hitch.md` |
| generation dump, ascii seal fixtures | `design/debug-dungeon-map.md` |
| planted faults, unit probes | `design/debug-shot-checks.md` |

When running smokes, use the listed runner and read only that runner's `_logs` summary.

Reach-in rule: nothing live loads `scripts/debug/` (gdhealth: every group -> `debug` is critical; a new group gets the same rule). Drivers (smoke phases, playtest, benches, shot tool) call system facades or duck-typed methods on live nodes where one exists. Check scripts (`*_check.gd`, `debug.shot_checks`, the `debug.dungeon_map` specs) are white-box tests: they may preload the helpers of the system they check. Shot tool code is `scripts/debug/shot_tool.gd` + `scripts/debug/shot_tool/` (gate `shot_tool`). Debug menu edits persist through `scripts/debug/tunable_overrides.gd` (`debug.menu`; shared code reaches it via `Dbg.script("tunable_overrides")`).

## Release vs debug builds

Release and web presets (`Web`, `release.py export-web`) exclude `scripts/debug/*` and `addons/*` from the PCK; `Web Debug` (`release.py export-web --debug --out DIR`) and the editor binary keep both. Shared code never preloads `scripts/debug/`: it calls `scripts/app/dbg.gd` (`Dbg`), whose `on()` is `OS.has_feature("debug")` and the folder present and no `--wdb-release`. Off, every `Dbg.*` call is a no-op and `App.debug` / `App.playtest` / `App.anim_browser` stay null. `cli_args.gd` and `telemetry.gd` (recap reads it) live in `scripts/app/` and ship. New instrumentation is born in `scripts/debug/` behind `Dbg`.

Always on in a debug build: hitch log (not on Pages), debug menu and its input chord, the smoke/scenario router check at boot, the idle playtester node (does nothing until a run starts).
Opt-in per scenario: phase smokes (`--wdb-phaseN-smoke`), load/open timing (`--wdb-*-timing`), hub bench (`--wdb-hub-bench`), dungeon bench (`--wdb-dungeon-bench`), shot tool and flows, playtest runs and journal (`--wdb-pt-*`, debug menu), web hook (`?wdb-playtest`), anim browser (built on first open), dungeon map dump.

`gate.py release` proves release: title to hub to dungeon with `--wdb-release` and with the folder deleted, no debug node, no script error; `--pck DIR` / `--pck-debug DIR` check an export's PCK (`--pck` also refuses `addons/` paths). `web_perf` hitch rows and `wdb-playtest` flows need the debug export.

`--mcp` flag enables the Godot AI game-helper autoload (editor/debug only; never on normal or web launches). The release Web preset also excludes `addons/*`. A debug Web export may still pack the addon, but the helper only talks over the editor-debugger channel, so it is idle in the browser.