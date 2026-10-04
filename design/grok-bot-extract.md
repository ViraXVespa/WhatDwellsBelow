# Grok Bot — extract / owner routing

Status: protocol  
Read when: Grok Bot Job table → ad-hoc extract or existing-owner routing  

For **Grok Bot** extract sessions only. This is not the staged reuse-map PR (the reuse Bot job). This is not a size sweep. User-gated: do not start this flow unless the User named extract / DRY / shared helpers / an owner route *and* did not hand over a non-empty staged reuse brief.

## Mandate

Move near-identical control flow (renamed locals OK) to one owner. No behavior change. No new game systems.

Owner choice (new shared module vs existing owner) and the near-identical test: `refactor.md` (New shared modules and reuse). An existing owner must stay under 10KB after the calls land. Do not keep splitting toward 5KB in this flow.

## Read set

1. `design/refactor.md` (recipe only)
2. One `design/code-map.md` **system row** for the named cluster
3. After the User names the cluster: only those live `.gd` bodies

Do not open the staged reuse brief (empty template is not a worklist). Do not walk the whole live tree to rediscover copies. Ask if the pair is not actually the same flow.

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
- `map_act` pan / zoom vs crystal map marks
- `step_row` vs sliders vs debug SpinBox
- `interact_prompt.gd` vs `PromptView`
- Playtest grid walk vs combat cover projection
- Playtest log / path / AI internals into combat or world
- Restyling debug value editors to match pause

## Pass

1. Name the cluster and the intended owner or new module. Wait if that is not already explicit.
2. Verify both bodies before moving.
3. Route call sites. A new shared module goes in its owner's stem folder (refactor.md, Cluster folders). Update `design/code-map.md` in the same PR when a new public helper path appears.
4. Prove: `BOT.md`.

Public entry points that must not change when a helper is split are listed in `design/code-map.md`.
