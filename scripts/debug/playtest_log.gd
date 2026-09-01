extends Object

## ver 2 journal: compact JSON, no tel.cfg, packed cards, sparse beats, coalesced steps.
## cards bit order is EWNS as a 4-char "01" string.

static var events: Array = []
static var file_name: String = ""
static var started: bool = false
static var last_goal: String = ""
static var last_decide_t: float = -999.0
static var last_step_t: float = -999.0
static var last_step_cell: Vector2i = Vector2i(-999, -999)
static var last_step_pos: Vector3 = Vector3.ZERO
static var last_combat_kills: int = 0
static var last_combat_dealt: float = 0.0
static var last_combat_taken: float = 0.0
static var last_beat_gold: int = -1
static var last_beat_kills: int = -1
static var last_beat_hp: float = -1.0
static var last_beat_goal: String = ""
static var flush_n: int = 0
static var ended: bool = false
static var end_cond: String = ""
static var end_fail: String = ""


static func _t(pt: Node) -> float:
	if pt.get("sim_t") == null:
		return 0.0
	return snappedf(float(pt.sim_t), 0.1)


static func _xy(pt: Node, n: Node) -> Array:
	if n == null or not is_instance_valid(n):
		return [0, 0]
	var c: Vector2i = pt._cell_of_node(n)
	return [c.x, c.y]


static func _dir() -> String:
	var d: String = OS.get_user_data_dir().path_join("playtest").path_join("runs")
	DirAccess.make_dir_recursive_absolute(d)
	return d


static func _stamp(pt: Node) -> String:
	var now: Dictionary = Time.get_datetime_dict_from_system()
	var save: String = "fresh"
	if pt.get("job") is Dictionary:
		save = str((pt.job as Dictionary).get("save", "fresh"))
	return "run_%04d%02d%02d_%02d%02d%02d_%s_%s.json" % [
		int(now.year), int(now.month), int(now.day),
		int(now.hour), int(now.minute), int(now.second),
		save, str(App.weapon),
	]


static func _cfg_hash() -> String:
	if App.tel and App.tel.get("cfg_hash") != null:
		return str(App.tel.cfg_hash)
	return ""


static func _bits(d: Dictionary) -> String:
	var s: String = ""
	for k: String in ["e", "w", "n", "s"]:
		s += "1" if d.get(k) == true else "0"
	return s


static func _cmd(want: Vector2) -> String:
	if want.length() < 0.15:
		return ""
	if absf(want.x) >= absf(want.y):
		return "e" if want.x > 0.0 else "w"
	return "s" if want.y > 0.0 else "n"


static func _best_d(pt: Node, p: Node, n: Node) -> float:
	if n == null or not is_instance_valid(n) or p == null:
		return -1.0
	return snappedf(pt._dist(p, n), 0.1)


static func _near(pt: Node, p: Node, lim: float = 40.0) -> Array:
	var out: Array = []
	var tree: SceneTree = pt.get_tree()
	if tree == null or p == null:
		return out
	for n: Node in tree.get_nodes_in_group("interact"):
		if n == null or not is_instance_valid(n):
			continue
		var d: float = pt._dist(p, n)
		if d > lim:
			continue
		var c: Vector2i = pt._cell_of_node(n)
		out.append([str(n.get("kind")), snappedf(d, 0.1), c.x, c.y])
	out.sort_custom(func(a: Array, b: Array) -> bool: return float(a[1]) < float(b[1]))
	if out.size() > 6:
		out.resize(6)
	return out


static func _relabel(why: String, clerk_d: float, gather_d: float, cargo: int) -> String:
	if why != "not_path" and why != "no_local_prop":
		return why
	if cargo > 0:
		if clerk_d < 0.0:
			return "no_clerk"
		if clerk_d > 40.0:
			return "clerk_far"
		return "clerk_gated"
	if gather_d < 0.0:
		return "no_gather"
	if gather_d > 16.0:
		return "gather_far"
	return why


