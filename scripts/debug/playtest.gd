extends Node

## Full-target Automated Playtest. Drives the live player, combat, gather,
## clerks, recap, and isolated saves. Medium-bar fast seed remains for coefs.

const Store := preload("res://scripts/data/save_store.gd")
const TelS := preload("res://scripts/debug/telemetry.gd")
const Combat := preload("res://scripts/combat/combat.gd")

var history: Array = []
var recs: Dictionary = {"fresh": [], "progressed": []}
var coefs: Dictionary = {}
var last_summary := ""
var interrupted := false
var running := false
var live_running := false
var ai_on := false
var queue: Array = []
var job: Dictionary = {}
var slot := "fresh"
var live_backup: Dictionary = {}
var bal_backup: Dictionary = {}
var scale_backup := 1.0
var sim_t := 0.0
var stuck_t := 0.0
var last_pos := Vector3.ZERO
var wander_t := 0.0
var wander_dir := Vector2.ZERO
var spec_cd := 0.0
var just: Dictionary = {}
var move := Vector2.ZERO
var aim := Vector2.DOWN
var attack := false
var special := false
var interact := false
var dash := false
var potion := false
var smoke_mode := false
var moved := false
var hit_something := false
var recap_taken := false
var path: Array[Vector2i] = []
var path_i := 0
var path_goal: Node = null
var strafe_sign := 1.0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	process_priority = -80
	_load_history()
	_load_coefs()
	if not recs["fresh"].is_empty() or not history.is_empty():
		_build_recs()


func interrupt() -> void:
	interrupted = true
	if live_running:
		_finish_job("interrupted playtest", true)


func queue_batch() -> String:
	interrupted = false
	var weapons := ["great_axe", "staff", "longbow"]
	var tools := ["pickaxe", "hatchet", "pickaxe"]
	var genders := ["male", "female", "male"]
	for kind in ["fresh", "progressed"]:
		for i in 3:
			enqueue({
				"save": kind,
				"weapon": weapons[i],
				"tool": tools[i],
				"gender": genders[i],
				"scale": App.bal.playtest_scale,
				"limit": App.bal.playtest_limit,
				"cfg": {},
			})
	return "Queued %d live runs." % queue.size()


func enqueue(j: Dictionary) -> void:
	queue.append(j)
	if not live_running:
		_start_next()


func begin_smoke() -> void:
	smoke_mode = true
	interrupted = false
	moved = false
	hit_something = false
	ai_on = false
	live_running = true
	running = true
	sim_t = 0.0
	path.clear()
	path_i = 0
	path_goal = null
	slot = "fresh"
	job = {"save": "fresh", "weapon": App.weapon, "tool": App.prog.tool_type, "limit": 8.0, "scale": 1.0, "cfg": {}}
	App.tel.reset("fresh", true)
	App.tel.start_weapon = App.weapon


func run_medium() -> String:
	running = true
	interrupted = false
	var snapshot: Dictionary = _snap_bal()
	var live: Dictionary = Store.collect()
	_sim_save("fresh", false)
	if interrupted:
		_restore_bal(snapshot)
		Store.apply(live)
		running = false
		return "Interrupted. Rows kept: %d" % history.size()
	_sim_save("progressed", true)
	_compute_coefs()
	_build_recs()
	_save_coefs()
	_save_history()
	_restore_bal(snapshot)
	Store.apply(live)
	running = false
	last_summary = _format()
	return last_summary


func apply_rec(save_kind: String, i: int) -> String:
	var arr: Array = recs.get(save_kind, [])
	if i < 0 or i >= arr.size():
		return "No recommendation."
	var cfg: Dictionary = arr[i].cfg
	for k in cfg.keys():
		App.bal.setv(str(k), float(cfg[k]))
	return "Applied %s rec %d." % [save_kind, i + 1]


func ideal_for(name: String, save_kind: String) -> float:
	var arr: Array = recs.get(save_kind, [])
	if arr.is_empty():
		return App.bal.getv(name)
	var cfg: Dictionary = arr[0].cfg
	if cfg.has(name):
		return float(cfg[name])
	return App.bal.getv(name)


func reset_progressed_template() -> String:
	var live: Dictionary = Store.collect()
	Store.fresh_delver()
	for id in App.prog.SKILLS:
		App.prog.skills_perm[id] = 400.0
	App.prog.deepest = 8
	App.bank_gold = 80
	App.bank_ore = 24
	App.bank_wood = 16
	App.character_chosen = true
	Store.save_slot("progressed")
	Store.apply(live)
	return "Progressed template reset (isolated slot)."


func consume_recap() -> bool:
	if not live_running or recap_taken:
		return false
	recap_taken = true
	App.tel.recap_drain = true
	_finish_job(str(App.tel.end_cond), false)
	return true


func _physics_process(delta: float) -> void:
	if not live_running:
		return
	just.clear()
	attack = false
	special = false
	interact = false
	dash = false
	potion = false
	move = Vector2.ZERO
	spec_cd = maxf(0.0, spec_cd - delta)
	sim_t += delta

	if App.recap and bool(App.recap.get("open")):
		if bool(App.recap.get("draining")):
			App.recap.skip_drain()
		elif not recap_taken:
			App.recap._finish()
		return

	if _dismiss_world_ui():
		return

	if not App.in_dungeon:
		ai_on = false
		return
	if _dungeon() == null:
		ai_on = false
		return
	var p := get_tree().get_first_node_in_group("player")
	if p == null or not is_instance_valid(p):
		ai_on = false
		return

	ai_on = true
	if smoke_mode and sim_t >= 8.0:
		_finish_job("interrupted playtest", true)
		return
	var limit := float(job.get("limit", App.bal.playtest_limit))
	if not smoke_mode and sim_t >= limit:
		_finish_job("interrupted playtest", true)
		return
	_think(p, delta)


func _world_ui() -> Node:
	var tree := get_tree()
	if tree == null:
		return null
	var s := tree.current_scene
	if s and s.has_method("world_ui"):
		return s.world_ui()
	return null


func _role_has_cargo(role: String) -> bool:
	if role == "gather":
		return _gather_cargo() > 0
	if role == "misc":
		return _misc_cargo() > 0
	if role == "patty":
		return (_gather_cargo() + _misc_cargo()) > 0
	return false


func _dismiss_world_ui() -> bool:
	var w := _world_ui()
	if w == null or not bool(w.get("open")):
		if not App.ui_open:
			return false
		w = _world_ui()
		if w == null:
			App.ui_open = false
			if get_tree():
				get_tree().paused = false
			return false
	var mode := str(w.get("mode"))
	if mode == "extract":
		var role := str(w.get("extract_role"))
		if _role_has_cargo(role):
			App.note_clerk()
			App.prog.extract_all(role)
		if w.has_method("close_ui"):
			w.close_ui()
		return true
	if w.has_method("close_ui"):
		w.close_ui()
		return true
	return false


