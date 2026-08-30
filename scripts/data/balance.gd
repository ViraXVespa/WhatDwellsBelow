extends RefCounted

## All Phase 2 combat numbers. Mutated by the secret debug menu.
## Bump BAL_REV when shipping new defaults that old saves should receive.
const BAL_REV := 5

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

var gen_w := 216
var gen_h := 216
var gen_rooms := 36
var gen_room_min := 5
var gen_room_max := 9
var gen_extra_loops := 8
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
var enemy_cl_per_floor := 20.0
var enemy_cl_end_pct := 0.86
var enemy_cl_jitter := 2.0
var enemy_cl_dmg := 0.018
var enemy_cl_gear_dmg := 0.012
var enemy_cl_hp := 0.010
var enemy_cl_gear_hp := 0.016
var enemy_cl_def := 0.4
var enemy_cl_gear_def := 0.3
var cl_dealt_up := 1.15
var cl_dealt_down := 0.85
var cl_received_up := 0.85
var cl_received_down := 1.15
var cl_xp_up := 1.1
var cl_xp_down := 0.9
var cl_style_weight := 0.5
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
var mine_nodes := 18
var wood_nodes := 14
var break_count := 24
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
var forge_time := 2.0
var xp_keep := 0.2
var restock_gold := 8.0
var restock_potion := 2.0
var restock_food := 3.0
var potion_cooldown := 1.2
var vendor_potion_cost := 15.0
var vendor_food_cost := 8.0
var vendor_ore_gold := 3.0
var bitter_loop_offset := 15.52
var music_fade := 0.35
var playtest_scale := 6.0
var playtest_limit := 90.0

var xp_level := 100.0
var xp_double_every := 14.0
var xp_hit_weapon := 1.2
var xp_hit_style := 0.8
var xp_gather := 6.0
var xp_smith := 12.0
var xp_def_hit := 0.4
var xp_hp_heal := 0.15
var skill_dmg_weapon := 0.04
var skill_dmg_style := 0.03
var skill_special_bonus := 0.02
var skill_def_per_lv := 1.5
var skill_hp_per_lv := 4.0

var gear_white_dmg := 2.0
var gear_green_dmg := 5.0
var gear_blue_dmg := 9.0
var gear_white_def := 2.0
var gear_green_def := 5.0
var gear_blue_def := 9.0
var gear_white_hp := 4.0
var gear_green_hp := 10.0
var gear_blue_hp := 18.0

var enemy_gear_chance := 0.12
var enemy_gear_floor := 0.02
var enemy_gear_green := 0.18
var enemy_gold_base := 1.0
var enemy_gold_span := 2.0
var boss_gold_extra := 6.0
var chest_gold_base := 8.0
var chest_gold_span := 12.0
var boss_chest_gold := 20.0
var boss_blue_chance := 0.45
var chest_green_chance := 0.35
var chest_gear_chance := 0.55

var shop_stock_min := 2.0
var shop_stock_max := 4.0
var shop_buy_max := 2.0

var quest_kill_need := 4.0
var quest_ore_need := 8.0
var quest_gold := 25.0
var quest_xp_a := 24.0
var quest_xp_b := 16.0

var near_death_hp := 0.2
var cam_pitch := -58.0
var cam_height := 14.0
var look_lift := 0.42

var set_cinder_1 := 1.0
var set_cinder_2 := 3.0
var set_tide_1 := 4.0
var set_tide_2 := 8.0
var set_root_1 := 0.03
var set_root_2 := 0.06
var set_root_3 := 0.08
var set_ash_1 := 1.5
var set_ash_2 := 4.0
var set_ash_3 := 6.0
var set_spark_1 := 0.03
var set_spark_2 := 0.06
var set_bone_1 := 3.0
var set_bone_2 := 6.0
var set_bone_3 := 10.0
var set_veil_1 := 0.04
var set_veil_2 := 0.08
var set_veil_3 := 0.08
var set_veil_4 := 0.12
var set_iron_1 := 2.0
var set_iron_2 := 5.0
var set_iron_3 := 5.0
var set_iron_4 := 6.0
var set_iron_5 := 10.0

