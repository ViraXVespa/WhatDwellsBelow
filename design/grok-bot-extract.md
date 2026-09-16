# Grok Bot — extract / owner routing

Status: protocol  
Read when: Grok Bot Job table → ad-hoc extract or existing-owner routing  

Binding for **Grok Bot** extract sessions only. This is not the staged reuse-map PR (`design/grok-bot-reuse.md`). This is not a size sweep. User-gated: do not start this flow unless the User named extract / DRY / shared helpers / an owner route *and* did not hand a non-empty `design/reuse-map.md` brief.


## Mandate

Move near-identical control flow (renamed locals OK) to one owner. No behavior change. No new game systems.

- Prefer a **new shared module** when the same flow spans systems and the current owner would blow 10KB or is the wrong concern.
- Prefer an **existing owner** only when that script already is the concern and stays under 10KB after the calls land.
- Never grow an owner just to avoid a new file.
- Never treat vaguely similar features as the same flow.
- Touched live `scripts/**/*.gd` ship under 10KB. Split with `design/refactor.md` (recipe only). Do not keep splitting toward 5KB in this flow.

## Read set

1. This file
2. `design/refactor.md` (recipe only)
3. One `design/code-map.md` **system row** for the named cluster
4. After the User names the cluster: only those live `.gd` bodies
5. At ship: `scripts/data/version.json` + `design/versioning-log.md` body shape — not the changelog tree

Do not reopen `AGENTS.md` unless types, warnings, tabs, or the 10KB cap left context. Do not open `design/reuse-map.md` (empty template is not a worklist). Do not walk the whole live tree to rediscover copies. Ask if the pair is not actually the same flow.

## Do not merge

Keep these as separate concerns unless the User overrides a specific row:

- `gather_node` vs `breakable` vs `pickup` vs used-chest fade
- `player_hit*` vs `enemy_hit.take_hit` vs dummy `take_hit`
- World `hp_bar.gd` vs HUD meters vs recap XP bars
- `progress_ui` mode rebuild vs SplitMenu chrome
- Title / splash / FS-gate void vs dungeon dim plates
- `present.gd` vs menu dim
- `web_pad.gd` vs `input/pad.gd` vs `touch_pad.gd`
- `display_mode` web vs desktop
- `dungeon_map_act` pan / zoom vs crystal map marks
- `step_row` vs sliders vs debug SpinBox
- `interact_prompt.gd` vs `PromptView`
- Playtest grid walk vs combat cover projection
- Playtest log / path / AI internals into combat or world
- Restyling debug value editors to match pause

## Pass

1. Name the cluster and the intended owner or new module. Wait if that is not already explicit.
2. Verify both bodies before moving.
3. Route call sites. Update `design/code-map.md` in the same PR when a new public helper path appears.
4. Verify with `design/pc-offload.md` runners as needed. Ship per the door.

Public entry points that must not change when a helper is split: `App.playtest`, `App.set_zoom` / `App.set_hud_scale` / `App.set_volume`, `PauseInv.*`, `Gen.generate` / `Gen.make_opening`, `EnemyAI.tick`, `SmokeLate.p5`–`p9`, `ProgressGear.make_*`.
