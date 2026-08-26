# What Dwells Below — Grok Build rules

Source of truth: Demo_GDD.md (current version on main).
Read Demo_GDD.md before writing code. Do not invent systems outside it.

Mandatory first actions on a fresh instance:
1. Archive the current live path as archives/full_3d_pass/ per Section 20.
2. Verify that archive launches with zero shared live-path state.
3. Then implement a clean live rewrite. Do not extend, patch, or reuse live scenes/scripts/autoloads.

Follow Section 18 phases in order. After each phase, stop and report to the User.
Godot target: 4.7.2. Playable path must stay gamepad-first and web-exportable.