const ENEMY_IDS: PackedStringArray = [
	"slime", "goblin", "orc", "skeleton", "bat", "spider",
	"archer", "shaman", "imp", "wolf", "beetle", "wisp",
]
var enemy_stats: Dictionary = {}


func schema() -> Array:
	var rows := [
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
		["gen_w", 24.0, 256.0, 1.0],
		["gen_h", 24.0, 256.0, 1.0],
		["gen_rooms", 6.0, 80.0, 1.0],
		["gen_room_min", 4.0, 10.0, 1.0],
		["gen_room_max", 5.0, 16.0, 1.0],
		["gen_extra_loops", 0.0, 40.0, 1.0],
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
		["enemy_cl_per_floor", 5.0, 40.0, 1.0],
		["enemy_cl_end_pct", 0.7, 0.96, 0.01],
		["enemy_cl_jitter", 0.0, 6.0, 1.0],
		["enemy_cl_dmg", 0.0, 0.08, 0.001],
		["enemy_cl_gear_dmg", 0.0, 0.08, 0.001],
		["enemy_cl_hp", 0.0, 0.08, 0.001],
		["enemy_cl_gear_hp", 0.0, 0.08, 0.001],
		["enemy_cl_def", 0.0, 4.0, 0.05],
		["enemy_cl_gear_def", 0.0, 4.0, 0.05],
		["cl_dealt_up", 1.0, 2.0, 0.01],
		["cl_dealt_down", 0.4, 1.0, 0.01],
		["cl_received_up", 0.4, 1.0, 0.01],
		["cl_received_down", 1.0, 2.0, 0.01],
		["cl_xp_up", 1.0, 2.0, 0.01],
		["cl_xp_down", 0.4, 1.0, 0.01],
		["cl_style_weight", 0.0, 1.0, 0.05],
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
		["mine_nodes", 1.0, 40.0, 1.0],
		["wood_nodes", 1.0, 40.0, 1.0],
		["break_count", 1.0, 48.0, 1.0],
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
		["forge_time", 0.2, 8.0, 0.1],
		["xp_keep", 0.05, 0.5, 0.01],
		["restock_gold", 0.0, 40.0, 1.0],
		["restock_potion", 0.0, 10.0, 1.0],
		["restock_food", 0.0, 20.0, 1.0],
		["potion_cooldown", 0.0, 8.0, 0.1],
		["vendor_potion_cost", 1.0, 80.0, 1.0],
		["vendor_food_cost", 1.0, 80.0, 1.0],
		["vendor_ore_gold", 1.0, 40.0, 1.0],
		["bitter_loop_offset", 0.0, 120.0, 0.01],
		["music_fade", 0.0, 3.0, 0.05],
		["playtest_scale", 1.0, 12.0, 0.5],
		["playtest_limit", 10.0, 600.0, 5.0],
		["xp_level", 10.0, 400.0, 1.0],
		["xp_double_every", 4.0, 40.0, 1.0],
		["xp_hit_weapon", 0.0, 20.0, 0.1],
		["xp_hit_style", 0.0, 20.0, 0.1],
		["xp_gather", 0.0, 40.0, 0.5],
		["xp_smith", 0.0, 40.0, 0.5],
		["xp_def_hit", 0.0, 8.0, 0.05],
		["xp_hp_heal", 0.0, 8.0, 0.05],
		["skill_dmg_weapon", 0.0, 0.2, 0.005],
		["skill_dmg_style", 0.0, 0.2, 0.005],
		["skill_special_bonus", 0.0, 0.2, 0.005],
		["skill_def_per_lv", 0.0, 12.0, 0.1],
		["skill_hp_per_lv", 0.0, 20.0, 0.5],
		["gear_white_dmg", 0.0, 40.0, 1.0],
		["gear_green_dmg", 0.0, 40.0, 1.0],
		["gear_blue_dmg", 0.0, 40.0, 1.0],
		["gear_white_def", 0.0, 40.0, 1.0],
		["gear_green_def", 0.0, 40.0, 1.0],
		["gear_blue_def", 0.0, 40.0, 1.0],
		["gear_white_hp", 0.0, 60.0, 1.0],
		["gear_green_hp", 0.0, 60.0, 1.0],
		["gear_blue_hp", 0.0, 60.0, 1.0],
		["enemy_gear_chance", 0.0, 1.0, 0.01],
		["enemy_gear_floor", 0.0, 0.2, 0.005],
		["enemy_gear_green", 0.0, 1.0, 0.01],
		["enemy_gold_base", 0.0, 20.0, 1.0],
		["enemy_gold_span", 1.0, 20.0, 1.0],
		["boss_gold_extra", 0.0, 40.0, 1.0],
		["chest_gold_base", 0.0, 40.0, 1.0],
		["chest_gold_span", 1.0, 40.0, 1.0],
		["boss_chest_gold", 0.0, 80.0, 1.0],
		["boss_blue_chance", 0.0, 1.0, 0.05],
		["chest_green_chance", 0.0, 1.0, 0.05],
		["chest_gear_chance", 0.0, 1.0, 0.05],
		["shop_stock_min", 1.0, 6.0, 1.0],
		["shop_stock_max", 1.0, 8.0, 1.0],
		["shop_buy_max", 1.0, 6.0, 1.0],
		["quest_kill_need", 1.0, 20.0, 1.0],
		["quest_ore_need", 1.0, 40.0, 1.0],
		["quest_gold", 0.0, 200.0, 1.0],
		["quest_xp_a", 0.0, 80.0, 1.0],
		["quest_xp_b", 0.0, 80.0, 1.0],
		["near_death_hp", 0.05, 0.6, 0.05],
		["cam_pitch", -80.0, -20.0, 1.0],
		["cam_height", 4.0, 40.0, 0.5],
		["look_lift", 0.0, 2.0, 0.02],
		["set_cinder_1", 0.0, 20.0, 0.5],
		["set_cinder_2", 0.0, 20.0, 0.5],
		["set_tide_1", 0.0, 20.0, 0.5],
		["set_tide_2", 0.0, 40.0, 0.5],
		["set_root_1", 0.0, 0.2, 0.005],
		["set_root_2", 0.0, 0.2, 0.005],
		["set_root_3", 0.0, 0.2, 0.005],
		["set_ash_1", 0.0, 20.0, 0.5],
		["set_ash_2", 0.0, 20.0, 0.5],
		["set_ash_3", 0.0, 20.0, 0.5],
		["set_spark_1", 0.0, 0.3, 0.01],
		["set_spark_2", 0.0, 0.3, 0.01],
		["set_bone_1", 0.0, 20.0, 0.5],
		["set_bone_2", 0.0, 20.0, 0.5],
		["set_bone_3", 0.0, 40.0, 0.5],
		["set_veil_1", 0.0, 0.4, 0.01],
		["set_veil_2", 0.0, 0.4, 0.01],
		["set_veil_3", 0.0, 0.4, 0.01],
		["set_veil_4", 0.0, 0.4, 0.01],
		["set_iron_1", 0.0, 20.0, 0.5],
		["set_iron_2", 0.0, 20.0, 0.5],
		["set_iron_3", 0.0, 20.0, 0.5],
		["set_iron_4", 0.0, 20.0, 0.5],
		["set_iron_5", 0.0, 40.0, 0.5],
	]
	_ensure_enemies()
	for id in ENEMY_IDS:
		rows.append(["e_%s_hp" % id, 5.0, 200.0, 1.0])
		rows.append(["e_%s_dmg" % id, 1.0, 80.0, 1.0])
		rows.append(["e_%s_spd" % id, 0.4, 8.0, 0.05])
		rows.append(["e_%s_range" % id, 0.4, 12.0, 0.05])
		rows.append(["e_%s_def" % id, 0.0, 40.0, 1.0])
	return rows


