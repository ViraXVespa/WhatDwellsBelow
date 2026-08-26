extends RefCounted

## All Phase 2 combat numbers. Mutated by the secret debug menu.

var move_speed := 4.5
var dash_speed_mult := 2.8
var dash_duration := 0.28
var dash_cooldown := 1.1
var special_windup := 0.22
var special_recovery := 0.35
var attack_move_mult := 0.45

var axe_damage := 18.0
var axe_range := 1.85
var axe_arc_deg := 110.0
var axe_rate := 1.7
var axe_hit_norm := 0.42
var axe_los := false
var axe_slam_mult := 1.8
var slam_radius := 2.2
var slam_stagger := 0.85
var slam_stagger_boss := 0.35

var staff_damage := 9.0
var staff_range := 1.2
var staff_arc_deg := 80.0
var staff_rate := 2.2
var staff_hit_norm := 0.38
var staff_los := false
var staff_special_damage := 24.0
var staff_special_radius := 2.15

var bow_damage := 14.0
var bow_range := 8.0
var bow_proj_speed := 14.0
var bow_rate := 1.9
var bow_hit_norm := 0.35
var bow_los := true
var bow_special_count := 5
var bow_special_cone := 50.0
var bow_special_range := 6.5
var bow_special_damage := 10.0

var crit_chance := 0.12
var crit_mult := 2.0
var knockback := 3.4
var hitstop := 0.055
var dummy_hp := 80.0
var dummy_defense := 0.0
var defense_k := 100.0
var xp_per_kill := 12.0

var adrenaline_window := 4.5
var adrenaline_kills := 4
var adrenaline_speed := 1.35
var adrenaline_xp_stack := 0.15
var adrenaline_timeout := 4.5

var aim_line_on := true
var aim_line_opacity := 0.85
var aim_line_width := 0.08
var aim_line_use_weapon_range := true
var aim_line_length := 4.0

var lock_stick_delay := 0.18
var lock_stick_deadzone := 0.42
var atk_fps := 10.0

var trail_gap := 0.045
var trail_life := 0.22

var gen_w := 48
var gen_h := 48
var gen_rooms := 12
var gen_room_min := 5
var gen_room_max := 9
var gen_extra_loops := 3
var fog_radius := 5
var max_clerks := 3
var ghost_shop_chance := 0.33
var base_guards := 8
var boss_hp_mult := 8.0
var cycle_hp := 0.2

var player_max_hp := 100.0
var player_hurt_iframe := 0.35
var leash_range := 9.0
var hunt_duration := 1.8
var reaggro_cd := 0.6
var aggro_range := 7.5
var flee_per_floor := 2.0
var flee_hp_frac := 0.4
var flee_speed_mult := 1.45
var flee_run_time := 1.15
var flee_help := 2.0
var idle_timer := 24.0
var noreveal_timer := 22.0
var pressure_count := 3.0
var pressure_radius := 5.0
var pressure_cd := 18.0
var named_every := 3.0
var named_scale := 1.28
var named_hp := 1.8
var named_dmg := 1.35
var enemy_sep := 0.55
var enemy_hp_mult := 1.0
var enemy_dmg_mult := 1.0
var enemy_speed_mult := 1.0
var windup_melee := 0.42
var windup_ranged := 0.38
var windup_mage := 0.55
var enemy_recover := 0.35
var enemy_proj_speed := 9.0
var hop_height := 0.28
var fly_height := 0.45
var room_pack := 3.0

var mine_hits := 4
var mine_time := 2.4
var mine_chance := 0.65
var wood_hits := 8
var wood_time := 1.2
var wood_chance := 0.32
var skill_gather := 0.02
var tool_gather := 0.03
var break_gold := 0.55
var break_orb := 0.35
var orb_heal := 18.0
var crack_hp := 8.0
var shrine_dmg := 0.2
var shrine_time := 45.0
var campfire_heal := 0.4
var snack_cost := 25.0
var snack_heal := 22.0
var art_cost := 40.0
var pawn_gold := 8.0
var chest_art := 0.35
var mine_nodes := 5
var wood_nodes := 4
var break_count := 8
var shrine_count := 1
var campfire_count := 1
var bag_cap := 28
var food_bring_max := 20
var food_hot_x := 40.0
var food_hot_y := 8.0
var potion_heal := 100.0
var forge_gold := 18.0
var forge_ore := 6.0
var forge_root := 2.0
var xp_keep := 0.2
var restock_gold := 8.0
var bitter_loop_offset := 15.52
var music_fade := 0.35
var playtest_scale := 6.0
var playtest_limit := 90.0


