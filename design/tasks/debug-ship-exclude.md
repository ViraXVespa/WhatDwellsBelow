# Exclude debug systems from ship builds

id: debug-ship-exclude
owner: bot
status: open
done-when: Heavy debug tooling and the secret debug menu are excluded from release/web export presets; constraints updated; gates pass.
resume: python tools/bot_status.py --bot

## Intent
Remove the secret debug menu and all heavy debug tooling from release/ship builds (including web export). Debug systems must be completely excluded from the PCK in release presets, not merely runtime-gated.

## Scope
- Move heavy debug scripts/scenes (hitch log internals, bench counters, animation browser full viewer, playtest telemetry hooks, and any similar instrumentation) into a dedicated debug folder.
- Exclude that folder from release and web export presets so the files never enter the ship PCK.
- Remove the requirement that the secret debug menu ships (update design/constraints.md and any related docs).
- Keep a thin runtime gate (OS.has_feature("debug")) only where an entry point must remain in shared code.
- New instrumentation must be born in the excluded debug folder.

## Done criteria
- Release and web export presets exclude the debug folder.
- No heavy debug code is present in a release/web export.
- constraints.md no longer requires the secret debug menu in ship builds.
- check_load_graph and relevant gates pass.
- Code-map and design docs updated for the new ownership.

## Notes
This is a Bot job. Follow BOT.md. Prefer export exclusion over pure runtime checks for anything with cost or surface. Do not change gameplay behavior.