func _init() -> void:
	_ensure_enemies()


func _ensure_enemies() -> void:
	if not enemy_stats.is_empty():
		return
	enemy_stats = {
		"slime": {"hp": 24.0, "dmg": 6.0, "spd": 2.2, "range": 0.95, "def": 2.0},
		"goblin": {"hp": 32.0, "dmg": 8.0, "spd": 3.15, "range": 1.15, "def": 1.0},
		"orc": {"hp": 58.0, "dmg": 12.0, "spd": 2.05, "range": 1.35, "def": 8.0},
		"skeleton": {"hp": 36.0, "dmg": 9.0, "spd": 2.7, "range": 1.2, "def": 3.0},
		"bat": {"hp": 20.0, "dmg": 7.0, "spd": 4.05, "range": 0.9, "def": 0.0},
		"spider": {"hp": 28.0, "dmg": 8.0, "spd": 3.25, "range": 1.05, "def": 2.0},
		"archer": {"hp": 26.0, "dmg": 7.0, "spd": 2.85, "range": 6.2, "def": 1.0},
		"shaman": {"hp": 30.0, "dmg": 11.0, "spd": 2.35, "range": 3.4, "def": 2.0},
		"imp": {"hp": 22.0, "dmg": 10.0, "spd": 3.55, "range": 4.2, "def": 0.0},
		"wolf": {"hp": 34.0, "dmg": 10.0, "spd": 3.85, "range": 1.1, "def": 2.0},
		"beetle": {"hp": 52.0, "dmg": 9.0, "spd": 1.85, "range": 1.05, "def": 10.0},
		"wisp": {"hp": 18.0, "dmg": 8.0, "spd": 2.95, "range": 5.4, "def": 0.0},
	}


