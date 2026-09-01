# Utilities for PlaytestLog

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


static func _maybe_combat(pt: Node, last_combat_kills: int, last_combat_dealt: float, last_combat_taken: float) -> Dictionary:
	if App.tel == null:
		return {"changed": false}
	var kills: int = int(App.tel.kills)
	var dealt: float = float(App.tel.dmg_dealt)
	var taken: float = float(App.tel.dmg_taken)
	if kills == last_combat_kills and is_equal_approx(dealt, last_combat_dealt) and is_equal_approx(taken, last_combat_taken):
		return {"changed": false}
	return {
		"changed": true,
		"event": {
			"ev": "combat",
			"t": _t(pt),
			"kills": kills,
			"dk": kills - last_combat_kills,
			"dealt": snappedf(dealt, 0.1),
			"taken": snappedf(taken, 0.1),
		},
		"kills": kills,
		"dealt": dealt,
		"taken": taken,
	}


static func _coalesce_step(events: Array, ev: Dictionary) -> bool:
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


static func _flush(file_name: String, events: Array, end_cond: String, end_fail: String) -> void:
	if file_name == "":
		file_name = "unknown.json"
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