static func _card_open(pt: Node, p: Node) -> Dictionary:
	var keys: Array[String] = ["e", "w", "n", "s"]
	var vecs: Array[Vector2] = [Vector2.RIGHT, Vector2.LEFT, Vector2.UP, Vector2.DOWN]
	var grid: Dictionary = {}
	var open: Dictionary = {}
	var test: Dictionary = {}
	var here: Vector2i = pt._cell_of_node(p)
	var body: CharacterBody3D = p as CharacterBody3D
	for i: int in range(4):
		var k: String = keys[i]
		var v: Vector2 = vecs[i]
		var nb: Vector2i = here + Vector2i(int(round(v.x)), int(round(v.y)))
		grid[k] = pt._steer_floor(nb)
		open[k] = pt._dir_open(p, v)
		var blocked: bool = false
		if body:
			blocked = body.test_move(body.global_transform, Vector3(v.x, 0.0, v.y) * 0.42)
		test[k] = not blocked
	return {"grid": grid, "open": open, "test": test}


static func begin(pt: Node) -> void:
	events = []
	started = true
	ended = false
	end_cond = ""
	end_fail = ""
	last_goal = ""
	last_decide_t = -999.0
	last_step_t = -999.0
	last_step_cell = Vector2i(-999, -999)
	last_step_pos = Vector3.ZERO
	last_combat_kills = 0
	last_combat_dealt = 0.0
	last_combat_taken = 0.0
	last_beat_gold = -1
	last_beat_kills = -1
	last_beat_hp = -1.0
	last_beat_goal = ""
	flush_n = 0
	file_name = _stamp(pt)
	var save: String = "fresh"
	var limit: float = float(App.bal.playtest_limit)
	var scale: float = float(App.bal.playtest_scale)
	var smoke: bool = false
	if pt.get("job") is Dictionary:
		var job: Dictionary = pt.job
		save = str(job.get("save", "fresh"))
		limit = float(job.get("limit", limit))
		smoke = job.get("smoke") == true
	if pt.get("smoke_mode") == true:
		smoke = true
	events.append({
		"ev": "begin",
		"t": 0.0,
		"cfg_hash": _cfg_hash(),
		"gender": str(App.character_type),
		"limit": limit,
		"platform": OS.get_name(),
		"save": save,
		"scale": scale,
		"time_scale": Engine.time_scale,
		"smoke": smoke,
		"tool": str(App.prog.tool_type) if App.prog else "",
		"weapon": str(App.weapon),
	})
	_flush(pt)


static func wait(pt: Node, reason: String) -> void:
	if events.size() > 0:
		var last: Variant = events[events.size() - 1]
		if last is Dictionary and str(last.get("ev", "")) == "wait" and str(last.get("reason", "")) == reason:
			return
	events.append({
		"ev": "wait",
		"t": _t(pt),
		"in_dungeon": App.in_dungeon,
		"reason": reason,
		"ui_open": App.get("ui_open") == true,
	})


static func goal(pt: Node, p: Node, name: String, extra: Dictionary = {}) -> void:
	if name == last_goal and extra.is_empty():
		return
	last_goal = name
	var ev: Dictionary = {
		"ev": "goal",
		"t": _t(pt),
		"goal": name,
		"floor": App.floor_n,
		"cell": _xy(pt, p),
	}
	if extra.size() > 0:
		ev.merge(extra)
	events.append(ev)


static func act(pt: Node, p: Node) -> void:
	if not pt.dash and not pt.special and not pt.potion and not pt.interact:
		return
	var ev: Dictionary = {
		"ev": "act",
		"t": _t(pt),
		"cell": _xy(pt, p),
	}
	if pt.dash:
		ev["dash"] = 1
	if pt.special:
		ev["spec"] = 1
	if pt.potion:
		ev["pot"] = 1
	if pt.interact:
		ev["use"] = 1
	events.append(ev)


static func beat(pt: Node, p: Node) -> void:
	var gold: int = int(App.gold)
	var kills: int = int(App.tel.kills) if App.tel else 0
	var hp: float = 0.0
	if p != null and p.get("hp") != null:
		hp = float(p.hp)
	var same: bool = gold == last_beat_gold and kills == last_beat_kills and last_goal == last_beat_goal and is_equal_approx(hp, last_beat_hp)
	last_beat_gold = gold
	last_beat_kills = kills
	last_beat_hp = hp
	last_beat_goal = last_goal
	if same:
		_maybe_combat(pt)
		return
	var ev: Dictionary = {
		"ev": "beat",
		"t": _t(pt),
		"fl": App.floor_n,
		"cell": _xy(pt, p),
		"g": last_goal,
		"gold": gold,
		"hp": snappedf(hp, 0.1),
		"kills": kills,
		"stk": snappedf(float(pt.stuck_t), 0.1),
	}
	if App.extracted:
		ev["ex"] = 1
	if p != null and p.get("in_combat") == true:
		ev["cmb"] = 1
	if App.get("ore") != null and int(App.ore) != 0:
		ev["ore"] = int(App.ore)
	if App.get("wood") != null and int(App.wood) != 0:
		ev["wood"] = int(App.wood)
	events.append(ev)
	_maybe_combat(pt)
	flush_n += 1
	if flush_n >= 24:
		_flush(pt)


