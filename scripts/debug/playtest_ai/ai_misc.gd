extends Object

const U := preload("res://scripts/debug/playtest_ai/ai_util.gd")
const G := preload("res://scripts/debug/playtest_goals.gd")
const L := preload("res://scripts/debug/playtest_log.gd")
const A := preload("res://scripts/debug/playtest_ai/ai_act.gd")
const CLOSE := 2.4
const GATHER := 9.0
const HAUL := 8
const Human := preload("res://scripts/debug/playtest_ai/ai_human.gd")
const PathU := preload("res://scripts/debug/playtest_path/path_util.gd")
const Step := preload("res://scripts/debug/playtest_path/path_step.gd")
const Net := preload("res://scripts/world/crystal/net.gd")

static func must_swing(pt: PlayHost, p: Node, foe: Node) -> bool:
	if foe == null or not is_instance_valid(foe):
		return false
	var dist: float = pt._dist(p, foe)
	if pt._is_boss(foe):
		return dist <= maxf(pt._weapon_range() + 1.2, _see_reach())
	return dist <= pt._weapon_range() + 1.2


static func press_at(reach: float) -> float:
	if reach < 1.18:
		return 1.18
	return reach


static func use_prop(pt: PlayHost, p: Node, dest: Node, reach: float = 1.18) -> void:
	if dest == null or not is_instance_valid(dest):
		pt.move = Vector2.ZERO
		pt.path_goal = null
		return
	var d: float = pt._dist(p, dest)
	pt.aim = pt._xz_to(p, dest)
	pt.path_goal = dest
	var allow: float = reach
	if dest.get("reach") != null:
		allow = maxf(allow, float(dest.get("reach")))
	if d < press_at(allow):
		pt.path.clear()
		pt.path_i = 0
		pt.move = Vector2.ZERO
		pt.interact = true
		pt.just["interact"] = true
		return
	if d < CLOSE:
		pt.path.clear()
		pt.path_i = 0
		pt.move = pt._steer(p, pt._xz_to(p, dest))
		return
	if U.spinning(pt):
		pt.path.clear()
		pt.path_i = 0
		pt.move = pt._any_open(p)
		return
	pt._follow_goal(p, dest)

static func _wants_clerk(pt: PlayHost, n: Node) -> bool:
	if n == null or not is_instance_valid(n) or U._banned(pt, n):
		return false
	if (n.get("used") == true):
		return false
	var k: String = str(n.get("kind"))
	if k != "extract_gate" and k.find("clerk") < 0 and k != "patty" and k != "receptionist":
		return false
	if k.find("gather") >= 0:
		return int(pt._gather_cargo()) > 0
	return int(App.gold) > 0 or int(pt._gather_cargo()) > 0 or int(pt._misc_cargo()) > 0

static func _is_junk(pt: PlayHost, n: Node) -> bool:
	if n == null or not is_instance_valid(n):
		return true
	var k: String = str(n.get("kind"))
	if k.find("crystal") >= 0:
		return false
	if U._banned(pt, n):
		return true
	if n.get("used") == true:
		return true
	if (k == "mine" or k == "wood") and not U.tool_ok(n):
		return true
	if (k == "mine" or k == "wood") and int(n.get("hits")) <= 0:
		return true
	return false

static func _usable_local(pt: PlayHost, p: Node, lim: float) -> Node:
	var _fac = load("res://scripts/debug/playtest_ai.gd")
	var guard: int = 0
	while guard < 8:
		guard += 1
		var n: Node = U._near_prop(pt, p, lim)
		if n == null or not is_instance_valid(n):
			return null
		if _is_junk(pt, n) or not U.can_use(pt, n):
			U._ban(pt, n)
			_fac._mark_pad(pt, n, 1)
			continue
		return n
	return null

