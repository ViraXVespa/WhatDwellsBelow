# What Dwells Below — Grok Build rules

Source of truth: Demo_GDD.md (current version on main).
Read Demo_GDD.md before writing code. Do not invent systems outside it.

The shipping game is the live path at the repo root
(`project.godot`, `scenes/`, `scripts/`, `assets/`).
Grok's job is to update that codebase in place.

Mandatory first actions on a fresh instance:
1. Read Demo_GDD.md and inspect the live tree. Do not start by archiving or rewriting.
2. Treat `archives/classic_2d/`, `archives/art_experiment/`, and `archives/full_3d_pass/` as frozen historical snapshots. Do not overwrite them. Do not copy them over the live path. Do not create a new archive unless the User explicitly asks.
3. Implement the requested change by editing live scenes, scripts, assets, and autoloads. Prefer the smallest patch that matches existing patterns.

Do not throw away, replace, or greenfield-rewrite the live path.
Do not extend, patch, or reuse archive code as if it were live unless the User asks to port a specific piece.

Section 18 phases are a coverage checklist against the existing live build, not a rebuild schedule.
After a requested slice of work, stop and report to the User.
Godot target: 4.7.2. Playable path must stay gamepad-first and web-exportable.