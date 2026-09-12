extends CharacterBody3D

const EnemySetup := preload("res://scripts/combat/enemy_setup.gd")
const EnemyAI := preload("res://scripts/combat/enemy_ai.gd")
const Ready := preload("res://scripts/combat/enemy_ready.gd")
const Hit := preload("res://scripts/combat/enemy_hit.gd")
const Present := preload("res://scripts/combat/enemy_present.gd")

const ST_IDLE := 0
const ST_CHASE := 1
const ST_HUNT := 2
const ST_RETURN := 3
const ST_WIND := 4
const ST_STRIKE := 5
const ST_REC := 6
const ST_FLEE := 7

var type_id := "goblin"
var combat_lv := 1
var role := "melee"
var move_kind := "walk"
var hp := 32.0
var max_hp := 32.0
var defense := 0.0
var damage := 8.0
var move_spd := 3.0
var atk_range := 1.2
var arc_deg := 90.0
var is_boss := false
var is_named := false
var named_name := ""
var group_id := 0
var post := Vector3.ZERO
var last_seen := Vector3.ZERO
var hunt_t := 0.0
var reaggro_t := 0.0
var state := ST_IDLE
var aim := Vector2.DOWN
var locked_aim := Vector2.DOWN
var wind_t := 0.0
var rec_t := 0.0
var hop_t := 0.0
var bob_t := 0.0
var stuck_t := 0.0
var last_pos := Vector3.ZERO
var flash := 0.0
var stagger := 0.0
var knock := Vector3.ZERO
var knock_t := 0.0
var dead := false
var spr: Sprite3D
var tag: Label3D
var bang: Label3D
var telegraph
var base_mod := Color.WHITE
var size_u := 1.5
var idle_t := 0.0
var wander_dir := Vector2.RIGHT
var flee_t := 0.0
var spawned_help := false
var spec_point := Vector3.ZERO
var wind_dur := 0.42
var last_glance := false
var los_ok := false
var los_t := 0.0



func _ready() -> void:
	Ready.ready(self)


func setup(id: String, floor_n: int, named := false, given_name := "") -> void:
	EnemySetup.setup(self, id, floor_n, named, given_name)


func setup_boss(title: String, floor_n: int) -> void:
	EnemySetup.setup_boss(self, title, floor_n)


func setup_guard(id: String, floor_n: int) -> void:
	setup(id, floor_n, false, "")


func _mark_post() -> void:
	Hit.mark_post(self)


func take_hit(raw: float, from_dir: Vector2, crit: bool) -> void:
	Hit.take_hit(self, raw, from_dir, crit)


func apply_stagger(sec: float) -> void:
	Hit.apply_stagger(self, sec)


func _float(amount: int, crit: bool) -> void:
	Hit.float_num(self, amount, crit)


func _die() -> void:
	Hit.die(self)


func force_kill() -> void:
	hp = 0.0
	_die()


func is_alive() -> bool:
	return not dead and hp > 0.0


func start_flee() -> void:
	EnemyAI.start_flee(self)


func _physics_process(delta: float) -> void:
	Present.physics(self, delta)


func _present(delta: float) -> void:
	Present.present(self, delta)


func kill_tag() -> String:
	if is_boss:
		var title := str(tag.text) if tag else ""
		return "gate_master" if title.begins_with("Gate Master") else "guardian"
	return type_id


func _drop_loot() -> void:
	Hit.drop_loot(self)


func _player() -> Node3D:
	var tree := get_tree()
	if tree == null:
		return null
	var n := tree.get_first_node_in_group("player")
	if n is Node3D:
		return n
	return null


func state_name() -> String:
	match state:
		ST_IDLE:
			return "idle"
		ST_CHASE:
			return "chase"
		ST_HUNT:
			return "hunt"
		ST_RETURN:
			return "return"
		ST_WIND:
			return "windup"
		ST_STRIKE:
			return "strike"
		ST_REC:
			return "recover"
		ST_FLEE:
			return "flee"
		_:
			return "unk"
