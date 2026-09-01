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


static func _tool_name() -> String:
	if App.prog:
		return str(App.prog.tool_type)
	return "pickaxe"


static func _kind_tool_ok(k: String) -> bool:
	var tool: String = _tool_name()
	if k == "wood":
		return tool == "hatchet"
	if k == "mine":
		return tool == "pickaxe"
	return true


static func _banned_n(pt: Node, n: Node) -> bool:
	if n == null or not pt.has_meta("skip_list"):
		return false
	var a: Variant = pt.get_meta("skip_list")
	return a is Array and (a as Array).has(n)


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
		var k: String = str(n.get("kind"))
		var row: Array = [k, snappedf(d, 0.1), c.x, c.y]
		var flags: Dictionary = {}
		if n.get("used") == true:
			flags["used"] = 1
		if k == "mine" or k == "wood":
			flags["hits"] = int(n.get("hits"))
			if not _kind_tool_ok(k):
				flags["tool"] = 0
		if _banned_n(pt, n):
			flags["ban"] = 1
		if not flags.is_empty():
			row.append(flags)
		out.append(row)
	out.sort_custom(func(a: Array, b: Array) -> bool: return float(a[1]) < float(b[1]))
	if out.size() > 6:
		out.resize(6)
	return out


static func _skip_hint(pt: Node, p: Node) -> String:
	if p == null or pt.get_tree() == null:
		return ""
	var best: Node = null
	var best_d: float = 8.0
	for n: Node in pt.get_tree().get_nodes_in_group("interact"):
		if n == null or not is_instance_valid(n):
			continue
		var k: String = str(n.get("kind"))
		if k.find("crystal") >= 0:
			continue
		var d: float = pt._dist(p, n)
		if d < best_d:
			best_d = d
			best = n
	if best == null:
		return ""
	var k: String = str(best.get("kind"))
	if _banned_n(pt, best):
		return "banned:" + k
	if best.get("used") == true:
		return "used:" + k
	if (k == "mine" or k == "wood") and not _kind_tool_ok(k):
		return "wrong_tool:" + k
	if (k == "mine" or k == "wood") and int(best.get("hits")) <= 0:
		return "hits0:" + k
	return ""


static func _lock_fields(pt: Node, p: Node) -> Dictionary:
	var out: Dictionary = {}
	if not pt.has_meta("lock_n"):
		return out
	var n: Variant = pt.get_meta("lock_n")
	if n == null or not is_instance_valid(n):
		return out
	var node: Node = n
	out["lock_k"] = str(node.get("kind"))
	out["lock_c"] = _xy(pt, node)
	if p:
		out["lock_d"] = snappedf(pt._dist(p, node), 0.1)
	if pt.has_meta("lock_t"):
		out["lock_t"] = snappedf(float(pt.get_meta("lock_t")), 0.1)
	return out


static func _path_fields(pt: Node) -> Dictionary:
	var out: Dictionary = {}
	var path: Variant = pt.get("path")
	if path == null or not (path is Array) or (path as Array).is_empty():
		return out
	var arr: Array = path
	var i: int = 0
	if pt.get("path_i") != null:
		i = clampi(int(pt.path_i), 0, arr.size() - 1)
	var a: Variant = arr[i]
	var b: Variant = arr[arr.size() - 1]
	if a is Vector2i:
		out["p0"] = [(a as Vector2i).x, (a as Vector2i).y]
	elif a is Vector2:
		out["p0"] = [int(round((a as Vector2).x)), int(round((a as Vector2).y))]
	if b is Vector2i:
		out["pe"] = [(b as Vector2i).x, (b as Vector2i).y]
	elif b is Vector2:
		out["pe"] = [int(round((b as Vector2).x)), int(round((b as Vector2).y))]
	out["pn"] = arr.size()
	return out


static func _wd(pt: Node) -> String:
	if pt.get("wander_dir") == null:
		return ""
	return _cmd(pt.wander_dir)


static func _seen_n(pt: Node) -> int:
	if not pt.has_meta("seen_map"):
		return 0
	var m: Variant = pt.get_meta("seen_map")
	if m is Dictionary:
		return (m as Dictionary).size()
	return 0


static func _tgt_cell(pt: Node, extra: Dictionary) -> Dictionary:
	var out: Dictionary = {}
	if extra.has("tgt_c"):
		return out
	if not pt.has_meta("lock_n"):
		var g: Variant = pt.get("path_goal")
		if g != null and is_instance_valid(g):
			out["tgt_c"] = _xy(pt, g)
		return out
	var n: Variant = pt.get_meta("lock_n")
	if n != null and is_instance_valid(n):
		out["tgt_c"] = _xy(pt, n)
	return out


static func _use_fields(pt: Node, p: Node) -> Dictionary:
	var out: Dictionary = {}
	if not pt.interact:
		return out
	var n: Node = null
	if pt.path_goal != null and is_instance_valid(pt.path_goal):
		n = pt.path_goal
	elif pt.has_meta("lock_n"):
		var v: Variant = pt.get_meta("lock_n")
		if v != null and is_instance_valid(v):
			n = v
	if n == null:
		return out
	var k: String = str(n.get("kind"))
	out["use_k"] = k
	if n.get("used") == true:
		out["used"] = 1
	if k == "mine" or k == "wood":
		out["hits"] = int(n.get("hits"))
		out["use_ok"] = 1 if _kind_tool_ok(k) else 0
	else:
		out["use_ok"] = 0 if n.get("used") == true else 1
	return out


static func _beat_perf() -> Dictionary:
	var out: Dictionary = {}
	var fps: float = Engine.get_frames_per_second()
	if fps > 0.0 and fps < 50.0:
		out["fps"] = snappedf(fps, 0.1)
	return out


static func _relabel(why: String, clerk_d: float, gather_d: float, cargo: int) -> String:
	if why != "not_path" and why != "no_local_prop":
		return why
	if cargo > 0:
		return "no_clerk" if clerk_d < 0.0 else ("clerk_far" if clerk_d > 40.0 else "clerk_gated")
	if gather_d < 0.0:
		return "no_gather"
	return "gather_far" if gather_d > 16.0 else why


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
	for k: String in ["cmd", "g", "o", "p", "goal"]:
		if str(prev.get(k, "")) != str(ev.get(k, "")):
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
