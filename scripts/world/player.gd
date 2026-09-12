extends CharacterBody3D

const PlayerAnim := preload("res://scripts/world/player_anim.gd")
const PlayerHit := preload("res://scripts/combat/player_hit.gd")
const PlayerLock := preload("res://scripts/world/player_lock.gd")
const PlayerAct := preload("res://scripts/world/player_act.gd")
const PlayerCombat := preload("res://scripts/world/player_combat.gd")
const Setup := preload("res://scripts/world/player_setup.gd")
const Tick := preload("res://scripts/world/player_tick.gd")

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

func _make_sprite(prio: int) -> Sprite3D:
	return Setup.make_sprite(self, prio)

func _add_body_shape() -> void:
	Setup.add_body_shape(self)

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

func take_hit(raw: float, from_dir: Vector2, crit: bool, src := "") -> void:
	PlayerAct.take_hit(self, raw, from_dir, crit, src)

func heal(amount: float) -> void:
	PlayerAct.heal(self, amount)

func play_exit(cond: String, killer := "") -> void:
	PlayerAct.play_exit(self, cond, killer)

func start_gather(node: Node) -> void:
	PlayerAct.start_gather(self, node)

func stop_gather() -> void:
	PlayerAct.stop_gather(self)

func _tick_exit(delta: float) -> void:
	PlayerAct.tick_exit(self, delta)

func _tick_gather(delta: float, move: Vector2) -> void:
	PlayerAct.tick_gather(self, delta, move)

func _refresh_prompt() -> void:
	PlayerAct.refresh_prompt(self)

func _try_interact() -> void:
	PlayerAct.try_interact(self)

func _cooldowns(delta: float) -> void:
	PlayerAct.cooldowns(self, delta)

func _ai_on() -> bool:
	return PlayerLock.ai_on()

func _ai_or_vec(which: String) -> Vector2:
	return PlayerLock.ai_or_vec(self, which)

func _ai_just(action: String) -> bool:
	return PlayerLock.ai_just(self, action)

func _ai_held(action: String) -> bool:
	return PlayerLock.ai_held(self, action)

func _lock_and_aim(move: Vector2, delta: float) -> void:
	PlayerLock.lock_and_aim(self, move, delta)

func _try_dash(move: Vector2) -> void:
	PlayerCombat.try_dash(self, move)

func _try_special() -> void:
	PlayerCombat.try_special(self)

func _try_basic() -> void:
	PlayerCombat.try_basic(self)

func _advance_attack(delta: float) -> void:
	PlayerCombat.advance_attack(self, delta)

func _basic_duration() -> float:
	return PlayerCombat.basic_duration()

func _hit_norm() -> float:
	return PlayerCombat.hit_norm()

func _draw_basic_tele(active: bool) -> void:
	PlayerHit.draw_basic_tele(self, active)

func _draw_special_tele(active: bool) -> void:
	PlayerHit.draw_special_tele(self, active)

func _special_point() -> Vector3:
	return PlayerHit.special_point(self)

func _apply_basic() -> void:
	PlayerHit.apply_basic(self)

func _apply_special() -> void:
	PlayerHit.apply_special(self)

func _trail(delta: float) -> void:
	PlayerHit.trail(self, delta)

func _update_aim_line() -> void:
	PlayerCombat.update_aim_line(self)

func _weapon_reach() -> float:
	return PlayerCombat.weapon_reach()

func _update_aura(delta: float) -> void:
	PlayerCombat.update_aura(self, delta)

func _pose_tex(key: String) -> Texture2D:
	return PlayerAnim.pose_tex(self, key)

func _apply_tex(tex: Texture2D) -> void:
	PlayerAnim.apply_tex(self, tex)

func _apply_facing(delta: float) -> void:
	PlayerAnim.apply_facing(self, delta)
