# Smoke tests (live snapshot)

Status: binding design
Read when: smoke phase coverage / how to run smokes
Code: scripts/debug/, scripts/combat/debug_menu paths may be under scripts/debug/debug_menu/
See also: `design/debug.md`, `design/debug-menu.md`, `design/debug-playtest.md`, `design/debug-anim-browser.md`, `design/pc-offload.md`, `design/refactor.md`, `design/doc-refactor.md`, `design/README.md`

## Live snapshot — smoke tests (`smoke.gd`)

Coverage runner, not a particle system. User args: `--wdb-phaseN-smoke` for N = 1..9 (after `--`). Prints on `printerr`, then quits. There are no live `smoke_*.tscn` scenes — phases attach from `boot` / foundation / dungeon / camp via `scripts/debug/smoke.gd`.

### How to run (Steam Godot / redirected IO)

Preferred (agent-friendly): from repo root, prefer `& .\tools\run_smokes.ps1 -Phases @(1,2,6)` (optional `-TimeoutSec 180`, `-VerboseGodot`). Avoid `powershell -File tools/run_smokes.ps1 -Phases 1,2,6` - PowerShell can bind that as phase 45. Writes `_logs/smokes/summary.txt` with phase status plus `P*:` / `SCRIPT ERROR` highlights only. Full PC-offload catalog: `design/pc-offload.md`.

Binary (Steam tools build): `C:/Program Files (x86)/Steam/steamapps/common/Godot Engine/godot.windows.opt.tools.64.exe` (also in `tools/export_web.ps1`).

**Required flags** when stdout/stderr are redirected (CI, `Start-Process -Redirect*`, agent shells):

```
--headless --display-driver headless --audio-driver Dummy --path <WDB_ROOT> -- --wdb-phaseN-smoke
```

- Plain `--headless` alone can **hang forever** with only the engine banner and empty stderr under redirected IO. Always pass `--display-driver headless` `--audio-driver Dummy` for automated smoke.
- Put the phase flag in **user** args (after `--`) so `OS.get_cmdline_user_args()` sees it.
- Capture stderr for `P1:`…`P9:` lines and `SCRIPT ERROR`. Exit is self-quit from the phase (or kill after a timeout if hung).
- Optional: `--verbose` for load traces (huge logs). Not required once drivers are set.
- Compile/reload check is separate: see `design/grok-bot-session.md` (`--editor --import`). Do not treat a smoke pass as proof scripts are editor-clean, or vice versa.

| Fn | Checks |
|----|--------|
| p1 | Boot, player, camera, basic weapon |
| p2 | Weapon swap, telegraphs, projectiles, FPS estimate |
| p3 | Floor data, doors, stairs, boss flow |
| p4 | Roster, named, flee, pressure safety |
| p5 | Gather nodes, extract UI, puzzle props |
| p6 | Artifacts, food/potion, forge, quests |
| p7 | HUD, pause, debug, recap |
| p8 | Hub spots, building depth, save backup, archive catalog |
| p9 | Audio, archive catalog, anim models, playtest hook |
