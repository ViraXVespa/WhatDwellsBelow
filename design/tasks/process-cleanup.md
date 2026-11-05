# Remove unnecessary per-frame work; convert to events and triggers

id: process-cleanup
owner: web
status: open
done-when: every item below no longer runs unconditionally in _process / process_floor; crystal safe zones use area volumes; telemetry and debug timing are release-safe; no gameplay regressions; gates pass
resume: start a web session and open the process-cleanup task

## Background
A performance investigation found many `_process` and `process_floor` callbacks that exist only for convenience. They are small individually but add up, and several of them (crystal guard, telemetry enemy walk, map-related, etc.) do real work every frame.

## Items to convert
- **Aim line and aura**: DONE — update only on direction change or adrenaline toggle.
- **Adrenaline audio**: DONE — loop-restart only while active and in world.
- **Depth sorting**: DONE — set only when offset changes.
- **Torch facing**: DONE — camera-moved dirty flag.
- **Progress UI**: DONE — _process only while open or forging.
- **Dungeon triggers**: DONE — plates Area3D; reveal/stairs/hint dirty or fire-once.
- **Dungeon HUD**: DONE — per-element; gem pulse removed (color/visibility on events).

## Acceptance
- No behavior changes except the removal of useless per-frame work.
- Crystal safe-zone rules work as described.
- Release builds do not walk enemies for telemetry or run hitch/floor timing.
- User confirms nothing feels broken.

## User confirmations (post-all-slices)
User confirmations required after all process-cleanup slices land
(cannot be fully proven in scratch):

- Non-pursuing enemies reverse direction on volume enter (go back the way they came).
- Pursuing / aggroed enemies ignore the volume and continue chasing.
- Crystal activation and interaction blocked while volume enemy count > 0.
- Already-activated crystals that appear with enemies inside relocate those enemies to a nearby valid off-screen floor cell.
- Inactive crystals leave enemies in place for clearing.
- No other gameplay regressions (movement, combat, interact, web/gamepad).
- Release builds contain no enemy-group walks for telemetry or unconditional hitch/floor timing.

## Progress
Slice: plates converted to Area3D self-report; combat notes wired; camp empty process removed.
