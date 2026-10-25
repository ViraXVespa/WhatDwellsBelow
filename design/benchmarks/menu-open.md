# Benchmark: menu first open

Status: record
Read when: a menu open feels slow, or `open_timing` is rerun

Source: `python tools/gate.py bot-smokes` (open_timing smoke, `OPEN:` lines, pass 1 = first open). Each run writes `_logs/smokes/open_timing.env.txt` (machine fields from `tools/lib/perf/bench_env.py` plus the engine's `OPEN: env` line: renderer, GPU, display, vsync, max_fps, resolution); copy it with the row. Rows before 2026-10-20 15:00 predate that line: their vsync / cap / resolution are unknown.

| Date | Machine | Commit | Menu | First open call_ms | Note |
|------|---------|--------|------|--------------------|------|
| 2026-10-20 | `bot-box` | `7eb51fd5` | inventory | 53.1 -> 11.0 | Slot marker glyph the UI font lacks forced a system-font fallback on every slot build |

`bot-box`, 2026-10-20 14:34, `5b0f1feb` (pass 1 call_ms; frame_ms 6.8-8.9 for all): anvil 7.3, controls_billboard 5.6, dumpster 6.0, extraction_gate 5.1, ghost_shop 2.4, inventory 9.6, loadout_crystal 6.9, pause 9.9, pause_inventory 16.2, pause_quest 10.2, pause_skills 11.1, quest_board 6.2, recap 6.4, receptionist 1.7, vendor 3.2.

`bot-box`, 2026-10-20 15:00, `0d497e2a`+ (env: Godot 4.7.2-stable, gl_compatibility, GPU name empty, display headless, vsync mode 1, max_fps 0 = uncapped, viewport 1920x1920): anvil 8.0, controls_billboard 4.7, dumpster 5.3, extraction_gate 5.7, ghost_shop 2.2, inventory 9.4, loadout_crystal 8.4, pause 8.5, pause_inventory 15.4, pause_quest 9.1, pause_skills 12.6, quest_board 6.9, recap 6.6, receptionist 1.5, vendor 3.1.
