extends Object


static func run(b: Object, old_rev: int, bal_rev: int) -> bool:
	if old_rev >= bal_rev:
		return false
	if old_rev < 2:
		b.gen_w = 216
		b.gen_h = 216
		b.gen_rooms = 36
		b.gen_extra_loops = 8
		b.mine_nodes = 18
		b.wood_nodes = 14
		b.break_count = 24
	if old_rev < 3:
		b.xp_double_every = 14.0
		b.xp_level = 100.0
	if old_rev < 4:
		b.enemy_cl_per_floor = 20.0
		b.enemy_cl_end_pct = 0.86
		b.enemy_cl_jitter = 2.0
		b.enemy_cl_dmg = 0.018
		b.enemy_cl_gear_dmg = 0.012
		b.enemy_cl_hp = 0.010
		b.enemy_cl_gear_hp = 0.016
		b.enemy_cl_def = 0.4
		b.enemy_cl_gear_def = 0.3
	if old_rev < 6:
		b.enemy_cl_per_floor = 5.0
		b.enemy_cl_jitter = 1.0
		b.enemy_cl_dmg = 0.072
		b.enemy_cl_gear_dmg = 0.048
		b.enemy_cl_hp = 0.040
		b.enemy_cl_gear_hp = 0.064
		b.enemy_cl_def = 1.6
		b.enemy_cl_gear_def = 1.2
		b.cl_dealt_up = 1.075
		b.cl_dealt_down = 0.925
		b.cl_received_up = 0.925
		b.cl_received_down = 1.075
		b.xp_kill_hp = 3.0
		b.xp_kill_def = 3.0
	if old_rev < 7:
		b.gen_w = 432
		b.gen_h = 432
	if old_rev < 8:
		b.crystal_min_sep = 56
		b.crystal_clear_r = 12
		b.crystal_arrive_r = 8
		b.crystal_extra_max = 4
		b.crystal_place_chance = 0.62
	if old_rev < 9:
		b.gen_rooms = 64
		b.enemy_cl_per_floor = 20.0
		b.cl_dealt_up = 1.03
		b.cl_dealt_down = 0.97
		b.cl_received_up = 0.97
		b.cl_received_down = 1.03
		b.cl_xp_up = 1.04
		b.cl_xp_down = 0.97
		b.xp_per_kill = 22.0
		b.xp_kill_hp = 11.0
		b.xp_kill_def = 11.0
		b.axe_damage = 16.0
		b.room_pack = 3.0
		b.base_guards = 5
		if b.get("hall_w_min") != null:
			b.hall_w_min = 2
			b.hall_w_mode = 3
			b.hall_w_max = 4
			b.hall_w_interval = 10
			b.hall_w_min_pct = 0.15
			b.hall_w_mode_pct = 0.60
		if b.get("ambush_cap") != null:
			b.ambush_cap = 40
			b.ambush_spacing = 10
			b.ambush_pack_min = 1
			b.ambush_pack_max = 2
		if b.get("pressure_waves") != null:
			b.pressure_waves = 3
		if b.get("crystal_deadend_sep") != null:
			b.crystal_deadend_sep = 18
		b._ensure_enemies()
		var hp := {
			"slime": 48.0, "goblin": 64.0, "orc": 116.0, "skeleton": 72.0,
			"bat": 40.0, "spider": 56.0, "archer": 52.0, "shaman": 60.0,
			"imp": 44.0, "wolf": 68.0, "beetle": 104.0, "wisp": 36.0,
		}
		for id in hp.keys():
			if b.enemy_stats.has(id):
				(b.enemy_stats[id] as Dictionary)["hp"] = hp[id]
	return true
