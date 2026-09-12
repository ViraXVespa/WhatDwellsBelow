extends Object

const PlaytestLog := preload("res://scripts/debug/playtest_log.gd")
const Util := preload("res://scripts/debug/playtest_ai_util.gd")
const Act := preload("res://scripts/debug/playtest_ai_act.gd")
const Goals := preload("res://scripts/debug/playtest_goals.gd")
const NEAR := 22.0
const SEE := 28.0
const CLOSE := 2.4
const START := 24.0
const GATHER := 9.0
const Core := preload("res://scripts/debug/playtest_ai_core.gd")
const Misc := preload("res://scripts/debug/playtest_ai_misc.gd")

static func weapon_range() -> float:
	return Util.weapon_range()

static func is_boss(n: Node) -> bool:
	return Util.is_boss(n)

static func alive_enemy(n: Node) -> bool:
	return Util.alive_enemy(n)

static func notice_range(pt: Node) -> float:
	return Util.notice_range(pt)

static func try_staff_special(pt: Node, d: float, los: bool) -> void:
	Util.try_staff_special(pt, d, los)

static func fight(pt: Node, p: Node, enemy: Node) -> void:
	Act.fight(pt, p, enemy)

static func approach_boss(pt: Node, p: Node, boss: Node) -> void:
	Act.approach_boss(pt, p, boss)

static func wander(pt: Node, p: Node, delta: float) -> void:
	Util.wander(pt, p, delta)

static func use_prop(pt: Node, p: Node, dest: Node, _reach: float = 1.18) -> void:
	Misc.use_prop(pt, p, dest, _reach)

static func _mark_pad(pt: Node, n: Node, w: int = 1) -> void:
	if n == null or not is_instance_valid(n):
		return
	var c: Vector2i = pt._cell_of_node(n)
	var m: Dictionary = Util._seen(pt)
	for x: int in range(-2, 3):
		for y: int in range(-2, 3):
			var k: Vector2i = c + Vector2i(x, y)
			m[k] = int(m.get(k, 0)) + w
	pt.set_meta("seen_map", m)

static func _is_junk(pt: Node, n: Node) -> bool:
	return Misc._is_junk(pt, n)

static func _usable_local(pt: Node, p: Node, lim: float) -> Node:
	return Misc._usable_local(pt, p, lim)

static func _wants_clerk(pt: Node, n: Node) -> bool:
	return Misc._wants_clerk(pt, n)

static func _done_with_clerk(pt: Node, n: Node) -> void:
	Misc._done_with_clerk(pt, n)

static func _clear_lock(pt: Node) -> void:
	Misc._clear_lock(pt)

static func _mail_if_close(pt: Node, p: Node, clerk: Node) -> bool:
	return Misc._mail_if_close(pt, p, clerk)

static func _engage(pt: Node, p: Node, foe: Node, why: String) -> void:
	Misc._engage(pt, p, foe, why)

static func _leave_crystal(pt: Node, p: Node, crystal: Node) -> void:
	Misc._leave_crystal(pt, p, crystal)

static func think(pt: Node, p: Node, delta: float) -> void:
	Core.think(pt, p, delta)