static func _mail_if_close(pt: PlayHost, p: Node, clerk: Node) -> bool:
	if clerk == null or not is_instance_valid(clerk) or not _wants_clerk(pt, clerk):
		return false
	if pt._dist(p, clerk) > 1.6:
		return false
	G.mail_at(pt, clerk)
	_done_with_clerk(pt, clerk)
	L.decide(pt, p, "clerk", "mailed", L.target(clerk))
	pt.move = Vector2.ZERO
	pt.interact = true
	pt.just["interact"] = true
	return true

static func _leave_crystal(pt: PlayHost, p: Node, crystal: Node) -> void:
	var _fac = load("res://scripts/debug/playtest_ai.gd")
	pt.set_meta("flee_c", true)
	pt.set_meta("flee_t", 6.0)
	pt.set_meta("wander_hold", 2.4)
	_fac._mark_pad(pt, crystal, 10)
	var flee_c: Vector2 = G.away_open(pt, p, crystal)
	if flee_c == Vector2.ZERO:
		flee_c = pt._any_open(p)
	L.decide(pt, p, "wander", "leave_crystal")
	pt.path.clear()
	pt.path_goal = null
	pt.move = flee_c
	pt.wander_dir = flee_c
	pt.aim = flee_c

static func _engage(pt: PlayHost, p: Node, foe: Node, why: String) -> void:
	U.stop_gather(p)
	U.note_threat(pt, p, foe)
	_clear_lock(pt)
	L.decide(pt, p, "fight", why, L.target(foe))
	var d: float = pt._dist(p, foe)
	if Human.reacting(pt, foe, d):
		pt.attack = false
		pt.aim = pt._xz_to(p, foe)
		return
	if pt._is_boss(foe):
		A.approach_boss(pt, p, foe)
	else:
		A.fight(pt, p, foe)
	Human.dodge(pt, p, foe, d)
	Human.blur_aim(pt, d)

static func _done_with_clerk(pt: PlayHost, n: Node) -> void:
	var _fac = load("res://scripts/debug/playtest_ai.gd")
	if n == null or not is_instance_valid(n):
		return
	U._ban(pt, n)
	_fac._mark_pad(pt, n, 2)
	_clear_lock(pt)
	pt.path.clear()
	pt.path_goal = null

static func _clear_lock(pt: PlayHost) -> void:
	if pt.has_meta("lock_n"):
		pt.remove_meta("lock_n")
	pt.set_meta("lock_t", 0.0)

static func _see_reach() -> float:
	return float(App.bal.fog_radius) + 1.0

static func campaign_depth(pt: PlayHost, p: Node, delta: float) -> bool:
	if str(pt.slot) != "campaign":
		return false
	if p != null:
		var walked: Vector2i = pt._cell_of_node(p)
		U._mark(pt, walked)
		U._trail(pt, walked)
	if App.boss_dead:
		var stairs_ready: Node = _floor_stairs(pt)
		if stairs_ready != null and not bool(stairs_ready.get("locked")) and not U._banned(pt, stairs_ready):
			U._lock(pt, stairs_ready, 4.0)
			L.decide(pt, p, "extract_stairs", "campaign_stairs", L.target(stairs_ready))
			use_prop(pt, p, stairs_ready)
			return true
	var boss_near: Node = _living_boss(pt, p)
	if boss_near != null and pt._dist(p, boss_near) <= _see_reach():
		pt.set_meta("campaign_slip", 0.0)
		L.decide(pt, p, "hunt", "campaign_boss", L.target(boss_near))
		A.approach_boss(pt, p, boss_near)
		return true
	if _bind_here(pt, p):
		return true
	if _haul(pt, p):
		return true
	if _gather_near(pt, p):
		return true
	var door: Node = _known_guardian(pt, p)
	if door != null:
		var aim_cell: Vector2i = pt._cell_of_node(door)
		if _crystal_here(pt, p, aim_cell):
			return true
		var here: Vector2i = pt._cell_of_node(p)
		var at_door: bool = bool(door.get("open")) and pt._dist(p, door) <= 2.2
		if not at_door:
			var open_way: bool = PathU.opens_toward(pt, here, aim_cell) or pt._near_closed_door(p)
			if open_way:
				pt.set_meta("campaign_slip", 0.0)
				L.decide(pt, p, "hunt", "campaign_door", L.target(door))
				pt._follow_goal(p, door)
				pt.aim = pt._xz_to(p, door)
				return true
			if _crystal_detour(pt, p, aim_cell):
				return true
			if _retreat_move(pt, p):
				L.decide(pt, p, "wander", "campaign_back", L.target(door))
				return true
			return _explore_slip(pt, p, door, delta)
	return _explore(pt, p, delta)

