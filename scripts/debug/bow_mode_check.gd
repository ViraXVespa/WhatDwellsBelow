extends RefCounted

## Bow mode probe (dungeon-bow-mode flow, pad scheme). Press getters act and return "ok"; checks return "" or the
## first fault. .setup: longbow, Bow mode off, aim line off, inputs released. Off: .fire_idle (RT does not shoot)
## and .attack_shoots (X does). On: .fire_shoots (RT shoots). .stick_right then .aim_walk_down: the right stick
## aims right, then holding Aim while walking down must keep the aim right (no turn to the walk), slow the walk and
## show the aim line with the setting off: .aiming. .axe: with a melee weapon Bow mode is inert (.fire_idle).
## Planted: Bow mode off makes .fire_shoots and .aiming report a fault (.plant_off).

const BowMode := preload("res://scripts/world/bow_mode.gd")

const INPUTS: PackedStringArray = ["fire", "attack", "aim", "aim_right", "move_down"]

static func _p() -> Node:
	var tree := Engine.get_main_loop() as SceneTree
	return tree.get_first_node_in_group("player") if tree else null

static func _release() -> void:
	for a: String in INPUTS:
		Input.action_release(a)

var setup: String:
	get:
		_release()
		_p().set_weapon("longbow")
		BowMode.enabled = false
		App.bal.aim_line_on = false
		return "ok"
var bow_on: String:
	get:
		BowMode.enabled = true
		return "ok"
var plant_off: String:
	get:
		BowMode.enabled = false
		return "ok"
var axe: String:
	get:
		_release()
		_p().set_weapon("great_axe")
		BowMode.enabled = true
		return "ok"
var release: String:
	get:
		_release()
		return "ok"
var press_fire: String:
	get:
		Input.action_press("fire")
		return "ok"
var press_attack: String:
	get:
		Input.action_press("attack")
		return "ok"
var stick_right: String:
	get:
		_release()
		Input.action_press("aim_right")
		return "ok"
var aim_walk_down: String:
	get:
		Input.action_release("aim_right")
		Input.action_press("aim")
		Input.action_press("move_down")
		return "ok"
var fire_idle: String:
	get:
		var p := _p()
		var st: int = int(p.atk_state)
		_release()
		return "" if st == int(p.ATK_NONE) else "fire: %s shot with Bow mode %s (atk_state %d)" % [App.weapon, BowMode.enabled, st]
var attack_shoots: String:
	get:
		return _shooting("attack")
var fire_shoots: String:
	get:
		return _shooting("fire")
var aiming: String:
	get:
		var p := _p()
		var d: Vector2 = p.aim_dir
		var v := Vector2(p.velocity.x, p.velocity.z).length()
		var cap: float = float(App.bal.move_speed) * (1.0 + App.gear("move_spd")) * float(App.bal.attack_move_mult) * 1.1
		var line_on: bool = p.aim_line != null and bool(p.aim_line.visible)
		_release()
		if not BowMode.aiming() and d.x < 0.9:
			return "aim: not aiming (aim_dir %s turned to the walk)" % d
		if d.x < 0.9:
			return "aim: aim_dir %s followed the walk" % d
		if v > cap:
			return "aim: walk %.2f not slowed (cap %.2f)" % [v, cap]
		if not line_on:
			return "aim: aim line hidden while aiming"
		return ""

static func _shooting(what: String) -> String:
	var p := _p()
	var st: int = int(p.atk_state)
	_release()
	return "" if st != int(p.ATK_NONE) else "%s: no shot with Bow mode %s (atk_state %d)" % [what, BowMode.enabled, st]