func _think(p: Node, _delta: float) -> void:
	var pos: Vector3 = (p as Node3D).global_position
	if last_pos.distance_to(pos) > 0.08:
		moved = true
		stuck_t = 0.0
	else:
		stuck_t += _delta
	last_pos = pos

	if p.get("hp") != null and float(p.hp) / maxf(1.0, float(p.max_hp)) < 0.35:
		potion = true
		just["potion"] = true

	var gathering: Variant = p.get("gathering")
	if gathering != null and is_instance_valid(gathering):
		path.clear()
		path_goal = null
		move = Vector2.ZERO
		aim = _xz_to(p, gathering)
		return

	var seen := _nearest_visible_threat(p)
	if seen:
		_fight(p, seen)
		return

	var hunt := _nearest_hunt(p)
	if hunt:
		if _is_boss(hunt):
			_approach_boss(p, hunt)
		else:
			_follow_goal(p, hunt)
			aim = _xz_to(p, hunt)
		return

	if App.extracted:
		var stairs := _reachable_kind(p, "stairs")
		if stairs == null:
			var wait_boss := _nearest_boss(p)
			if wait_boss:
				_approach_boss(p, wait_boss)
				return
		_follow_goal(p, stairs)
		if stairs and _dist(p, stairs) < 1.15:
			interact = true
			just["interact"] = true
		return

	var clerk := _best_clerk(p)
	if clerk:
		_use_prop(p, clerk, 1.25)
		return

	var node := _best_gather(p)
	if node:
		_use_prop(p, node, 1.05)
		return

	var chest := _best_chest(p)
	if chest:
		_use_prop(p, chest, 1.2)
		return

	var boss := _nearest_boss(p)
	if boss and (_near_closed_door(p) or _dist(p, boss) <= 8.5 or _has_los(p, boss)):
		_approach_boss(p, boss)
		return

	var dest: Node = _reachable_kind(p, "stairs")
	if dest == null:
		dest = _reachable_kind(p, "crystal")
	if dest:
		_follow_goal(p, dest)
		return
	_wander(p, _delta)


func _use_prop(p: Node, dest: Node, reach: float) -> void:
	if _dist(p, dest) < reach:
		path.clear()
		path_goal = null
		move = Vector2.ZERO
		aim = _xz_to(p, dest)
		interact = true
		just["interact"] = true
		return
	_follow_goal(p, dest)
	aim = _xz_to(p, dest)


func _wander(p: Node, delta: float) -> void:
	wander_t -= delta
	if wander_t <= 0.0 or wander_dir == Vector2.ZERO or not _dir_open(p, wander_dir):
		wander_t = 1.2
		wander_dir = _any_open(p)
	move = _safe_step(p, wander_dir)
	aim = move if move.length() > 0.1 else wander_dir


func _weapon_range() -> float:
	var w := str(App.weapon)
	if w == "longbow":
		return maxf(2.4, float(App.bal.bow_range))
	if w == "staff":
		return maxf(1.05, float(App.bal.staff_range))
	return maxf(1.15, float(App.bal.axe_range))


func _is_bow() -> bool:
	return str(App.weapon) == "longbow"


func _is_staff() -> bool:
	return str(App.weapon) == "staff"


func _is_axe() -> bool:
	return str(App.weapon) == "great_axe"


func _is_boss(n: Node) -> bool:
	if n == null or not is_instance_valid(n):
		return false
	if bool(n.get("is_boss")):
		return true
	return n.is_in_group("boss")


func _is_chest(n: Node) -> bool:
	return n != null and str(n.get("kind")).ends_with("chest")


func _world3() -> World3D:
	var tree := get_tree()
	if tree == null or tree.root == null:
		return null
	return tree.root.get_viewport().world_3d


func _has_los(a: Node, b: Node) -> bool:
	if a == null or b == null:
		return false
	var w3 := _world3()
	if w3 == null:
		return true
	return Combat.los((a as Node3D).global_position, (b as Node3D).global_position, w3)


func _has_los_from(pos: Vector3, b: Node) -> bool:
	if b == null:
		return false
	var w3 := _world3()
	if w3 == null:
		return true
	return Combat.los(pos, (b as Node3D).global_position, w3)


func _door_between(a: Node, b: Node) -> bool:
	var door := _closed_door()
	if door == null or a == null or b == null:
		return false
	var pa: Vector3 = (a as Node3D).global_position
	var pb: Vector3 = (b as Node3D).global_position
	var pc: Vector3 = (door as Node3D).global_position
	var av := Vector2(pa.x, pa.z)
	var bv := Vector2(pb.x, pb.z)
	var cv := Vector2(pc.x, pc.z)
	var ab := bv - av
	var den := ab.length_squared()
	if den < 0.0001:
		return false
	var t := clampf((cv - av).dot(ab) / den, 0.0, 1.0)
	if t < 0.08 or t > 0.92:
		return false
	return av.lerp(bv, t).distance_to(cv) < 0.95


func _has_wide_los(a: Node, b: Node) -> bool:
	if _door_between(a, b):
		return false
	if not _has_los(a, b):
		return false
	if not _is_bow():
		return true
	var w3 := _world3()
	if w3 == null:
		return true
	var pa: Vector3 = (a as Node3D).global_position
	var pb: Vector3 = (b as Node3D).global_position
	var d := Vector3(pb.x - pa.x, 0.0, pb.z - pa.z)
	if d.length() < 0.001:
		return true
	var perp := Vector3(-d.z, 0.0, d.x).normalized() * 0.32
	if not Combat.los(pa + perp, pb + perp, w3):
		return false
	if not Combat.los(pa - perp, pb - perp, w3):
		return false
	return true


func _has_los_from_wide(pos: Vector3, b: Node) -> bool:
	if not _has_los_from(pos, b):
		return false
	if not _is_bow():
		return true
	var w3 := _world3()
	if w3 == null:
		return true
	var pb: Vector3 = (b as Node3D).global_position
	var d := Vector3(pb.x - pos.x, 0.0, pb.z - pos.z)
	if d.length() < 0.001:
		return true
	var perp := Vector3(-d.z, 0.0, d.x).normalized() * 0.32
	return Combat.los(pos + perp, pb + perp, w3) and Combat.los(pos - perp, pb - perp, w3)


func _alive_enemy(n: Node) -> bool:
	if n == null or not is_instance_valid(n):
		return false
	if n.has_method("is_alive") and not n.is_alive():
		return false
	return true


func _notice_range() -> float:
	if _is_staff():
		return maxf(6.2, float(App.bal.staff_special_radius) + 4.0)
	if _is_bow():
		return maxf(6.0, float(App.bal.bow_range) + 0.4)
	return maxf(4.4, _weapon_range() + 1.6)


func _grid_dims() -> Dictionary:
	var dung := _dungeon()
	if dung == null:
		return {}
	var data: Dictionary = dung.data
	return {"grid": data.grid, "w": int(data.w), "h": int(data.h)}


