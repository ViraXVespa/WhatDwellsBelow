# Bug sweep findings

id: bug-sweep-combined
owner: web
status: open
done-when: All listed issues are fixed or explicitly deferred with design confirmation
resume: python tools/task.py show bug-sweep-combined

## Findings

### Lifetime / cache
- Static near-interact cache can return freed or stale nodes (`scripts/world/player/near_interact.gd`). Shared statics + incomplete validity check on the fresh path.
- Projectile flush resolves a potentially freed lock target (`scripts/combat/projectile.gd`). `_flush` calls `_resolve` without its own fresh validity test.
- Player ground cache is static and shared (`ground.gd`).
- Floating-number and HP-bar spawn via repeated script load.

### Resource leaks
- Telegraph meshes leak on replacement (`scripts/combat/telegraph.gd`). New mesh assigned without freeing previous.
- HP bar recreates full ImageTexture every update and has no cleanup (`hp_bar.gd`).
- Crystal map texture leak (`crystal_ui.gd:_aim` creates a new `AtlasTexture` and assigns it without freeing the prior one).

### Collision / presentation
- Player collision/visual bounds mismatch (fixed `BoxShape3D` vs sprite `pixel_size` from art height).
- Enemy collision/visual bounds mismatch (`enemy_ready.gd` fixed `BoxShape3D(0.48, 1.05, 0.38)` vs `size_u`-scaled sprite).
- Enemy present forces Y = 0 after every slide (`scripts/combat/enemy/enemy_present.gd`). Fights fly/hop lift.
- Animation direction fallback collapses diagonals (`player_anim.gd` clip).
- Locomotion falls through with no texture on empty clips (`anim_loco.gd`).
- Interact prompts empty for gates; hidden chests not fully locked (`interact_prompt.gd`).
- Progress UI flow leaves stale focus/status on mode change (`ui_flow.gd`).
- Boss door remains in `boss_door`/`interact` groups after `open_door` disables the shape and tweens Y (`boss_door.gd`).

### Progression / economy
- Extract one-item path silently drops bag items on UID miss (`scripts/data/progress/extract.gd`). Failed `remove_uid` treated as gone; non-mailable items never banked.
- Restock overwrites partial potion charges (`scripts/data/progress_quest/restock.gd`). Replaces the slot instead of topping up.
- Threat walk-level indexes distance array without bounds (`scripts/combat/threat.gd`). Out-of-grid cell yields crash or wrong CL.
- Skill XP floating-point edge drift (`progress_combat.gd`).
- Gear roll can leave only primary affix under restrictive unlocks (`gear_roll.gd`).
- Anvil tab/`_drop_sub` mid-forge silent abort (`anvil_view.gd:set_tab` zeros `forge_t`, clears job fields, and calls `drop_sub` without `cancel_job`; materials already paid, batch/XP lost, no feedback or partial pick).
- Anvil analyze closes the sub-list (`sub_open.gd:pick` calls `analyze` then immediately `close_sub`).

### Other
- Shop/inventory minor type and lifetime issues.
- Camp spot placement assumes every named spot exists.

## Notes
- Partial guards (`is_instance_valid` somewhere else on the path, a string return instead of a crash) do not close an item.
- Open tasks that already cover visual or content incompleteness are not re-listed.