static func _maybe_combat(pt: Node) -> void:
	if App.tel == null:
		return
	var kills: int = int(App.tel.kills)
	var dealt: float = float(App.tel.dmg_dealt)
	var taken: float = float(App.tel.dmg_taken)
	if kills == last_combat_kills and is_equal_approx(dealt, last_combat_dealt) and is_equal_approx(taken, last_combat_taken):
		return
	events.append({
		"ev": "combat",
		"t": _t(pt),
		"kills": kills,
		"dk": kills - last_combat_kills,
		"dealt": snappedf(dealt, 0.1),
		"taken": snappedf(taken, 0.1),
	})
	last_combat_kills = kills
	last_combat_dealt = dealt
	last_combat_taken = taken


static func target(n: Node) -> Dictionary:
	if n == null or not is_instance_valid(n):
		return {}
	var is_boss: bool = n.get("is_boss") == true or n.is_in_group("boss")
	var kind: String = str(n.get("kind"))
	if kind == "<null>" or kind == "Null":
		kind = ""
	var out: Dictionary = {"tgt": n.name}
	if kind != "":
		out["kind"] = kind
	if is_boss:
		out["boss"] = 1
	return out


static func decide(pt: Node, p: Node, name: String, why: String, extra: Dictionary = {}) -> void:
	var t: float = _t(pt)
	if name == last_goal and why == str(pt.get_meta("decide_why", "")) and t - last_decide_t < 2.0:
		return
	last_goal = name
	last_decide_t = t
	pt.set_meta("decide_why", why)
	var clerk: Node = pt._best_clerk(p) if pt.has_method("_best_clerk") else null
	var gather: Node = pt._best_gather(p) if pt.has_method("_best_gather") else null
	var clerk_d: float = _best_d(pt, p, clerk)
	var gather_d: float = _best_d(pt, p, gather)
	var cargo: int = int(App.gold)
	if App.get("ore") != null:
		cargo += int(App.ore)
	if App.get("wood") != null:
		cargo += int(App.wood)
	var threat_d: float = 99.0
	var threat: Node = pt._nearest_visible_threat(p) if pt.has_method("_nearest_visible_threat") else null
	if threat:
		threat_d = snappedf(pt._dist(p, threat), 0.1)
	var bans: int = 0
	if pt.has_meta("skip_list") and pt.get_meta("skip_list") is Array:
		bans = (pt.get_meta("skip_list") as Array).size()
	if extra.has("kind") and (str(extra.kind) == "<null>" or str(extra.kind) == "Null"):
		extra.erase("kind")
	var ev: Dictionary = {
		"ev": "decide",
		"t": t,
		"goal": name,
		"why": _relabel(why, clerk_d, gather_d, cargo),
		"fl": App.floor_n,
		"cell": _xy(pt, p),
		"gold": int(App.gold),
		"cargo": cargo,
		"near": _near(pt, p),
		"threat_d": threat_d,
		"clerk_d": clerk_d,
		"gather_d": gather_d,
	}
	if why != ev["why"]:
		ev["why_raw"] = why
	if gather:
		ev["gather_k"] = str(gather.get("kind"))
	if clerk != null and pt._has_path(p, clerk):
		ev["pc"] = 1
	if gather != null and pt._has_path(p, gather):
		ev["pg"] = 1
	if bans > 0:
		ev["bans"] = bans
	if extra.size() > 0:
		ev.merge(extra)
	events.append(ev)