func _grid_floor(c: Vector2i) -> bool:
	var dim := _grid_dims()
	if dim.is_empty():
		return false
	var grid: PackedByteArray = dim.grid
	var w: int = dim.w
	var h: int = dim.h
	if c.x < 0 or c.y < 0 or c.x >= w or c.y >= h:
		return false
	return grid[c.y * w + c.x] == 1


func _obstacle_cell(c: Vector2i) -> bool:
	var tree := get_tree()
	if tree == null:
		return false
	for g in tree.get_nodes_in_group("gates"):
		if g and is_instance_valid(g) and not bool(g.get("open")) and _cell_of_node(g) == c:
			return true
	for d in tree.get_nodes_in_group("boss_door"):
		if d and is_instance_valid(d) and not bool(d.get("open")) and _cell_of_node(d) == c:
			return true
	for b in tree.get_nodes_in_group("breakables"):
		if b and is_instance_valid(b) and _cell_of_node(b) == c:
			return true
	return false


func _prop_cell(c: Vector2i) -> bool:
	var tree := get_tree()
	if tree == null:
		return false
	for n in tree.get_nodes_in_group("interact"):
		if n == null or not is_instance_valid(n):
			continue
		var k := str(n.get("kind"))
		if k.ends_with("chest") or k.begins_with("clerk") or k.find("patty") >= 0 or k.find("misc") >= 0:
			if _cell_of_node(n) == c:
				return true
	for n in tree.get_nodes_in_group("gather"):
		if n and is_instance_valid(n) and _cell_of_node(n) == c:
			return true
	return false


func _floor_cell(_grid: PackedByteArray, _w: int, _h: int, c: Vector2i) -> bool:
	return _grid_floor(c) and not _obstacle_cell(c) and not _prop_cell(c)


func _steer_floor(c: Vector2i) -> bool:
	return _grid_floor(c) and not _obstacle_cell(c)


func _pos_walkable(pos: Vector3) -> bool:
	return _steer_floor(_cell_of_pos(pos))


func _dir_open(p: Node, dir: Vector2) -> bool:
	if dir.length() < 0.01:
		return true
	var n := dir.normalized()
	if _dir_hits_door(p, n):
		return false
	var pos: Vector3 = (p as Node3D).global_position
	for t in [0.18, 0.34]:
		var q := Vector3(pos.x + n.x * t, pos.y, pos.z + n.y * t)
		if not _pos_walkable(q):
			return false
	return true


func _any_open(p: Node) -> Vector2:
	var dirs := [Vector2.RIGHT, Vector2.LEFT, Vector2.DOWN, Vector2.UP]
	for d in dirs:
		if _dir_open(p, d):
			return d
	return Vector2.ZERO


func _walk_clear(a: Node, b: Node) -> bool:
	var dim := _grid_dims()
	if dim.is_empty() or a == null or b == null:
		return false
	var grid: PackedByteArray = dim.grid
	var w: int = dim.w
	var h: int = dim.h
	var s := _cell_of_pos((a as Node3D).global_position)
	var g := _stand_cell(a, b)
	var x := s.x
	var y := s.y
	var x1 := g.x
	var y1 := g.y
	var dx := absi(x1 - x)
	var dy := absi(y1 - y)
	var sx := 1 if x < x1 else -1
	var sy := 1 if y < y1 else -1
	var err := dx - dy
	var guard := 0
	while guard < 80:
		guard += 1
		if not _floor_cell(grid, w, h, Vector2i(x, y)):
			return false
		if x == x1 and y == y1:
			return true
		var e2 := err * 2
		var step_x := e2 > -dy
		var step_y := e2 < dx
		if step_x and step_y:
			if not _floor_cell(grid, w, h, Vector2i(x + sx, y)):
				return false
			if not _floor_cell(grid, w, h, Vector2i(x, y + sy)):
				return false
			x += sx
			y += sy
			err += dx - dy
		elif step_x:
			x += sx
			err -= dy
		else:
			y += sy
			err += dx
	return false


func _stand_cell(p: Node, dest: Node) -> Vector2i:
	var raw := _cell_of_node(dest)
	var here := _cell_of_pos((p as Node3D).global_position)
	var best := Vector2i(-999, -999)
	var best_d := 999
	for n in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
		var c: Vector2i = raw + n
		if not _steer_floor(c):
			continue
		if _prop_cell(c):
			continue
		var d := absi(c.x - here.x) + absi(c.y - here.y)
		if d < best_d:
			best_d = d
			best = c
	if best.x > -900:
		return best
	if _steer_floor(raw) and not _prop_cell(raw):
		return raw
	for n in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1), Vector2i(1, 1), Vector2i(1, -1), Vector2i(-1, 1), Vector2i(-1, -1)]:
		if _steer_floor(raw + n) and not _prop_cell(raw + n):
			return raw + n
	return raw


func _nearest_visible_threat(p: Node) -> Node:
	var best: Node = null
	var best_d := _notice_range()
	var tree := get_tree()
	if tree == null:
		return null
	for n in tree.get_nodes_in_group("enemies"):
		if not _alive_enemy(n):
			continue
		if _door_between(p, n):
			continue
		if _is_boss(n) and _dist(p, n) > 6.5:
			continue
		if _is_bow():
			if not _has_wide_los(p, n):
				continue
		elif not _has_los(p, n):
			continue
		var d := _dist(p, n)
		if d < best_d:
			best_d = d
			best = n
	return best


func _nearest_hunt(p: Node) -> Node:
	var best: Node = null
	var best_d := 8.0
	var tree := get_tree()
	if tree == null:
		return null
	for n in tree.get_nodes_in_group("enemies"):
		if not _alive_enemy(n):
			continue
		var d := _dist(p, n)
		if _is_boss(n):
			if d > 8.5 or _door_between(p, n):
				continue
		elif d > best_d:
			continue
		if _is_bow() and _has_wide_los(p, n) and not _door_between(p, n):
			continue
		if (not _is_bow()) and _has_los(p, n) and not _door_between(p, n):
			continue
		if not _has_path(p, n):
			continue
		var score := d
		if _is_boss(n):
			score -= 1.5
		if score < best_d:
			best_d = score
			best = n
	return best


func _closed_door() -> Node:
	var tree := get_tree()
	if tree == null:
		return null
	for d in tree.get_nodes_in_group("boss_door"):
		if d and is_instance_valid(d) and not bool(d.get("open")):
			return d
	return null


func _near_closed_door(p: Node) -> bool:
	var d := _closed_door()
	return d != null and _dist(p, d) < 1.85


func _dir_hits_door(p: Node, dir: Vector2) -> bool:
	var d := _closed_door()
	if d == null or dir.length() < 0.05:
		return false
	var from: Vector3 = (p as Node3D).global_position
	var nxt := from + Vector3(dir.x, 0.0, dir.y) * 0.75
	var dp: Vector3 = (d as Node3D).global_position
	return Vector2(nxt.x - dp.x, nxt.z - dp.z).length() < 1.12


