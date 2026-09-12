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
	if pt.has_meta("log_clerk_d"):
		clerk_d = float(pt.get_meta("log_clerk_d"))
	if pt.has_meta("log_gather_d"):
		gather_d = float(pt.get_meta("log_gather_d"))
	var threat_d: float = 99.0
	if pt.has_meta("log_threat_d"):
		threat_d = float(pt.get_meta("log_threat_d"))
	elif extra.has("threat_d"):
		threat_d = float(extra.threat_d)
	var bans: int = 0
	if pt.has_meta("skip_list") and pt.get_meta("skip_list") is Array:
		bans = (pt.get_meta("skip_list") as Array).size()
	if extra.has("kind") and (str(extra.kind) == "<null>" or str(extra.kind) == "Null"):
		extra.erase("kind")
	var ev: Dictionary = {
		"ev": "decide",
		"t": t,
		"goal": name,
		"why": PlaytestLogUtil._relabel(why, clerk_d, gather_d, cargo),
		"fl": App.floor_n,
		"cell": PlaytestLogUtil._xy(pt, p),
		"gold": int(App.gold),
		"cargo": cargo,
		"near": near,
		"threat_d": threat_d,
		"clerk_d": clerk_d,
		"gather_d": gather_d,
	}
	if why != ev["why"]:
		ev["why_raw"] = why
	var gk: String = str(scanned.gather_k)
	if pt.has_meta("log_gather_k"):
		gk = str(pt.get_meta("log_gather_k"))
	if gk != "":
		ev["gather_k"] = gk
	if bans > 0:
		ev["bans"] = bans
	if App.extracted:
		ev["ex"] = 1
	ev.merge(PlaytestLogUtil._lock_fields(pt, p))
	if name == "wander" or why == "explore":
		var skip: String = PlaytestLogUtil._skip_hint(pt, p)
		if skip != "":
			ev["skip"] = skip
		var wd: String = PlaytestLogUtil._wd(pt)
		if wd != "":
			ev["wd"] = wd
		var seen_n: int = PlaytestLogUtil._seen_n(pt)
		if seen_n > 0:
			ev["seen"] = seen_n
	if extra.size() > 0:
		ev.merge(extra)
	_fac.events.append(ev)

static func step(pt: Node, p: Node) -> void:
	var _fac = load("res://scripts/debug/playtest_log_core.gd")
	if p == null or not is_instance_valid(p):
		return
	var t: float = PlaytestLogUtil._t(pt)
	var here: Vector2i = pt._cell_of_node(p)
	var pos: Vector3 = (p as Node3D).global_position
	var moved: float = 0.0
	if _fac.last_step_pos != Vector3.ZERO:
		moved = _fac.last_step_pos.distance_to(pos)
	if here == _fac.last_step_cell and t - _fac.last_step_t < 0.3:
		return
	_fac.last_step_t = t
	_fac.last_step_cell = here
	_fac.last_step_pos = pos
	var cards: Dictionary = PlaytestLogUtil._card_open(pt, p)
	var want: Vector2 = pt.move
	if want.length() < 0.05 and pt.get("wander_dir") != null:
		want = pt.wander_dir
	var cmd: String = PlaytestLogUtil._cmd(want)
	var g: String = PlaytestLogUtil._bits(cards.grid)
	var o: String = PlaytestLogUtil._bits(cards.open)
	var ts: String = PlaytestLogUtil._bits(cards.test)
	var mismatch: bool = g != ts or g != o
	if here == _fac.last_step_cell and not mismatch and t > 1.0 and moved < 0.2:
		return
	var ev: Dictionary = {
		"ev": "step",
		"t": t,
		"cell": [here.x, here.y],
		"cmd": cmd,
		"g": g,
		"o": o,
		"p": ts,
		"d": snappedf(moved, 0.01),
		"goal": _fac.last_goal,
	}
	if mismatch:
		ev["mis"] = 1
	ev.merge(PlaytestLogUtil._path_fields(pt))
	ev.merge(PlaytestLogUtil._tgt_cell(pt, ev))
	if _fac.last_goal == "wander":
		var wd: String = PlaytestLogUtil._wd(pt)
		if wd != "":
			ev["wd"] = wd
	if PlaytestLogUtil._coalesce_step(_fac.events, ev):
		return
	_fac.events.append(ev)
