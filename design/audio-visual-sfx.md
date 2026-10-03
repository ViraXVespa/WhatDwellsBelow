# Audio: SFX cues and wiring

Status: binding design + live snapshot  
Read when: wiring or adding an SFX cue, the Appendix E minimum set, the silent-cue table  
Code: `scripts/audio/sfx.gd`, `scripts/audio/music.gd`  

## SFX – minimum required set (Appendix E)

All volumes are controlled by the SFX slider. Additional short UI, weapon-specific, and ambient sounds may be added.

| SFX | Notes |
|-----|-------|
| Melee hit | |
| Player hurt | Separate male and female VO performances of equal scope |
| Special / Slam impact | |
| Dash | |
| Mining hit | |
| Woodcutting hit | |
| Breakable smash | |
| Item pickup | |
| UI click / confirm / cancel | |
| Level-up | |
| Adrenaline Rush start (warcry) | Separate male and female performances of equal scope |
| Adrenaline Rush loop (woosh / crackle) | |
| Critical hit | |
| Potion use | Instant heal; distinct from food |
| Food use | Heal-over-time start; distinct from potion |
| Deathrattle “hurk” | Separate male and female performances of equal scope |
| Comedic thud (“Dispel”) | |
| Consciousness-transfer (enter dungeon) | Short presentation beat |
| Wake-up (return to Placeholdia) | Short presentation beat |

## Where cues come from, and how Build wires one
- Assets: `assets/audio/` (`p2_*`, `p9_*` and `sfx_*` wavs, `music_*`). `sfx.gd` `_ready()` maps each cue id to a file (`_load("hit", "res://assets/audio/p2_hit.wav")`); a missing file loads silent, so check the path.
- Play: `App.sfx("id")` at the event (`App.sfx` forwards to the `sfx.gd` node). `hurt`, `warcry` and `hurk` resolve to `_male` / `_female` by `App.character_type`. The adrenaline loop is `set_adrenaline(true/false)` from `app_run.gd`.
- Volume: every player is on the Master bus at `vol_sfx * vol_master`; there are no custom buses. Music is `music.gd`.
- New cue: reuse a file already under `assets/audio/` when one fits. A new file is an access confirm (new asset location) and `isolated-media.md` if Imagined. Then add one `_load` line and one `App.sfx` call, and run smoke 9.
- Unused wavs `sfx_dash`, `sfx_hit`, `sfx_level`, `sfx_slam` are the original cues for dash, hit, level-up and slam. Each event already plays its `p2_*` / `p9_*` replacement (`dash`, `hit`, `level`, `slam` in `sfx.gd`), so they stay unwired; `sfx_hurt` and `sfx_mine` are live fallbacks.
- An event listed under Missing SFX stays silent until the User approves wiring it: ask, do not add.

## Missing SFX (silent today; Build may generate these on request, not wire them)
Same rules as above: new file under `assets/audio/`, one `_load` line, one `App.sfx` call. Short, dry, placeholder-grade, matched to the existing `sfx_ui` / `p9_*` loudness.

| Event | Code location | Cue id / file | Duration and character |
|-------|---------------|---------------|------------------------|
| Anvil, loadout crystal, quest board, vendor, dumpster, billboard panel opens | `interact_act.gd` `open_chest` (one branch per kind) | `panel_open` / `p10_panel_open.wav` (shared) | 0.15 s soft wooden or paper rustle, no pitch |
| Stairs descend | `interact_act.gd` stairs branch, `App.next_floor()` | `stairs` / `p10_stairs.wav` | 0.5 s stone steps down plus a short echo |
| Enemy death | `enemy_hit.gd` `die` | `enemy_die` / `p10_enemy_die.wav` | 0.3 s comic poof or squelch; readable over `hit` |
| Enemy hits player (impact, not the hurt VO) | `enemy_ai.gd` `hit_player` | `player_struck` / `p10_player_struck.wav` | 0.2 s dull thump, lower than `hit`; the hurt VO already plays in `player_act.gd` |
| Chest open | `interact_act.gd` `open_chest` chest branch (today plays `pickup`) | `chest` / `p10_chest.wav` | 0.4 s creak then latch click |
| Quest accept | `quest_roll.gd` `accept_quest` | `quest_accept` / `p10_quest_accept.wav` | 0.3 s two-note stamp or seal, hopeful |

Generate a placeholder wav with `python3 tools/make_sfx.py --only <id>`: add one entry to `tools/sfx-cues.json` (sine, noise, mix, cat nodes; the 22 existing p2/p9 cues live there, byte-identical, `--check` proves it). No new `make_pN` script.
