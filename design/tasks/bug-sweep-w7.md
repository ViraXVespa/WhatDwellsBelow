# Bugs found in grok-build-w7 sweep

id: bug-sweep-w7
owner: build
status: open
done-when: All listed issues are fixed or explicitly deferred with design confirmation; second-pass findings (if any) are incorporated
resume: python tools/task.py show bug-sweep-w7

## Confirmed issues (first pass)

### High
- Static near-interact cache can return freed or stale nodes (`scripts/world/player/near_interact.gd`). Shared statics + no validity check on fresh path.
- Extract one-item path silently drops bag items on UID miss (`scripts/data/progress/extract.gd`). Failed `remove_uid` treated as gone; non-mailable items never banked.
- Projectile flush resolves a potentially freed lock target (`scripts/combat/projectile.gd`). `_flush` calls `_resolve` without fresh validity test.

### Medium
- Restock overwrites partial potion charges (`scripts/data/progress_quest/restock.gd`). Replaces slot instead of topping up.
- Enemy present forces Y = 0 after every slide (`scripts/combat/enemy/enemy_present.gd`). Fights fly/hop lift.
- Threat walk-level indexes distance array without bounds (`scripts/combat/threat.gd`). Out-of-grid cell yields crash or wrong CL.
- Telegraph meshes leak on replacement (`scripts/combat/telegraph.gd`). New mesh assigned without freeing previous.

## Broader defects noted (non-crash / incomplete / feel)

- Animation direction fallback collapses diagonals (`player_anim.gd` `clip`).
- Interact prompts empty for gates; hidden chests not fully locked (`interact_prompt.gd`).
- Locomotion falls through with no texture on empty clips (`anim_loco.gd`).
- Skill XP floating-point edge drift (`progress_combat.gd`).
- Gear roll can leave only primary affix under restrictive unlocks (`gear_roll.gd`).
- HP bar recreates full ImageTexture every update and has no cleanup (`hp_bar.gd`).
- Floating-number and HP-bar spawn via repeated script load.
- Player ground cache is static and shared (`ground.gd`).
- Progress UI flow leaves stale focus/status on mode change (`ui_flow.gd`).
- Shop/inventory minor type and lifetime issues.
- Camp spot placement assumes every named spot exists.

## Second pass
A follow-up sweep focused on incorrect non-crashing behavior, feel/presentation, progression edges, and resource lifetime may append additional items. Do not mark this task done until that pass is complete or explicitly skipped.

## Notes
Open tasks (ui-quest-board-posters, inventory-consumables, metal-hud-mana, ui-recap-skills-style, rekey-assets, etc.) already cover some visual and content incompleteness; those are not re-listed here.
