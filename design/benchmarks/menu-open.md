# Benchmark: menu first open

Status: record
Read when: a menu open feels slow, or `open_timing` is rerun

Source: `python tools/bot_smokes.py` (open_timing smoke, `OPEN:` lines, pass 1 = first open). Box: 8-core Xeon, headless, shared.

| Date | Commit | Menu | First open call_ms | Note |
|------|--------|------|--------------------|------|
| 2026-10-20 | `7eb51fd5` | inventory | 53.1 -> 11.0 | Slot marker glyph the UI font lacks forced a system-font fallback on every slot build |

2026-10-20, `250c5167`+ (pass 1 call_ms; frame_ms 6.8-8.9 for all): anvil 7.3, controls_billboard 5.6, dumpster 6.0, extraction_gate 5.1, ghost_shop 2.4, inventory 9.6, loadout_crystal 6.9, pause 9.9, pause_inventory 16.2, pause_quest 10.2, pause_skills 11.1, quest_board 6.2, recap 6.4, receptionist 1.7, vendor 3.2.