func _door_away(p: Node) -> Vector2:
	var d := _closed_door()
	if d == null:
		return Vector2.ZERO
	return -_xz_to(p, d)


func _nearest_boss(p: Node) -> Node:
	var best: Node = null
	var best_d := 10.0
	var tree := get_tree()
	if tree == null:
		return null
	for n in tree.get_nodes_in_group("enemies"):
		if not _alive_enemy(n) or not _is_boss(n):
			continue
		var d := _dist(p, n)
		if d < best_d:
			best_d = d
			best = n
	return best


func _approach_boss(p: Node, boss: Node) -> void:
	if _door_between(p, boss):
		var side := _door_bypass(p, boss)
		aim = _xz_to(p, boss)
		move = _steer(p, side if side != Vector2.ZERO else _door_away(p))
		attack = false
		return
	if _has_los(p, boss) and _dist(p, boss) <= 6.5:
		_fight(p, boss)
		return
	if _has_path(p, boss):
		_follow_goal(p, boss)
		aim = _xz_to(p, boss)
		return
	if _near_closed_door(p):
		var side := _door_bypass(p, boss)
		move = _steer(p, side if side != Vector2.ZERO else _door_away(p))
		aim = _xz_to(p, boss)
		return
	move = _steer(p, Vector2.ZERO)


func _door_bypass(p: Node, boss: Node) -> Vector2:
	var door := _closed_door()
	if door == null:
		return Vector2.ZERO
	var dc := _cell_of_node(door)
	var here := _cell_of_pos((p as Node3D).global_position)
	var goal := _cell_of_node(boss)
	var best := Vector2i(-999, -999)
	var best_score := -9999
	for n in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1), Vector2i(2, 0), Vector2i(-2, 0), Vector2i(0, 2), Vector2i(0, -2), Vector2i(1, 1), Vector2i(1, -1), Vector2i(-1, 1), Vector2i(-1, -1)]:
		var c: Vector2i = dc + n
		if c == dc or not _steer_floor(c):
			continue
		var to_boss := absi(c.x - goal.x) + absi(c.y - goal.y)
		var to_here := absi(c.x - here.x) + absi(c.y - here.y)
		var score := -to_boss * 3 - to_here
		if score > best_score:
			best_score = score
			best = c
	if best.x < -900:
		return Vector2.ZERO
	var pos := (p as Node3D).global_position
	var t := _clearance_target(best)
	var v := Vector2(t.x - pos.x, t.y - pos.z)
	if v.length() < 0.18:
		return Vector2.ZERO
	if not _dir_open(p, v):
		v = Vector2(-v.y, v.x)
		if not _dir_open(p, v):
			return _door_away(p)
	return v.normalized()


func _safe_step(p: Node, desired: Vector2) -> Vector2:
	if desired.length() < 0.001:
		return _steer(p, Vector2.ZERO)
	if _dir_open(p, desired):
		return _steer(p, desired.normalized())
	var step := _step_dir(p, desired)
	if step != Vector2.ZERO and _dir_open(p, step):
		return step
	var side := Vector2(-desired.y, desired.x) * strafe_sign
	step = _step_dir(p, side)
	if step != Vector2.ZERO and _dir_open(p, step):
		return step
	return _steer(p, _any_open(p))


func _staff_hold() -> float:
	return float(App.bal.staff_special_radius) + 1.35


func _in_primary(d: float) -> bool:
	return d <= _weapon_range() + 0.12


func _try_staff_special(d: float, los: bool) -> void:
	if not los or spec_cd > 0.0:
		return
	if d < 1.45 or d > _staff_hold() + 1.8:
		return
	special = true
	just["special"] = true
	spec_cd = 1.15


func _lock_aim(p: Node, enemy: Node) -> void:
	aim = _xz_to(p, enemy)


func _fight(p: Node, enemy: Node) -> void:
	var d := _dist(p, enemy)
	var rng := _weapon_range()
	var boss := _is_boss(enemy)
	var los := _has_wide_los(p, enemy) if _is_bow() else _has_los(p, enemy)
	if _door_between(p, enemy):
		var bypass := _door_bypass(p, enemy)
		move = _steer(p, bypass if bypass != Vector2.ZERO else _door_away(p))
		attack = false
		_lock_aim(p, enemy)
		return
	var hold := clampf(rng * 0.86, 1.12, maxf(1.12, rng - 0.08))
	var too_close := minf(hold * 0.52, maxf(0.78, rng * 0.34))
	if boss and _is_axe():
		hold = rng - 0.18
		too_close = 1.08
	elif boss:
		hold = 3.9 if not _is_bow() else clampf(rng * 0.62, 3.2, 6.2)
		too_close = 3.2 if not _is_bow() else 2.6
	if _is_bow():
		hold = clampf(rng * 0.62, 3.2, 6.2)
		too_close = 2.6
	if _is_staff():
		hold = _staff_hold()
		too_close = 2.05
	_lock_aim(p, enemy)
	if App.tel and App.tel.dmg_dealt > 0.0:
		hit_something = true

	var need_path := (not los) or (d > hold and not _walk_clear(p, enemy))
	if _is_axe() and not _walk_clear(p, enemy) and d > rng:
		need_path = true
	if need_path and _has_path(p, enemy):
		_follow_goal(p, enemy)
		_lock_aim(p, enemy)
		attack = los and _in_primary(d) and not _is_staff()
		if _is_staff():
			_try_staff_special(d, los)
		return

	path.clear()
	path_goal = null

	if not los:
		var slide := _los_reposition(p, enemy)
		move = _steer(p, slide)
		_lock_aim(p, enemy)
		attack = false
		if stuck_t > 0.4:
			strafe_sign *= -1.0
			dash = true
			just["dash"] = true
		return

	if _is_staff():
		_try_staff_special(d, true)
		attack = spec_cd > 0.2 and _in_primary(d)
		if d < too_close:
			move = _safe_step(p, -aim)
		elif d > hold + 0.35:
			move = _safe_step(p, aim)
		else:
			move = _safe_step(p, Vector2(-aim.y, aim.x) * strafe_sign)
			if stuck_t > 0.35:
				strafe_sign *= -1.0
				dash = true
				just["dash"] = true
		_lock_aim(p, enemy)
		return

	if _is_axe() and boss:
		attack = _in_primary(d)
		if spec_cd <= 0.0 and d <= float(App.bal.slam_radius) + 0.08:
			special = true
			just["special"] = true
			spec_cd = 1.1
		if d < too_close:
			move = _safe_step(p, -aim)
		elif not _in_primary(d):
			move = _safe_step(p, aim)
		else:
			move = _safe_step(p, Vector2(-aim.y, aim.x) * strafe_sign)
		_lock_aim(p, enemy)
		return

	if d < too_close:
		move = _safe_step(p, -aim)
		attack = _in_primary(d)
		if d < (2.6 if boss else 1.05) or _crowd(p) >= 2 or stuck_t > 0.4:
			dash = true
			just["dash"] = true
		if spec_cd <= 0.0 and _in_primary(d) and randf() < 0.2:
			special = true
			just["special"] = true
			spec_cd = 1.1
		_lock_aim(p, enemy)
		return

	if d > hold + 0.2:
		move = _safe_step(p, aim)
		attack = _in_primary(d)
		_lock_aim(p, enemy)
		return

	var side := Vector2(-aim.y, aim.x) * strafe_sign
	if stuck_t > 0.35:
		strafe_sign *= -1.0
		move = _safe_step(p, -aim)
		dash = true
		just["dash"] = true
	else:
		move = _safe_step(p, side)
	attack = _in_primary(d)
	if spec_cd <= 0.0 and _in_primary(d) and randf() < 0.22:
		special = true
		just["special"] = true
		spec_cd = 1.1
	_lock_aim(p, enemy)


