extends "res://scripts/data/balance/vars_main.gd"

## Combat tunables (design/tunables-combat.md). One link of the balance vars chain (vars.gd aggregates).

var move_speed := T.MOVE_SPEED
var dash_speed_mult := 2.8
var dash_duration := 0.28
var dash_cooldown := 1.1
var special_windup := 0.22
var special_recovery := 1.5
var special_mana := 20.0
var mana_max := 100.0
var mana_regen := 3.0
var attack_move_mult := 0.45

var axe_damage := 16.0
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
var bow_path_width := 0.12
var arrow_tip_radius := 0.28

var cover_cols := 24.0
var cover_rings := 8.0
var cover_arcs := 14.0
var cover_alpha := 0.4
var cover_min_half := 0.08
var cover_edge_mult := 0.35
var cover_full := 0.18

var crit_chance := 0.12
var crit_mult := 2.0
var knockback := 3.4
var hitstop := 0.055
var dummy_hp := 80.0
var dummy_defense := 0.0
var defense_k := 100.0

var adrenaline_window := 4.5
var adrenaline_kills := 4
var adrenaline_speed := 1.35
var adrenaline_xp_stack := 0.15
var adrenaline_xp_max := 2.0
var adrenaline_timeout := 4.5

var aim_line_on: bool = Pref.DEF.aim_line_on
var aim_line_opacity: float = Pref.DEF.aim_line_opacity
var aim_line_width := 0.08
var aim_line_use_weapon_range := true
var aim_line_length := 4.0

var lock_stick_delay := 0.18
var lock_stick_deadzone := 0.42
var atk_fps := 10.0

var trail_gap := 0.045
var trail_life := 0.22

var player_max_hp := 100.0
var player_hurt_iframe := 0.35

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
var snack_heal := 22.0
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
var potion_hold_max := 3.0
var potion_charges_min := 1.0
var potion_charges_max := 4.0
var potion_heal_min := 40.0
var potion_heal_max := 140.0
var potion_cd_min := 4.0
var potion_cd_max := 12.0
var potion_speed_min := 0.0
var potion_speed_max := 6.0
var potion_bonus_chance := 0.35
var potion_bonus_secs_min := 3.0
var potion_bonus_secs_max := 6.0
var potion_bonus_flat := 2.0
var potion_bonus_pct := 0.04
var food_kind_max := 6.0
var food_ration_heal := 40.0
var food_ration_secs := 8.0
var food_ration_bonus := 1.0
var food_bread_heal := 28.0
var food_bread_secs := 12.0
var food_bread_bonus := 0.05
var food_stew_heal := 56.0
var food_stew_secs := 6.0
var food_stew_bonus := 4.0
var food_moldy_heal := 14.0
var food_moldy_secs := 8.0
var food_moldy_bonus := 0.0
var potion_mana := 40.0
var food_ration_mana := 20.0
var food_bread_mana := 15.0
var food_stew_mana := 30.0
var food_moldy_mana := 8.0

var enemy_gear_chance := 0.0171
var enemy_gear_floor := 0.00286
var enemy_gear_green := 0.18
var enemy_gold_base := 1.0
var enemy_gold_span := 2.0
var boss_gold_extra := 6.0
## Enemy kill drops, rolled independently (user-set, design/tunables.md "Enemy drops"). Bosses always drop gold.
var enemy_gold_chance := 0.25
var enemy_orb_chance := 0.06
## Mana orb. Chance and amount. Pickup restores App.prog mana (design/tasks/metal-hud-mana.md).
var enemy_mana_chance := 0.06
var orb_mana := 25.0
var chest_gold_base := 8.0
var chest_gold_span := 12.0
var boss_chest_gold := 20.0
var boss_blue_chance := 0.45
var chest_green_chance := 0.35
var chest_gear_chance := 0.55

var near_death_hp := 0.2
