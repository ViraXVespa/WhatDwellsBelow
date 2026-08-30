extends Object

## Enemy combat level from walk-distance to the floor entrance.
## End-of-floor uses a high percentile of all floor cells so the
## guardian room is not the unique "level 20 / 40 / ..." landmark.

static func per_floor() -> int:
	if App.bal:
		return maxi(1, int(App.bal.enemy_cl_per_floor))
	return 20


static func floor_lo(floor_n: int) -> int:
	var n := maxi(1, floor_n)
	if n <= 1:
		return 1
	return per_floor() * (n - 1)


static func floor_hi(floor_n: int) -> int:
	return per_floor() * maxi(1, floor_n)


static func level_at(floor_n: int, cell: Vector2i, dist: PackedInt32Array, w: int, cap: int) -> int:
	var lo := floor_lo(floor_n)
	var hi := floor_hi(floor_n)
	var walk := 0
	if w > 0:
		var i := cell.y * w + cell.x
		if i >= 0 and i < dist.size() and dist[i] >= 0:
			walk = dist[i]
	var t := clampf(float(walk) / float(maxi(1, cap)), 0.0, 1.0)
	var lv := int(round(lerpf(float(lo), float(hi), t)))
	var jmax := 0
	if App.bal:
		jmax = maxi(0, int(App.bal.enemy_cl_jitter))
	if jmax > 0:
		var h := absi((cell.x * 73856093) ^ (cell.y * 19349663) ^ (floor_n * 83492791))
		lv += (h % (jmax * 2 + 1)) - jmax
	return clampi(lv, lo, hi)


static func apply(base_hp: float, base_dmg: float, base_def: float, cl: int) -> Dictionary:
	var ranks := maxi(0, cl - 1)
	var dmg_r := 0.018 + 0.012
	var hp_r := 0.010 + 0.016
	var def_r := 0.4 + 0.3
	if App.bal:
		dmg_r = float(App.bal.enemy_cl_dmg) + float(App.bal.enemy_cl_gear_dmg)
		hp_r = float(App.bal.enemy_cl_hp) + float(App.bal.enemy_cl_gear_hp)
		def_r = float(App.bal.enemy_cl_def) + float(App.bal.enemy_cl_gear_def)
	var rf := float(ranks)
	return {
		"hp": base_hp * (1.0 + hp_r * rf),
		"dmg": base_dmg * (1.0 + dmg_r * rf),
		"def": base_def + def_r * rf,
	}