static func _tight(pt: PlayHost, p: Node, delta: float) -> bool:
	var here: Vector2i = pt._cell_of_node(p)
	var ax: int = here.x
	var ay: int = here.y
	if pt.has_meta("campaign_ax"):
		ax = int(pt.get_meta("campaign_ax"))
		ay = int(pt.get_meta("campaign_ay"))
	if absi(here.x - ax) + absi(here.y - ay) > 2:
		pt.set_meta("campaign_ax", here.x)
		pt.set_meta("campaign_ay", here.y)
		pt.set_meta("campaign_hold", 0.0)
		return false
	var hold: float = U._meta_f(pt, "campaign_hold", 0.0) + delta
	pt.set_meta("campaign_hold", hold)
	return hold > 2.0

static func _slip_side(pt: PlayHost, p: Node, goal: Node) -> Vector2:
	var to_goal: Vector2 = pt._xz_to(p, goal)
	var side: Vector2 = Vector2(-to_goal.y, to_goal.x)
	if side.length_squared() < 0.0001:
		return pt._any_open(p)
	side = side.normalized()
	if not pt._dir_open(p, side):
		side = -side
	if not pt._dir_open(p, side):
		if to_goal.length_squared() > 0.0001:
			return -to_goal.normalized()
		return pt._any_open(p)
	return side

static func _md(a: Vector2i, b: Vector2i) -> int:
	return absi(a.x - b.x) + absi(a.y - b.y)

static func _crystal_cell(n: Node) -> Vector2i:
	var cell_v: Variant = n.get("crystal_cell")
	if cell_v is Vector2i:
		return cell_v as Vector2i
	return Vector2i(-1, -1)

static func _crystal_spots(pt: PlayHost) -> Array:
	var tree: SceneTree = pt.get_tree()
	if tree == null:
		return []
	return tree.get_nodes_in_group("floor_crystals")

static func _crystal_here(pt: PlayHost, p: Node, boss_cell: Vector2i) -> bool:
	if boss_cell.x < 0:
		return false
	var at: Node = null
	var at_d: float = 1.85
	var jump: Node = null
	var jump_d: int = _md(pt._cell_of_node(p), boss_cell) - 8
	for n: Node in _crystal_spots(pt):
		if n == null or not is_instance_valid(n):
			continue
		var cell: Vector2i = _crystal_cell(n)
		if cell.x < 0:
			continue
		var dist: float = pt._dist(p, n)
		if dist < at_d:
			at = n
			at_d = dist
		if bool(n.get("crystal_on")):
			var cd: int = _md(cell, boss_cell)
			if cd < jump_d:
				jump = n
				jump_d = cd
	if at == null:
		return false
	if not bool(at.get("crystal_on")):
		if not Net.volume_clear(at):
			return false
		Net.activate(at)
		pt.path.clear()
		pt.path_goal = null
		pt.move = Vector2.ZERO
		L.decide(pt, p, "hunt", "campaign_crystal", L.target(at))
		return true
	if jump == null or jump == at:
		return false
	var dung: Node = pt._dungeon()
	if dung == null or not Net.local_unlocked(dung):
		return false
	var dest: Vector2i = _crystal_cell(jump)
	if dest.x < 0:
		return false
	Net.warp_local(dung, dest)
	pt.path.clear()
	pt.path_goal = null
	pt.move = Vector2.ZERO
	L.decide(pt, p, "hunt", "campaign_crystal", L.target(jump))
	return true