func _enemy_key(name: String) -> Array:
	if not name.begins_with("e_"):
		return []
	var cut := name.substr(2)
	var us := cut.rfind("_")
	if us <= 0:
		return []
	return [cut.substr(0, us), cut.substr(us + 1)]


func getv(name: String) -> float:
	var ek := _enemy_key(name)
	if ek.size() == 2:
		_ensure_enemies()
		var id := str(ek[0])
		var key := str(ek[1])
		if enemy_stats.has(id) and (enemy_stats[id] as Dictionary).has(key):
			return float((enemy_stats[id] as Dictionary)[key])
		return 0.0
	var v: Variant = get(name)
	if v is bool:
		return 1.0 if v else 0.0
	if v == null:
		return 0.0
	return float(v)


func migrate_from(old_rev: int) -> bool:
	if old_rev >= BAL_REV:
		return false
	if old_rev < 2:
		gen_w = 216
		gen_h = 216
		gen_rooms = 36
		gen_extra_loops = 8
		mine_nodes = 18
		wood_nodes = 14
		break_count = 24
	if old_rev < 3:
		xp_double_every = 14.0
		xp_level = 100.0
	if old_rev < 4:
		enemy_cl_per_floor = 20.0
		enemy_cl_end_pct = 0.86
		enemy_cl_jitter = 2.0
		enemy_cl_dmg = 0.018
		enemy_cl_gear_dmg = 0.012
		enemy_cl_hp = 0.010
		enemy_cl_gear_hp = 0.016
		enemy_cl_def = 0.4
		enemy_cl_gear_def = 0.3
	return true


func setv(name: String, value: float) -> void:
	var ek := _enemy_key(name)
	if ek.size() == 2:
		_ensure_enemies()
		var id := str(ek[0])
		var key := str(ek[1])
		if not enemy_stats.has(id):
			enemy_stats[id] = {}
		(enemy_stats[id] as Dictionary)[key] = value
		return
	var cur: Variant = get(name)
	if cur is bool:
		set(name, value >= 0.5)
	elif cur is int:
		set(name, int(round(value)))
	else:
		set(name, value)


func snapshot() -> Dictionary:
	var d := {}
	for row in schema():
		d[str(row[0])] = getv(str(row[0]))
	return d


func apply_defense(raw: float, defense: float) -> float:
	return raw * (defense_k / (defense_k + maxf(0.0, defense)))
