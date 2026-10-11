extends Object

## P3 regression check for dungeon actor shadows (design/graphics-actor.md) and the spatial grids behind them.
## Every published light cast must find itself through LightRt.nearest_casts (CastGrid), and SepGrid must bucket
## every live enemy. Prints "P3: marks_ok=" and, on a miss, a "SMOKE FAIL" line that fails the phase.

const LightRt := preload("res://scripts/graphics/light_rt.gd")
const SepGrid := preload("res://scripts/combat/enemy/sep_grid.gd")
const Combat := preload("res://scripts/combat/combat.gd")

static func run(host: Node) -> void:
	host.get_tree().create_timer(1.0).timeout.connect(func(): _check())

static func _check() -> void:
	var casts: Array[Dictionary] = LightRt._casts
	var miss: int = 0
	for c in casts:
		if LightRt.nearest_casts(c["xz"], 3).is_empty():
			miss += 1
	var listed: int = 0
	var live: int = 0
	var enemies: Array = Combat.enemies()
	if not enemies.is_empty():
		var at: Vector3 = (enemies[0] as Node3D).global_position
		SepGrid.near(at, 1.0)
		for e in enemies:
			if e != null and is_instance_valid(e):
				live += 1
		for k in SepGrid._grid:
			listed += (SepGrid._grid[k] as PackedInt32Array).size()
	var ok: bool = casts.size() > 0 and miss == 0 and listed == live
	printerr("P3: marks casts=%d miss=%d sep=%d/%d" % [casts.size(), miss, listed, live])
	printerr("P3: marks_ok=" + str(ok))
	if not ok:
		printerr("SMOKE FAIL: dungeon shadow casts or enemy grid empty (marks_check.gd)")