static func _crystal_detour(pt: PlayHost, p: Node, boss_cell: Vector2i, hop_if_lost: bool = true, known_only: bool = false) -> bool:
	if boss_cell.x < 0:
		return false
	var here: Vector2i = pt._cell_of_node(p)
	var here_d: int = _md(here, boss_cell)
	var toward: Node = null
	var toward_d: int = here_d
	var hop: Node = null
	var hop_d: int = 999999
	for n: Node in _crystal_spots(pt):
		if n == null or not is_instance_valid(n):
			continue
		var cell: Vector2i = _crystal_cell(n)
		if cell.x < 0:
			continue
		var cd: int = _md(cell, boss_cell)
		var bound: bool = bool(n.get("crystal_on"))
		var closer: bool = cd + 6 < here_d and cd < toward_d
		if not closer and not (hop_if_lost and bound):
			continue
		if known_only and not bound and not PathU.revealed(pt, cell):
			continue
		if not PathU.opens_toward(pt, here, cell):
			continue
		if closer:
			toward = n
			toward_d = cd
		if bool(n.get("crystal_on")):
			var walk: int = _md(here, cell)
			if walk < hop_d:
				hop = n
				hop_d = walk
	var dest_n: Node = toward
	if dest_n == null and hop_if_lost and hop != null:
		var dung: Node = pt._dungeon()
		if dung != null and Net.local_unlocked(dung):
			dest_n = hop
	if dest_n == null:
		return false
	L.decide(pt, p, "hunt", "campaign_crystal", L.target(dest_n))
	pt._follow_goal(p, dest_n)
	pt.aim = pt._xz_to(p, dest_n)
	return true

static func _retreat_move(pt: PlayHost, p: Node) -> bool:
	var back: Vector2 = Step.retreat_dir(pt, p)
	if back == Vector2.ZERO:
		return false
	pt.path.clear()
	pt.path_i = 0
	pt.path_goal = null
	pt.move = pt._steer(p, back)
	pt.aim = back
	if pt.stuck_t > 1.0:
		pt.dash = true
		pt.just["dash"] = true
	return true

static func _known_guardian(pt: PlayHost, p: Node) -> Node:
	if pt.has_meta("guardian_door"):
		var kept: Variant = pt.get_meta("guardian_door")
		if kept is Node and is_instance_valid(kept):
			return kept as Node
		pt.remove_meta("guardian_door")
	var tree: SceneTree = pt.get_tree()
	if tree == null:
		return null
	var best: Node = null
	var best_d: float = _see_reach()
	for n: Node in tree.get_nodes_in_group("boss_door"):
		if n == null or not is_instance_valid(n):
			continue
		var dist: float = pt._dist(p, n)
		if dist <= best_d:
			best = n
			best_d = dist
	if best != null:
		pt.set_meta("guardian_door", best)
	return best

static func _bind_here(pt: PlayHost, p: Node) -> bool:
	var at: Node = null
	var at_d: float = _see_reach()
	for n: Node in _crystal_spots(pt):
		if n == null or not is_instance_valid(n) or bool(n.get("crystal_on")):
			continue
		var dist: float = pt._dist(p, n)
		if dist < at_d:
			at = n
			at_d = dist
	if at == null or not Net.volume_clear(at):
		return false
	L.decide(pt, p, "hunt", "campaign_crystal", L.target(at))
	if at_d < 1.85:
		Net.activate(at)
		pt.path.clear()
		pt.path_goal = null
		pt.move = Vector2.ZERO
		return true
	pt._follow_goal(p, at)
	pt.aim = pt._xz_to(p, at)
	return true

static func _haul(pt: PlayHost, p: Node) -> bool:
	if int(pt._gather_cargo()) < HAUL:
		return false
	var clerk: Node = pt._best_clerk(p)
	if clerk == null or not is_instance_valid(clerk) or not _wants_clerk(pt, clerk):
		return false
	if not pt._has_path(p, clerk):
		return false
	U._lock(pt, clerk, 4.0)
	L.decide(pt, p, "clerk", "campaign_extract", L.target(clerk))
	use_prop(pt, p, clerk)
	return true