static func _coalesce_step(ev: Dictionary) -> bool:
	if events.is_empty():
		return false
	var last: Variant = events[events.size() - 1]
	if not (last is Dictionary) or str(last.get("ev", "")) != "step":
		return false
	var prev: Dictionary = last
	if prev.get("cell") != ev.get("cell"):
		return false
	if str(prev.get("cmd", "")) != str(ev.get("cmd", "")):
		return false
	if str(prev.get("g", "")) != str(ev.get("g", "")):
		return false
	if str(prev.get("o", "")) != str(ev.get("o", "")):
		return false
	if str(prev.get("p", "")) != str(ev.get("p", "")):
		return false
	if str(prev.get("goal", "")) != str(ev.get("goal", "")):
		return false
	prev["n"] = int(prev.get("n", 1)) + 1
	prev["t1"] = ev.get("t")
	prev["d"] = ev.get("d")
	return true


static func step(pt: Node, p: Node) -> void:
	if p == null or not is_instance_valid(p):
		return
	var t: float = _t(pt)
	var here: Vector2i = pt._cell_of_node(p)
	var pos: Vector3 = (p as Node3D).global_position
	var moved: float = 0.0
	if last_step_pos != Vector3.ZERO:
		moved = last_step_pos.distance_to(pos)
	if here == last_step_cell and t - last_step_t < 0.3:
		return
	last_step_t = t
	last_step_cell = here
	last_step_pos = pos
	var cards: Dictionary = _card_open(pt, p)
	var want: Vector2 = pt.move
	if want.length() < 0.05 and pt.get("wander_dir") != null:
		want = pt.wander_dir
	var cmd: String = _cmd(want)
	var g: String = _bits(cards.grid)
	var o: String = _bits(cards.open)
	var ts: String = _bits(cards.test)
	var mismatch: bool = g != ts or g != o
	if here == last_step_cell and not mismatch and t > 1.0 and moved < 0.2:
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
		"goal": last_goal,
	}
	if mismatch:
		ev["mis"] = 1
	if pt.get("path") != null and pt.path.size() > 0:
		ev["pn"] = pt.path.size()
	if _coalesce_step(ev):
		return
	events.append(ev)


static func finish(pt: Node, cond: String, fail: String = "") -> void:
	if ended:
		return
	ended = true
	end_cond = cond
	end_fail = fail if fail != "" else cond
	var pl: Node = null
	if pt.get_tree():
		pl = pt.get_tree().get_first_node_in_group("player")
	events.append({
		"ev": "end",
		"t": _t(pt),
		"cond": end_cond,
		"fail": end_fail,
		"ex": 1 if App.extracted else 0,
		"fl": App.floor_n,
		"goal": last_goal,
		"sim_t": snappedf(float(pt.sim_t) if pt.get("sim_t") != null else 0.0, 0.1),
		"cell": _xy(pt, pl),
	})
	_flush(pt)
	started = false


static func _godot() -> Dictionary:
	var v: Dictionary = Engine.get_version_info()
	return {
		"s": str(v.get("string", "")),
		"h": str(v.get("hash", "")),
	}


static func _tel_slim() -> Dictionary:
	if App.tel == null:
		return {}
	var raw: Dictionary = App.tel.to_dict()
	raw.erase("cfg")
	return raw


static func _flush(pt: Node) -> void:
	if file_name == "":
		file_name = _stamp(pt)
	var path: String = _dir().path_join(file_name)
	var header: Dictionary = {}
	if events.size() > 0 and events[0] is Dictionary and str(events[0].get("ev", "")) == "begin":
		header = events[0]
	var tel: Dictionary = _tel_slim()
	var cond: String = end_cond
	var fail: String = end_fail
	if cond == "" and tel.has("end_cond"):
		cond = str(tel.get("end_cond", ""))
	if fail == "" and cond != "":
		fail = cond
	var body: Dictionary = {
		"kind": "wdb_playtest_journal",
		"ver": 2,
		"file": file_name,
		"cards": "EWNS",
		"header": header,
		"events": events,
		"godot": _godot(),
		"written": Time.get_datetime_string_from_system(false, true),
		"end_cond": cond,
		"fail": fail,
	}
	if not tel.is_empty():
		body["tel"] = tel
	var f: FileAccess = FileAccess.open(path, FileAccess.WRITE)
	if f:
		f.store_string(JSON.stringify(body))
		f.close()
	flush_n = 0
