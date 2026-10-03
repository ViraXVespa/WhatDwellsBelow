extends CharacterBody3D

const PlayerAnim := preload("res://scripts/world/player/player_anim.gd")
const Setup := preload("res://scripts/world/player/player_setup.gd")
const Tick := preload("res://scripts/world/player/player_tick.gd")

const ATK_NONE := 0
const ATK_BASIC := 1
const ATK_WIND := 2
const ATK_ACT := 3
const ATK_REC := 4

var aim_dir := Vector2.DOWN
var facing_key := "down"
var walk_t := 0.0
var loc_state := 0
var loc_t := 0.0
var loc_foot := 0
var loc_rev := false
var loc_from := 0
var atk_i := 0
var body: Sprite3D
var idle := {}
var walk := {}
var idle_to_walk := {}
var walk_to_idle := {}
var equip := {}
var attack := {}
var special := {}
var rig: Node3D
var telegraph
var aim_line
var iframe := 0.0
var dash_t := 0.0
var dash_cd := 0.0
var dash_dir := Vector2.DOWN
var trail_acc := 0.0
var atk_state := ATK_NONE
var atk_t := 0.0
var hit_done := false
var spec_point := Vector3.ZERO
var lock_armed := false
var lock_target: Node = null
var stick_hold := 0.0
var special_held := false
var aura: Sprite3D
var hp := 100.0
var max_hp := 100.0
var hurt_flash := 0.0
var gathering: Node = null
var gather_t := 0.0
var gather := {}
var death := {}
var dispel := {}
var exiting := false
var exit_t := 0.0
var exit_cond := ""
var exit_killer := ""
var last_hit := ""
var last_glance := false
var interact_lock := 0.0
var ui_latch := false

func _ready() -> void:
	Setup.ready(self)

func warmup() -> void:
	PlayerAnim.warmup(self)

func _load_sprites() -> void:
	PlayerAnim.load_sprites(self)

func reload_character() -> void:
	_load_sprites()
	_apply_facing(0.016)

func set_weapon(id: String) -> void:
	App.weapon = id
	_load_sprites()

func _physics_process(delta: float) -> void:
	Tick.physics(self, delta)

func is_alive() -> bool:
	return hp > 0.0

func _script_at(path: String) -> GDScript:
	return Tick._gd(path)

func take_hit(raw: float, from_dir: Vector2, crit: bool, src := "") -> void:
	_script_at("res://scripts/world/player/player_act.gd").take_hit(self, raw, from_dir, crit, src)

func heal(amount: float) -> void:
	_script_at("res://scripts/world/player/player_act.gd").heal(self, amount)

func play_exit(cond: String, killer := "") -> void:
	_script_at("res://scripts/world/player/player_act.gd").play_exit(self, cond, killer)

func start_gather(node: Node) -> void:
	_script_at("res://scripts/world/player/player_act.gd").start_gather(self, node)

func stop_gather() -> void:
	_script_at("res://scripts/world/player/player_act.gd").stop_gather(self)

func _ai_just(action: String) -> bool:
	return _script_at("res://scripts/world/player/player_lock.gd").ai_just(self, action)

func _ai_held(action: String) -> bool:
	return _script_at("res://scripts/world/player/player_lock.gd").ai_held(self, action)

func _try_dash(move: Vector2) -> void:
	_script_at("res://scripts/world/player/player_combat.gd").try_dash(self, move)

func _basic_duration() -> float:
	return _script_at("res://scripts/world/player/player_combat.gd").basic_duration()

func _hit_norm() -> float:
	return _script_at("res://scripts/world/player/player_combat.gd").hit_norm()

func _draw_basic_tele(active: bool) -> void:
	_script_at("res://scripts/combat/player_hit.gd").draw_basic_tele(self, active)

func _draw_special_tele(active: bool) -> void:
	_script_at("res://scripts/combat/player_hit.gd").draw_special_tele(self, active)

func _special_point() -> Vector3:
	return _script_at("res://scripts/combat/player_hit.gd").special_point(self)

func _apply_basic() -> void:
	_script_at("res://scripts/combat/player_hit.gd").apply_basic(self)

func _apply_special() -> void:
	_script_at("res://scripts/combat/player_hit.gd").apply_special(self)

func _trail(delta: float) -> void:
	_script_at("res://scripts/combat/player_hit.gd").trail(self, delta)

func _weapon_reach() -> float:
	return _script_at("res://scripts/world/player/player_combat.gd").weapon_reach()

func _apply_facing(delta: float) -> void:
	PlayerAnim.apply_facing(self, delta)
