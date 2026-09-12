extends Object

const PlaytestLogUtil := preload("res://scripts/debug/playtest_log_util.gd")

static func decide(pt: Node, p: Node, name: String, why: String, extra: Dictionary = {}) -> void:
	var _fac = load("res://scripts/debug/playtest_log_core.gd")
	var t: float = PlaytestLogUtil._t(pt)
	if name == _fac.last_goal and why == str(pt.get_meta("decide_why", "")) and t - _fac.last_decide_t < 2.0:
		return
	_fac.last_goal = name
	_fac.last_decide_t = t
	pt.set_meta("decide_why", why)
	var cargo: int = int(App.gold)
	if App.get("ore") != null:
		cargo += int(App.ore)
	if App.get("wood") != null:
		cargo += int(App.wood)
	var near: Array = PlaytestLogUtil._near(pt, p)
	var scanned: Dictionary = load("res://scripts/debug/playtest_log.gd")._scan_dists(near)
	var clerk_d: float = float(scanned.clerk_d)
	var gather_d: float = float(scanned.gather_d)
	var foe_d: float = float(scanned.foe_d)
	var chest_d: float = float(scanned.chest_d)
	var door_d: float = float(scanned.door_d)
	var mail_d: float = float(scanned.mail_d)
	var boss_d: float = float(scanned.boss_d)
	var ev: Dictionary = {
		"ev": "decide",
		"t": t,
		"goal": name,
		"why": why,
		"floor": App.floor_n,
		"cell": PlaytestLogUtil._xy(pt, p),
		"cargo": cargo,
		"hp": int(round(float(App.hp))),
		"gold": int(App.gold),
	}
	if foe_d < 99.0:
		ev["foe_d"] = snappedf(foe_d, 0.1)
	if gather_d < 99.0:
		ev["gather_d"] = snappedf(gather_d, 0.1)
	if clerk_d < 99.0:
		ev["clerk_d"] = snappedf(clerk_d, 0.1)
	if chest_d < 99.0:
		ev["chest_d"] = snappedf(chest_d, 0.1)
	if door_d < 99.0:
		ev["door_d"] = snappedf(door_d, 0.1)
	if mail_d < 99.0:
		ev["mail_d"] = snappedf(mail_d, 0.1)
	if boss_d < 99.0:
		ev["boss_d"] = snappedf(boss_d, 0.1)
	if pt.lock != null:
		ev["lock_k"] = PlaytestLogUtil._node_key(pt.lock)
	if extra.size() > 0:
		ev.merge(extra)
	_fac.events.append(ev)

static func step(pt: Node, p: Node) -> void:
	var _fac = load("res://scripts/debug/playtest_log_core.gd")
	var t: float = PlaytestLogUtil._t(pt)
	var pos: Vector3 = (p as Node3D).global_position
	var here: Vector2i = pt._cell_of_pos(pos)
	var moved: float = 0.0
	if _fac.last_step_pos != Vector3.ZERO:
		moved = _fac.last_step_pos.distance_to(pos)
	if here == _fac.last_step_cell and t - _fac.last_step_t < 0.3:
		return
	_fac.last_step_t = t
	_fac.last_step_cell = here
	_fac.last_step_pos = pos
	var aim: Vector2 = pt.aim
	var move: Vector2 = pt.move
	var mismatch: bool = aim.length() > 0.2 and move.length() > 0.2 and aim.normalized().dot(move.normalized()) < 0.25
	var stuck: bool = false
	if here == _fac.last_step_cell and not mismatch and t > 1.0 and moved < 0.2:
		stuck = true
	var ev: Dictionary = {
		"ev": "step",
		"t": t,
		"cell": [here.x, here.y],
		"goal": _fac.last_goal,
	}
	if mismatch:
		ev["mis"] = 1
	if stuck:
		ev["stuck"] = 1
	if _fac.last_goal == "wander":
		ev["wander"] = 1
	if PlaytestLogUtil._coalesce_step(_fac.events, ev):
		return
	_fac.events.append(ev)