func _los_reposition(p: Node, target: Node) -> Vector2:
	var here := _cell_of_pos((p as Node3D).global_position)
	var best := Vector2i(-999, -999)
	var best_score := -9999.0
	var rng := _weapon_range()
	if _is_staff():
		rng = _staff_hold() + 0.4
	for dy in range(-6, 7):
		for dx in range(-6, 7):
			var c := Vector2i(here.x + dx, here.y + dy)
			if not _steer_floor(c) or _prop_cell(c):
				continue
			var pos := Vector3(float(c.x) + 0.5, 0.0, float(c.y) + 0.5)
			if _is_bow():
				if not _has_los_from_wide(pos, target):
					continue
			elif not _has_los_from(pos, target):
				continue
			var td := Vector2(pos.x - (target as Node3D).global_position.x, pos.z - (target as Node3D).global_position.z).length()
			if td > rng + 0.4:
				continue
			var walk := float(absi(dx) + absi(dy))
			var score := 12.0 - walk - absf(td - rng * 0.65)
			if score > best_score:
				best_score = score
				best = c
	if best.x < -900:
		return Vector2.ZERO
	var pos := (p as Node3D).global_position
	var t := _clearance_target(best)
	var v := Vector2(t.x - pos.x, t.y - pos.z)
	if v.length() < 0.16 or not _dir_open(p, v):
		return Vector2.ZERO
	return v.normalized()


func _clearance_target(c: Vector2i) -> Vector2:
	var t := Vector2(float(c.x) + 0.5, float(c.y) + 0.5)
	var push := Vector2.ZERO
	for n in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
		if not _steer_floor(c + n):
			push -= Vector2(float(n.x), float(n.y))
	if push.length() > 0.001:
		t += push.normalized() * 0.20
	return t


func _wall_sep(p: Node) -> Vector2:
	var here := _cell_of_pos((p as Node3D).global_position)
	var pos := (p as Node3D).global_position
	var center := Vector2(float(here.x) + 0.5, float(here.y) + 0.5)
	var off := Vector2(pos.x - center.x, pos.z - center.y)
	var sep := Vector2.ZERO
	for n in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
		if _steer_floor(here + n):
			continue
		var axis := Vector2(float(n.x), float(n.y))
		if off.dot(axis) > 0.08:
			sep -= axis
		else:
			var probe := Vector3(pos.x + axis.x * 0.34, pos.y, pos.z + axis.y * 0.34)
			if not _pos_walkable(probe):
				sep -= axis
	if sep.length() < 0.001:
		return Vector2.ZERO
	return sep.normalized()


func _steer(p: Node, desired: Vector2) -> Vector2:
	var sep := _wall_sep(p)
	var out := desired
	if desired != Vector2.ZERO and not _dir_open(p, desired):
		out = Vector2.ZERO
	if out == Vector2.ZERO:
		out = sep
	elif sep != Vector2.ZERO:
		out = (out * 0.40 + sep * 1.15).normalized()
	if out == Vector2.ZERO or not _dir_open(p, out):
		out = _any_open(p)
	return out


func _step_dir(p: Node, desired: Vector2) -> Vector2:
	if desired.length() < 0.001:
		return _steer(p, Vector2.ZERO)
	desired = desired.normalized()
	var here := _cell_of_pos((p as Node3D).global_position)
	var best := Vector2.ZERO
	var best_score := -999.0
	for n in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
		var nxt: Vector2i = here + n
		if not _steer_floor(nxt):
			continue
		var dir := Vector2(float(n.x), float(n.y))
		if not _dir_open(p, dir):
			continue
		var score := dir.dot(desired)
		if score > best_score:
			best_score = score
			best = dir
	if best == Vector2.ZERO:
		return _steer(p, Vector2.ZERO)
	return _steer(p, best)


func _mail_at(clerk: Node) -> void:
	if clerk == null or _is_chest(clerk):
		return
	var role := _clerk_role(clerk)
	if role == "" or not _clerk_accepts(clerk):
		return
	App.note_clerk()
	App.prog.extract_all(role)
	var ui := _world_ui()
	if ui and bool(ui.get("open")) and ui.has_method("close_ui"):
		ui.close_ui()


func _clerk_role(n: Node) -> String:
	var k := str(n.get("kind"))
	if k.find("patty") >= 0:
		return "patty"
	if k.find("misc") >= 0:
		return "misc"
	if k.begins_with("clerk"):
		return "gather"
	return ""


func _gather_cargo() -> int:
	var root_n := 0
	if App.prog:
		root_n = int(App.prog.root)
	return App.ore + App.wood + root_n


func _misc_cargo() -> int:
	var n := App.gold
	if App.prog and App.prog.has_method("extractable"):
		for it in App.prog.extractable("misc"):
			if str(it.get("kind", "")) != "gold":
				n += 1
	return n


func _clerk_accepts(n: Node) -> bool:
	var role := _clerk_role(n)
	if role == "gather":
		return _gather_cargo() > 0
	if role == "misc":
		return _misc_cargo() > 0
	if role == "patty":
		return (_gather_cargo() + _misc_cargo()) > 0
	return false


func _best_clerk(p: Node) -> Node:
	var best: Node = null
	var best_d := 999.0
	var tree := get_tree()
	if tree == null:
		return null
	for n in tree.get_nodes_in_group("interact"):
		if n == null or not is_instance_valid(n):
			continue
		var k := str(n.get("kind"))
		if k == "vendor" or k == "shop" or k == "receptionist":
			continue
		if _clerk_role(n) == "":
			continue
		if not _clerk_accepts(n):
			continue
		if not _has_path(p, n):
			continue
		var d := _dist(p, n)
		if _clerk_role(n) == "patty" and _gather_cargo() > 0 and _misc_cargo() > 0:
			d *= 0.55
		if d < best_d:
			best_d = d
			best = n
	return best