static func _gather_near(pt: PlayHost, p: Node) -> bool:
	var node: Node = pt._best_gather(p)
	if node == null or not is_instance_valid(node):
		return false
	if pt._dist(p, node) > GATHER or not U.can_use(pt, node) or _is_junk(pt, node):
		return false
	U._lock(pt, node, 6.0)
	L.decide(pt, p, "gather", "campaign_gather", L.target(node))
	use_prop(pt, p, node)
	return true

static func _seek_mark(pt: PlayHost, cell: Vector2i) -> Node3D:
	var mark: Node3D = pt.get_node_or_null("CampaignSeekMark") as Node3D
	if mark == null:
		mark = Node3D.new()
		mark.name = "CampaignSeekMark"
		pt.add_child(mark)
	mark.global_position = Vector3(float(cell.x) + 0.5, 0.0, float(cell.y) + 0.5)
	return mark

static func _explore(pt: PlayHost, p: Node, delta: float) -> bool:
	var here: Vector2i = pt._cell_of_node(p)
	var fresh: Vector2i = PathU.frontier_goal(pt, here)
	if fresh != here:
		if _crystal_here(pt, p, fresh):
			return true
		if _crystal_detour(pt, p, fresh, false, true):
			return true
		var same_mark: bool = false
		if pt.has_meta("seek_mark_cell"):
			var prev_c: Variant = pt.get_meta("seek_mark_cell")
			same_mark = prev_c is Vector2i and (prev_c as Vector2i) == fresh
		pt.set_meta("seek_mark_cell", fresh)
		var mark: Node3D = _seek_mark(pt, fresh)
		if not same_mark:
			pt.path.clear()
			pt.path_i = 0
			pt.path_goal = null
		pt.set_meta("campaign_slip", 0.0)
		L.decide(pt, p, "wander", "campaign_seek", L.target(mark))
		pt._follow_goal(p, mark)
		pt.aim = pt._xz_to(p, mark)
		return true
	if _retreat_move(pt, p):
		L.decide(pt, p, "wander", "campaign_back")
		return true
	return _explore_slip(pt, p, null, delta)

static func _explore_slip(pt: PlayHost, p: Node, goal: Node, delta: float) -> bool:
	if _tight(pt, p, delta):
		pt.set_meta("campaign_slip", 1.6)
		pt.set_meta("campaign_hold", 0.0)
		if goal != null:
			pt.set_meta("campaign_side", _slip_side(pt, p, goal))
	var slip: float = U._meta_f(pt, "campaign_slip", 0.0)
	if slip <= 0.0:
		pt.move = Vector2.ZERO
		L.decide(pt, p, "wander", "campaign_seek")
		return true
	pt.set_meta("campaign_slip", maxf(0.0, slip - delta))
	pt.path.clear()
	pt.path_goal = null
	var side: Vector2 = pt._any_open(p)
	if goal != null:
		side = _slip_side(pt, p, goal)
		if pt.has_meta("campaign_side") and pt.get_meta("campaign_side") is Vector2:
			side = pt.get_meta("campaign_side")
	pt.move = pt._steer(p, side)
	pt.dash = true
	pt.just["dash"] = true
	L.decide(pt, p, "wander", "campaign_slip", L.target(goal))
	return true


static func _living_boss(pt: PlayHost, p: Node) -> Node:
	var tree: SceneTree = pt.get_tree()
	if tree == null:
		return null
	var best: Node = null
	var best_d: float = 100000.0
	for n: Node in tree.get_nodes_in_group("boss"):
		if not U.alive_enemy(n):
			continue
		var dist: float = pt._dist(p, n)
		if best == null or dist < best_d:
			best = n
			best_d = dist
	return best

static func _floor_stairs(pt: PlayHost) -> Node:
	var dungeon: Node = pt._dungeon()
	if dungeon == null:
		return null
	var stairs: Variant = dungeon.get("stairs")
	if stairs is Node and is_instance_valid(stairs):
		return stairs as Node
	return null
