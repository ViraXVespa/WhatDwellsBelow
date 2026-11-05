# Remove unnecessary per-frame work; convert to events and triggers

id: process-cleanup
owner: web
status: open
done-when: every item below no longer runs unconditionally in _process / process_floor; crystal safe zones use area volumes; telemetry and debug timing are release-safe; no gameplay regressions; gates pass
resume: start a web session and open the process-cleanup task

## Background
A performance investigation found many `_process` and `process_floor` callbacks that exist only for convenience. They are small individually but add up, and several of them (crystal guard, telemetry enemy walk, map-related, etc.) do real work every frame.

## Items to convert
- **Crystal safe zones**: Replace `CrystalNet.guard` (per-frame walk of activated crystals × all enemies that `queue_free`s anyone inside `crystal_arrive_r`) with area volumes. Desired behavior: active crystal area acts like the ghost vendor safe zone—enemies turn around if they try to enter and are not currently aggroed on the player; player cannot interact with an activated crystal while enemies are inside it; a slightly larger clear can run once when the player travels to a different crystal. No per-frame scan.
- **Telemetry**: Remove the enemy-group walk that detects “fighting” from release builds. Use enter/exit-attack-state and death triggers instead. Make `Dbg.hitch_tick` and the floor timing accumulation in `process_floor` debug-only.
- **Input**: Make Pad, Touch HUD drawing, camp pause, and dungeon pause/map fully event-driven (or dirty-flag). Remove their `_process` polls.
- **Depth sorting**: `Depth.apply` (writes `sorting_offset` every present) → set Godot’s built-in sorting offset once or only on move.
- **Aim line and aura**: Update only when adrenaline is active or when the aim line is enabled and the aim direction has changed.
- **Progress UI**: `Flow._process` only while the panel is open.
- **Adrenaline audio**: The loop-restart check only while adrenaline is actually active (not in the hub).
- **Dungeon triggers**: `reveal_around` → fire-once on cells; pressure and plates → triggers on the objects; stairs and hint refresh → dirty flags.
- **Torch facing**: Calculate once when the torch is placed; remove the per-frame `look_at`.
- **Camp UI**: Bank/prompt label updates and pause input → signals or existing Pad edges, not `camp.gd` `_process`.
- **GUI focus release**: The every-frame `gui_release_focus` in `app_boot.gd` (workaround so B/dash does not fire after closing a menu) must move off the hot path—one-shot on enter or a proper focus signal.

## Acceptance
- No behavior changes except the removal of useless per-frame work.
- Crystal safe-zone rules work as described.
- Release builds do not walk enemies for telemetry or run hitch/floor timing.
- User confirms nothing feels broken.
