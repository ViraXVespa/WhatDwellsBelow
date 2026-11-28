# App flow (door)

Status: current plan  
Read when: App singleton, scene swaps, launch arguments  
Code: `scripts/app.gd` (the `App` autoload facade) + `scripts/app/`, `scripts/boot.gd`, `scripts/title.gd` + `scripts/title/`, `scripts/data/bug_doors.gd`, `scripts/world/foundation.gd` (the combat sandbox / smoke host scene) (code map row App flow; gdhealth group `app_flow`)

| Job | Open |
|-----|------|
| startup order, Dbg shim, wdb flags | `design/app-flow-boot.md` |
| loader handoff, descent, next floor, expedition ending | `design/app-flow-legs.md` |
| relay upload, crash marker, install id, state report | `design/app-flow-bug-report.md` |

The title menu card and its news overlay are the ui title_web job; the Report Bug page layout is the ui pause job; the camp entry events table belongs to hub.

## Rules for every job

- `App` is the top of the game: it may call any system, and no system reaches into `scripts/app/` helpers. Others call `App.*` (`App.sfx`, `App.go_camp`, `App.end_run`, ...).
- Two files here are shared shims any code may preload: `scripts/app/cli_args.gd` (`CliArgs`, launch and `?wdb-` URL args) and `scripts/app/dbg.gd` (`Dbg`, the only way live code reaches `scripts/debug/`). Neither preloads anything above it.
- `app.gd` holds state and one-line delegates. Bodies live in a helper by cluster: `app_boot` (start-up, input), `app_set` (settings), `app_flow` + `flow_hub` + `flow_leg` (scene legs), `app_run` (run state), `app_bake` (editor hub bake).
- Live code never preloads `scripts/debug/`; it asks `Dbg.script(name)` / `Dbg.make(name)`, which return null in a release build.