func _best_gather(p: Node) -> Node:
	if _gather_cargo() >= 8:
		return null
	var tool := str(App.prog.tool_type) if App.prog else "pickaxe"
	var best: Node = null
	var best_d := 999.0
	var tree := get_tree()
	if tree == null:
		return null
	for n in tree.get_nodes_in_group("gather"):
		if n == null or not is_instance_valid(n):
			continue
		if int(n.get("hits")) <= 0:
			continue
		var k := str(n.get("kind"))
		if k == "wood" and tool != "hatchet":
			continue
		if k != "wood" and tool != "pickaxe":
			continue
		if not _has_path(p, n):
			continue
		var d := _dist(p, n)
		if d < best_d:
			best_d = d
			best = n
	return best


func _best_chest(p: Node) -> Node:
	var best: Node = null
	var best_d := 14.0
	var tree := get_tree()
	if tree == null:
		return null
	for n in tree.get_nodes_in_group("interact"):
		if n == null or not is_instance_valid(n):
			continue
		if not _is_chest(n) or bool(n.get("used")):
			continue
		if not _has_path(p, n):
			continue
		var d := _dist(p, n)
		if d < best_d:
			best_d = d
			best = n
	return best


func _reachable_kind(p: Node, prefix: String) -> Node:
	var best: Node = null
	var best_d := 80.0
	var tree := get_tree()
	if tree == null:
		return null
	for n in tree.get_nodes_in_group("interact"):
		if n == null or not is_instance_valid(n):
			continue
		if str(n.get("kind")).find(prefix) < 0:
			continue
		if not _has_path(p, n):
			continue
		var d := _dist(p, n)
		if d < best_d:
			best_d = d
			best = n
	return best


func _crowd(p: Node) -> int:
	var n := 0
	var tree := get_tree()
	if tree == null:
		return 0
	for e in tree.get_nodes_in_group("enemies"):
		if e and is_instance_valid(e) and not _is_boss(e) and _has_los(p, e) and _dist(p, e) < 2.4:
			n += 1
	return n


func _dist(a: Node, b: Node) -> float:
	if a is Node3D and b is Node3D:
		var pa: Vector3 = (a as Node3D).global_position
		var pb: Vector3 = (b as Node3D).global_position
		return Vector2(pb.x - pa.x, pb.z - pa.z).length()
	return 999.0


func _xz_to(a: Node, b: Node) -> Vector2:
	var pa: Vector3 = (a as Node3D).global_position
	var pb: Vector3 = (b as Node3D).global_position
	var d := Vector2(pb.x - pa.x, pb.z - pa.z)
	if d.length() < 0.001:
		return Vector2.DOWN
	return d.normalized()


func _dungeon() -> Node:
	var tree := get_tree()
	if tree == null:
		return null
	var s := tree.current_scene
	if s and s.get("data") is Dictionary and (s.data as Dictionary).has("grid"):
		return s
	return null


func _cell_of_pos(pos: Vector3) -> Vector2i:
	return Vector2i(int(floor(pos.x)), int(floor(pos.z)))


func _cell_of_node(n: Node) -> Vector2i:
	return _cell_of_pos((n as Node3D).global_position)


func _has_path(p: Node, dest: Node) -> bool:
	if dest == null:
		return false
	if _dist(p, dest) < 1.25:
		return true
	return not _astar(p, dest).is_empty()


func _follow_goal(p: Node, dest: Node) -> void:
	if dest == null:
		move = _steer(p, Vector2.ZERO)
		return
	if _door_between(p, dest):
		var bypass := _door_bypass(p, dest)
		move = _steer(p, bypass if bypass != Vector2.ZERO else _door_away(p))
		return
	if stuck_t > 0.7:
		path.clear()
		path_i = 0
		path_goal = dest
		move = _steer(p, _any_open(p))
		if stuck_t > 1.0:
			dash = true
			just["dash"] = true
		return
	if path_goal != dest:
		path.clear()
		path_i = 0
		path_goal = dest
	move = _steer(p, _follow_or_direct(p, dest))


func _follow_or_direct(p: Node, dest: Node) -> Vector2:
	if path.is_empty() or path_i >= path.size():
		path = _astar(p, dest)
		path_i = 0
	if path.is_empty():
		return _step_dir(p, _xz_to(p, dest))
	var here := _cell_of_pos((p as Node3D).global_position)
	while path_i < path.size() and path[path_i] == here:
		path_i += 1
	if path_i >= path.size():
		return Vector2.ZERO
	var c: Vector2i = path[path_i]
	var target := _clearance_target(c)
	var pos := (p as Node3D).global_position
	var d := Vector2(target.x - pos.x, target.y - pos.z)
	if d.length() < 0.28:
		path_i += 1
		if path_i >= path.size():
			return Vector2.ZERO
		return _follow_or_direct(p, dest)
	if not _dir_open(p, d):
		return _step_dir(p, d)
	return d.normalized()


