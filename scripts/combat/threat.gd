extends Object

## Enemy combat level from walk-distance to the floor entrance.
## Each floor spans 20 combat levels: floor 1 is 1–20, floor 2 is 21–40,
## and so on. End-of-floor uses a high percentile of all floor cells so
## the guardian room is not the unique floor-cap landmark.
##
## Rank multipliers compare enemy combat_lv to the player's combat
## level (max style). Off-style play shifts the player level toward
## style_lv by cl_style_weight, then the same geometric table is used.
## Each full level of difference compounds the per-step factors with
## no cap.
##
## Player CL is the average of four skills (weapon + partner + HP +
## Defense), so one player CL is four skill-levels of old sum-CL.
## Floor span and per-CL enemy stats are scaled to that unit.


static func per_floor() -> int:
	if App.bal:
		return maxi(1, int(App.bal.enemy_cl_per_floor))
	return 20


static func floor_lo(floor_n: int) -> int:
	var n := maxi(1, floor_n)
	return per_floor() * (n - 1) + 1


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
	var dmg_r := 0.072 + 0.048
	var hp_r := 0.040 + 0.064
	var def_r := 1.6 + 1.2
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


static func _bal_f(name: String, fallback: float) -> float:
	if App.bal == null:
		return fallback
	return float(App.bal.get(name)) if App.bal.get(name) != null else fallback


## difference = enemy_lv - effective player lv
static func rank_diff(enemy_lv: int) -> float:
	if enemy_lv <= 0:
		return 0.0
	var max_style := 1.0
	var cur_style := 1.0
	if App.prog:
		if App.prog.has_method("combat_lv_f"):
			max_style = float(App.prog.combat_lv_f())
			cur_style = float(App.prog.style_lv_f())
		else:
			max_style = float(App.prog.combat_lv())
			cur_style = float(App.prog.style_lv())
	var weight := clampf(_bal_f("cl_style_weight", 0.5), 0.0, 1.0)
	var player_lv := lerpf(max_style, cur_style, weight)
	return float(enemy_lv) - player_lv


static func _geom(step_up: float, step_down: float, diff: float) -> float:
	if is_zero_approx(diff):
		return 1.0
	if diff > 0.0:
		return pow(step_up, diff)
	return pow(step_down, -diff)


## Enemy damage dealt to the player.
static func dealt_mult(enemy_lv: int) -> float:
	return _geom(_bal_f("cl_dealt_up", 1.03), _bal_f("cl_dealt_down", 0.97), rank_diff(enemy_lv))


## Damage the enemy receives from the player.
static func received_mult(enemy_lv: int) -> float:
	return _geom(_bal_f("cl_received_up", 0.97), _bal_f("cl_received_down", 1.03), rank_diff(enemy_lv))


## Kill XP multiplier.
static func xp_mult(enemy_lv: int) -> float:
	return _geom(_bal_f("cl_xp_up", 1.04), _bal_f("cl_xp_down", 0.97), rank_diff(enemy_lv))