func schema() -> Array:
	return [
		["move_speed", 0.2, 12.0, 0.1],
		["dash_speed_mult", 1.0, 6.0, 0.05],
		["dash_duration", 0.05, 1.2, 0.01],
		["dash_cooldown", 0.1, 4.0, 0.05],
		["special_windup", 0.05, 1.0, 0.01],
		["special_recovery", 0.05, 1.5, 0.01],
		["attack_move_mult", 0.0, 1.0, 0.05],
		["axe_damage", 1.0, 80.0, 1.0],
		["axe_range", 0.4, 6.0, 0.05],
		["axe_arc_deg", 20.0, 180.0, 1.0],
		["axe_rate", 0.4, 6.0, 0.05],
		["axe_hit_norm", 0.05, 0.95, 0.01],
		["axe_los", 0.0, 1.0, 1.0],
		["axe_slam_mult", 1.0, 5.0, 0.05],
		["slam_radius", 0.6, 8.0, 0.05],
		["slam_stagger", 0.0, 3.0, 0.05],
		["slam_stagger_boss", 0.0, 2.0, 0.05],
		["staff_damage", 1.0, 80.0, 1.0],
		["staff_range", 0.4, 5.0, 0.05],
		["staff_arc_deg", 20.0, 180.0, 1.0],
		["staff_rate", 0.4, 8.0, 0.05],
		["staff_hit_norm", 0.05, 0.95, 0.01],
		["staff_los", 0.0, 1.0, 1.0],
		["staff_special_damage", 1.0, 80.0, 1.0],
		["staff_special_radius", 0.4, 8.0, 0.05],
		["bow_damage", 1.0, 80.0, 1.0],
		["bow_range", 1.0, 20.0, 0.1],
		["bow_proj_speed", 2.0, 40.0, 0.5],
		["bow_rate", 0.4, 8.0, 0.05],
		["bow_hit_norm", 0.05, 0.95, 0.01],
		["bow_los", 0.0, 1.0, 1.0],
		["bow_special_count", 1.0, 12.0, 1.0],
		["bow_special_cone", 10.0, 120.0, 1.0],
		["bow_special_range", 1.0, 20.0, 0.1],
		["bow_special_damage", 1.0, 80.0, 1.0],
		["crit_chance", 0.0, 1.0, 0.01],
		["crit_mult", 1.0, 5.0, 0.05],
		["knockback", 0.0, 12.0, 0.1],
		["hitstop", 0.0, 0.25, 0.005],
		["dummy_hp", 10.0, 500.0, 5.0],
		["dummy_defense", 0.0, 200.0, 1.0],
		["defense_k", 10.0, 400.0, 5.0],
		["xp_per_kill", 0.0, 100.0, 1.0],
		["adrenaline_window", 0.5, 12.0, 0.1],
		["adrenaline_kills", 1.0, 12.0, 1.0],
		["adrenaline_speed", 1.0, 3.0, 0.05],
		["adrenaline_xp_stack", 0.0, 1.0, 0.05],
		["adrenaline_timeout", 0.5, 12.0, 0.1],
		["aim_line_on", 0.0, 1.0, 1.0],
		["aim_line_opacity", 0.05, 1.0, 0.05],
		["aim_line_width", 0.02, 0.4, 0.01],
		["aim_line_use_weapon_range", 0.0, 1.0, 1.0],
		["aim_line_length", 0.5, 20.0, 0.1],
		["lock_stick_delay", 0.05, 1.0, 0.01],
		["lock_stick_deadzone", 0.1, 0.9, 0.01],
		["atk_fps", 4.0, 20.0, 0.5],
		["trail_gap", 0.01, 0.2, 0.005],
		["trail_life", 0.05, 1.0, 0.01],
		["gen_w", 24.0, 64.0, 1.0],
		["gen_h", 24.0, 64.0, 1.0],
		["gen_rooms", 6.0, 24.0, 1.0],
		["gen_room_min", 4.0, 10.0, 1.0],
		["gen_room_max", 5.0, 16.0, 1.0],
		["gen_extra_loops", 0.0, 12.0, 1.0],
		["fog_radius", 2.0, 12.0, 1.0],
		["max_clerks", 1.0, 3.0, 1.0],
		["ghost_shop_chance", 0.0, 1.0, 0.05],
		["base_guards", 3.0, 16.0, 1.0],
		["boss_hp_mult", 2.0, 20.0, 0.5],
		["cycle_hp", 0.0, 1.0, 0.05],
		["player_max_hp", 20.0, 400.0, 5.0],
		["player_hurt_iframe", 0.05, 1.5, 0.05],
		["leash_range", 3.0, 24.0, 0.5],
		["hunt_duration", 0.2, 6.0, 0.1],
		["reaggro_cd", 0.0, 4.0, 0.05],
		["aggro_range", 2.0, 20.0, 0.25],
		["flee_per_floor", 0.0, 8.0, 1.0],
		["flee_hp_frac", 0.1, 0.9, 0.05],
		["flee_speed_mult", 1.0, 3.0, 0.05],
		["flee_run_time", 0.3, 4.0, 0.05],
		["flee_help", 1.0, 6.0, 1.0],
		["idle_timer", 4.0, 60.0, 1.0],
		["noreveal_timer", 4.0, 60.0, 1.0],
		["pressure_count", 1.0, 8.0, 1.0],
		["pressure_radius", 2.0, 12.0, 0.5],
		["pressure_cd", 4.0, 60.0, 1.0],
		["named_every", 1.0, 8.0, 1.0],
		["named_scale", 1.0, 2.2, 0.05],
		["named_hp", 1.0, 4.0, 0.05],
		["named_dmg", 1.0, 3.0, 0.05],
		["enemy_sep", 0.1, 2.0, 0.05],
		["enemy_hp_mult", 0.2, 4.0, 0.05],
		["enemy_dmg_mult", 0.2, 4.0, 0.05],
		["enemy_speed_mult", 0.2, 3.0, 0.05],
		["windup_melee", 0.1, 1.5, 0.01],
		["windup_ranged", 0.1, 1.5, 0.01],
		["windup_mage", 0.1, 2.0, 0.01],
		["enemy_recover", 0.05, 2.0, 0.01],
		["enemy_proj_speed", 2.0, 30.0, 0.5],
		["hop_height", 0.0, 1.2, 0.02],
		["fly_height", 0.0, 1.5, 0.02],
		["room_pack", 1.0, 8.0, 1.0],
		["mine_hits", 3.0, 5.0, 1.0],
		["mine_time", 0.4, 6.0, 0.1],
		["mine_chance", 0.05, 1.0, 0.01],
		["wood_hits", 6.0, 10.0, 1.0],
		["wood_time", 0.3, 4.0, 0.1],
		["wood_chance", 0.05, 1.0, 0.01],
		["skill_gather", 0.0, 0.2, 0.005],
		["tool_gather", 0.0, 0.2, 0.005],
		["break_gold", 0.0, 1.0, 0.05],
		["break_orb", 0.0, 1.0, 0.05],
		["orb_heal", 4.0, 80.0, 1.0],
		["crack_hp", 2.0, 20.0, 1.0],
		["shrine_dmg", 0.05, 1.0, 0.05],
		["shrine_time", 5.0, 120.0, 1.0],
		["campfire_heal", 0.1, 1.0, 0.05],
		["snack_cost", 1.0, 100.0, 1.0],
		["snack_heal", 4.0, 100.0, 1.0],
		["art_cost", 5.0, 200.0, 1.0],
		["pawn_gold", 1.0, 80.0, 1.0],
		["chest_art", 0.0, 1.0, 0.05],
		["mine_nodes", 1.0, 16.0, 1.0],
		["wood_nodes", 1.0, 16.0, 1.0],
		["break_count", 1.0, 24.0, 1.0],
		["shrine_count", 0.0, 3.0, 1.0],
		["campfire_count", 0.0, 3.0, 1.0],
		["bag_cap", 8.0, 40.0, 1.0],
		["food_bring_max", 1.0, 40.0, 1.0],
		["food_hot_x", 5.0, 120.0, 1.0],
		["food_hot_y", 1.0, 30.0, 0.5],
		["potion_heal", 10.0, 400.0, 5.0],
		["forge_gold", 1.0, 80.0, 1.0],
		["forge_ore", 1.0, 20.0, 1.0],
		["forge_root", 0.0, 10.0, 1.0],
		["xp_keep", 0.05, 0.5, 0.01],
		["restock_gold", 0.0, 40.0, 1.0],
		["bitter_loop_offset", 0.0, 120.0, 0.01],
		["music_fade", 0.0, 3.0, 0.05],
		["playtest_scale", 1.0, 12.0, 0.5],
		["playtest_limit", 10.0, 600.0, 5.0],
	]


func getv(name: String) -> float:
	var v: Variant = get(name)
	if v is bool:
		return 1.0 if v else 0.0
	return float(v)


func setv(name: String, value: float) -> void:
	var cur: Variant = get(name)
	if cur is bool:
		set(name, value >= 0.5)
	elif cur is int:
		set(name, int(round(value)))
	else:
		set(name, value)


func apply_defense(raw: float, defense: float) -> float:
	return raw * (defense_k / (defense_k + maxf(0.0, defense)))