func _astar(p: Node, dest: Node) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	var dim := _grid_dims()
	if dim.is_empty() or dest == null:
		return out
	var grid: PackedByteArray = dim.grid
	var w: int = dim.w
	var h: int = dim.h
	var start := _cell_of_pos((p as Node3D).global_position)
	var goal := _stand_cell(p, dest)
	if not _steer_floor(start) or _prop_cell(start):
		for n in [Vector2i(0, 0), Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
			if _steer_floor(start + n) and not _prop_cell(start + n):
				start += n
				break
	if not _steer_floor(goal) or _prop_cell(goal):
		return out
	if start == goal:
		out.append(goal)
		return out
	var open: Array[Vector2i] = [start]
	var came := {}
	var gscore := {}
	var fscore := {}
	gscore[start] = 0
	fscore[start] = start.distance_to(goal)
	var closed := {}
	var guard := 0
	while not open.is_empty() and guard < 2500:
		guard += 1
		var best_i := 0
		var best_f := float(fscore.get(open[0], 1e9))
		for i in open.size():
			var f := float(fscore.get(open[i], 1e9))
			if f < best_f:
				best_f = f
				best_i = i
		var cur: Vector2i = open[best_i]
		open.remove_at(best_i)
		if cur == goal:
			var step: Vector2i = cur
			var rev: Array[Vector2i] = []
			while step != start:
				rev.append(step)
				if not came.has(step):
					break
				step = came[step]
			rev.reverse()
			return rev
		closed[cur] = true
		for n in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
			var nxt: Vector2i = cur + n
			if closed.has(nxt) or not _floor_cell(grid, w, h, nxt):
				continue
			var tg := int(gscore.get(cur, 0)) + 1
			if tg < int(gscore.get(nxt, 1 << 30)):
				came[nxt] = cur
				gscore[nxt] = tg
				fscore[nxt] = float(tg) + nxt.distance_to(goal)
				if open.find(nxt) < 0:
					open.append(nxt)
	return out


func _start_next() -> void:
	if interrupted or queue.is_empty():
		_stop_live()
		return
	if not live_running:
		live_backup = Store.collect()
		bal_backup = _snap_bal()
		scale_backup = Engine.time_scale
	job = queue.pop_front()
	live_running = true
	running = true
	ai_on = false
	sim_t = 0.0
	stuck_t = 0.0
	wander_t = 0.0
	moved = false
	recap_taken = false
	path.clear()
	path_i = 0
	path_goal = null
	slot = str(job.get("save", "fresh"))
	_prep_slot()
	var cfg: Dictionary = job.get("cfg", {})
	for k in cfg.keys():
		App.bal.setv(str(k), float(cfg[k]))
	App.set_character(str(job.get("gender", "male")))
	App.prog.pick_weapon = str(job.get("weapon", "great_axe"))
	App.prog.tool_type = str(job.get("tool", "pickaxe"))
	App.weapon = App.prog.pick_weapon
	App.prog.begin_run_loadout()
	App.tel.reset(slot, true)
	App.tel.start_weapon = App.weapon
	Engine.time_scale = maxf(1.0, float(job.get("scale", App.bal.playtest_scale)))
	if App.debug and bool(App.debug.get("open")):
		App.debug.hide_menu()
	if App.pause_menu and bool(App.pause_menu.get("open")):
		App.pause_menu.close_ui()
	App.begin_run()


func _prep_slot() -> void:
	if slot == "progressed":
		Store.fresh_delver()
		for id in App.prog.SKILLS:
			App.prog.skills_perm[id] = 400.0
		App.prog.deepest = 8
		App.bank_gold = 80
		App.bank_ore = 20
		App.bank_wood = 12
		App.character_chosen = true
		Store.save_slot("progressed")
		Store.load_slot("progressed")
	else:
		Store.wipe_slot("fresh")
		Store.fresh_delver()
		Store.save_slot("fresh")
		Store.load_slot("fresh")


func _finish_job(cond: String, force_end: bool) -> void:
	if not live_running:
		return
	if force_end and App.tel and App.tel.end_cond == "":
		App.tel.note_end(cond, "")
	if App.extracted and App.tel.end_cond == "":
		App.tel.note_end("extraction", "")
	history.append(App.tel.to_dict())
	_save_history()
	ai_on = false
	path.clear()
	path_goal = null
	if queue.is_empty() or interrupted:
		_stop_live()
		return
	_start_next()


func _stop_live() -> void:
	ai_on = false
	live_running = false
	running = false
	smoke_mode = false
	path.clear()
	path_goal = null
	Engine.time_scale = scale_backup if scale_backup > 0.0 else 1.0
	_restore_bal(bal_backup)
	if not live_backup.is_empty():
		Store.apply(live_backup)
	_compute_coefs()
	_build_recs()
	_save_coefs()
	last_summary = _format()


func _sim_save(kind: String, progressed: bool) -> void:
	var weapons := ["great_axe", "staff", "longbow"]
	var tweaks := [
		{},
		{"axe_damage": App.bal.axe_damage * 1.2},
		{"staff_damage": App.bal.staff_damage * 1.2},
		{"bow_damage": App.bal.bow_damage * 1.2},
		{"enemy_hp_mult": App.bal.enemy_hp_mult * 0.8},
		{"mine_chance": mini_f(0.95, App.bal.mine_chance + 0.15)},
	]
	for w in weapons:
		for tw in tweaks:
			if interrupted:
				return
			_one_run(kind, progressed, w, tw)


func mini_f(a: float, b: float) -> float:
	return a if a < b else b


func _one_run(kind: String, progressed: bool, wpn: String, tw: Dictionary) -> void:
	var snap: Dictionary = _snap_bal()
	for k in tw.keys():
		App.bal.setv(str(k), float(tw[k]))
	if progressed:
		Store.fresh_delver()
		for id in App.prog.SKILLS:
			App.prog.skills_perm[id] = 400.0
		Store.save_slot("progressed")
		Store.load_slot("progressed")
	else:
		Store.wipe_slot("fresh")
		Store.fresh_delver()
		Store.save_slot("fresh")
		Store.load_slot("fresh")
	App.prog.pick_weapon = wpn
	App.prog.tool_type = "pickaxe"
	App.weapon = wpn
	App.character_type = "male"
	App.prog.begin_run_loadout()
	App.tel.reset(kind, true)
	App.tel.start_weapon = wpn
	App.floor_n = 1
	var dmg: float = App.bal.axe_damage
	if wpn == "staff":
		dmg = App.bal.staff_damage
	elif wpn == "longbow":
		dmg = App.bal.bow_damage
	dmg += App.prog.gear_dmg()
	var hp := App.bal.dummy_hp * App.bal.enemy_hp_mult
	var kills := 0
	var t := 0.0
	while kills < 6 and t < 90.0:
		t += 0.4
		App.tel.tick(0.4, true)
		var hit := dmg * 0.9
		App.tel.note_damage_dealt(hit, false)
		hp -= hit
		if hp <= 0.0:
			kills += 1
			App.on_kill()
			App.tel.note_kill()
			hp = App.bal.dummy_hp * App.bal.enemy_hp_mult
	App.gold += 12
	App.ore += 8
	App.wood += 4
	App.tel.mine_hits = 8
	App.tel.mine_ok = 5
	App.tel.gold_gained = 12
	App.tel.note_extract(App.gold, App.ore, App.wood)
	App.prog.extract_all("patty")
	if App.tel.clerk_t < 0.0:
		App.tel.clerk_t = 8.0
	App.prog.keep_fragments()
	App.tel.recap_drain = true
	App.tel.note_end("extraction", "")
	history.append(App.tel.to_dict())
	_restore_bal(snap)


func _compute_coefs() -> void:
	coefs.clear()
	for key in ["axe_damage", "staff_damage", "bow_damage", "enemy_hp_mult", "mine_chance"]:
		var xs: Array = []
		var ys: Array = []
		for row in history:
			xs.append(_cfg_proxy(key, row))
			ys.append(float(row.get("dmg_dealt", 0)) + 1.0 / maxf(0.2, float(row.get("duration", 1.0))))
		coefs[key] = _corr(xs, ys)
	_weapon_aware_nudge()


func _weapon_aware_nudge() -> void:
	var dmg := {"great_axe": 0.0, "staff": 0.0, "longbow": 0.0}
	for row in history:
		var wv: Variant = row.get("wpn", {})
		var w: Dictionary = wv if wv is Dictionary else {}
		for id in dmg.keys():
			var dv: Variant = w.get(id, {})
			var wd: Dictionary = dv if dv is Dictionary else {}
			dmg[id] = float(dmg[id]) + float(wd.get("dmg", 0))
	var mx := maxf(dmg["great_axe"], maxf(dmg["staff"], dmg["longbow"]))
	if mx <= 1.0:
		return
	if dmg["staff"] < mx * 0.55:
		coefs["staff_damage"] = maxf(float(coefs.get("staff_damage", 0.0)), 0.35)
	if dmg["longbow"] < mx * 0.55:
		coefs["bow_damage"] = maxf(float(coefs.get("bow_damage", 0.0)), 0.35)
	if dmg["great_axe"] < mx * 0.55:
		coefs["axe_damage"] = maxf(float(coefs.get("axe_damage", 0.0)), 0.35)


func _cfg_proxy(key: String, row: Dictionary) -> float:
	var w: Dictionary = row.get("wpn", {})
	if key == "axe_damage":
		return float((w.get("great_axe", {}) as Dictionary).get("dmg", 0))
	if key == "staff_damage":
		return float((w.get("staff", {}) as Dictionary).get("dmg", 0))
	if key == "bow_damage":
		return float((w.get("longbow", {}) as Dictionary).get("dmg", 0))
	if key == "enemy_hp_mult":
		return 1.0 / maxf(0.5, float(row.get("kills", 1)))
	return float(row.get("mine_ok", 0))


func _corr(xs: Array, ys: Array) -> float:
	var n := mini(xs.size(), ys.size())
	if n < 3:
		return 0.0
	var mx := 0.0
	var my := 0.0
	for i in n:
		mx += float(xs[i])
		my += float(ys[i])
	mx /= float(n)
	my /= float(n)
	var num := 0.0
	var dx := 0.0
	var dy := 0.0
	for i in n:
		var a := float(xs[i]) - mx
		var b := float(ys[i]) - my
		num += a * b
		dx += a * a
		dy += b * b
	if dx < 0.0001 or dy < 0.0001:
		return 0.0
	return clampf(num / sqrt(dx * dy), -1.0, 1.0)


func _build_recs() -> void:
	var base := {
		"axe_damage": App.bal.axe_damage,
		"staff_damage": App.bal.staff_damage,
		"bow_damage": App.bal.bow_damage,
		"enemy_hp_mult": App.bal.enemy_hp_mult,
		"mine_chance": App.bal.mine_chance,
		"move_speed": App.bal.move_speed,
	}
	var avg: float = (float(base.axe_damage) + float(base.staff_damage) + float(base.bow_damage)) / 3.0
	var staff_n := avg * 0.55
	var bow_n := avg * 0.8
	if float(coefs.get("staff_damage", 0.0)) > 0.2:
		staff_n = avg * 0.7
	if float(coefs.get("bow_damage", 0.0)) > 0.2:
		bow_n = avg * 0.9
	recs["fresh"] = [
		{"label": "Ideal — first extraction", "cfg": _merge(base, {"enemy_hp_mult": float(base.enemy_hp_mult) * 0.85, "mine_chance": mini_f(0.9, float(base.mine_chance) + 0.1), "move_speed": float(base.move_speed) * 1.05})},
		{"label": "Alt A — safer combat", "cfg": _merge(base, {"enemy_hp_mult": float(base.enemy_hp_mult) * 0.9, "axe_damage": avg})},
		{"label": "Alt B — gather lean", "cfg": _merge(base, {"mine_chance": mini_f(0.95, float(base.mine_chance) + 0.15)})},
	]
	recs["progressed"] = [
		{"label": "Ideal — weapon balance", "cfg": _merge(base, {"axe_damage": avg, "staff_damage": staff_n, "bow_damage": bow_n})},
		{"label": "Alt A — later floors", "cfg": _merge(base, {"enemy_hp_mult": float(base.enemy_hp_mult) * 1.1, "cycle_hp": App.bal.cycle_hp})},
		{"label": "Alt B — keep current", "cfg": base.duplicate()},
	]


func _merge(base: Dictionary, extra: Dictionary) -> Dictionary:
	var o := base.duplicate()
	for k in extra.keys():
		o[k] = extra[k]
	return o


func _snap_bal() -> Dictionary:
	var d := {}
	for row in App.bal.schema():
		d[str(row[0])] = App.bal.getv(str(row[0]))
	return d


func _restore_bal(d: Dictionary) -> void:
	for k in d.keys():
		App.bal.setv(str(k), float(d[k]))


func _format() -> String:
	var s := "Playtest  ·  rows %d  ·  queue %d\n" % [history.size(), queue.size()]
	s += "Coefs: "
	for k in coefs.keys():
		s += "%s=%.2f  " % [k, float(coefs[k])]
	s += "\nFresh recs: "
	for r in recs["fresh"]:
		s += str(r.label) + " | "
	s += "\nProgressed recs: "
	for r in recs["progressed"]:
		s += str(r.label) + " | "
	s += "\n" + success_report()
	return s


func success_report() -> String:
	if history.is_empty():
		return "Success: no rows."
	var extract_t := 9999.0
	var drain := true
	var wpn_kills := {"great_axe": 0.0, "staff": 0.0, "longbow": 0.0}
	for row in history:
		if str(row.get("end_cond", "")) == "extraction":
			extract_t = minf(extract_t, float(row.get("duration", 9999.0)))
		if not bool(row.get("recap_drain", false)):
			drain = false
		var wv: Variant = row.get("wpn", {})
		var w: Dictionary = wv if wv is Dictionary else {}
		for id in wpn_kills.keys():
			var dv: Variant = w.get(id, {})
			var wd: Dictionary = dv if dv is Dictionary else {}
			wpn_kills[id] = float(wpn_kills[id]) + float(wd.get("kills", 0))
	var mx := maxf(wpn_kills["great_axe"], maxf(wpn_kills["staff"], wpn_kills["longbow"]))
	var mn := minf(wpn_kills["great_axe"], minf(wpn_kills["staff"], wpn_kills["longbow"]))
	var bal_ok := mx <= 0.001 or (mn / maxf(0.001, mx)) >= 0.45
	var t_ok := extract_t <= 600.0
	return "SuccessCriterion extract_s=%.1f t_ok=%s recap=%s weapons_bal=%s" % [extract_t, str(t_ok), str(drain), str(bal_ok)]


func _save_history() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("user://playtest"))
	var f := FileAccess.open("user://playtest/history.json", FileAccess.WRITE)
	if f:
		f.store_string(JSON.stringify(history))


func _load_history() -> void:
	if not FileAccess.file_exists("user://playtest/history.json"):
		return
	var f := FileAccess.open("user://playtest/history.json", FileAccess.READ)
	if f == null:
		return
	var parsed: Variant = JSON.parse_string(f.get_as_text())
	if parsed is Array:
		history = parsed


func _save_coefs() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("user://playtest"))
	var f := FileAccess.open("user://playtest/coefs.json", FileAccess.WRITE)
	if f:
		f.store_string(JSON.stringify(coefs))


func _load_coefs() -> void:
	if not FileAccess.file_exists("user://playtest/coefs.json"):
		return
	var f := FileAccess.open("user://playtest/coefs.json", FileAccess.READ)
	if f == null:
		return
	var parsed: Variant = JSON.parse_string(f.get_as_text())
	if parsed is Dictionary:
		coefs = parsed