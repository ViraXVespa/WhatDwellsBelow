extends Object

const PlaytestLog := preload("res://scripts/debug/playtest_log.gd")
const PlaytestLogUtil := preload("res://scripts/debug/playtest_log_util.gd")
const KEEP := 3


static var active: bool = false
static var stamp: String = ""
static var runs: Array = []


static func begin() -> void:
	active = true
	runs = []
	var now: Dictionary = Time.get_datetime_dict_from_system()
	stamp = "batch_%04d%02d%02d_%02d%02d%02d" % [
		int(now.year), int(now.month), int(now.day),
		int(now.hour), int(now.minute), int(now.second),
	]


static func note_run() -> void:
	if not active:
		begin()
	var events: Array = PlaytestLog.events
	var file_name: String = PlaytestLog.file_name
	var header: Dictionary = {}
	if events.size() > 0 and events[0] is Dictionary and str(events[0].get("ev", "")) == "begin":
		header = events[0]
	var tel: Dictionary = PlaytestLogUtil._tel_slim()
	var body: Dictionary = {
		"kind": "wdb_playtest_journal",
		"ver": 2,
		"file": file_name,
		"cards": "EWNS",
		"header": header,
		"events": events.duplicate(true),
		"godot": PlaytestLogUtil._godot(),
		"written": Time.get_datetime_string_from_system(false, true),
		"end_cond": PlaytestLog.end_cond,
		"fail": PlaytestLog.end_fail,
	}
	if not tel.is_empty():
		body["tel"] = tel
	runs.append(body)


static func close() -> PackedStringArray:
	var out: PackedStringArray = PackedStringArray()
	if runs.is_empty():
		active = false
		stamp = ""
		_prune()
		return out
	if stamp == "":
		var now: Dictionary = Time.get_datetime_dict_from_system()
		stamp = "batch_%04d%02d%02d_%02d%02d%02d" % [
			int(now.year), int(now.month), int(now.day),
			int(now.hour), int(now.minute), int(now.second),
		]
	var dir: String = PlaytestLogUtil._dir()
	var json_path: String = dir.path_join(stamp + ".json")
	var txt_path: String = dir.path_join(stamp + ".txt")
	var files: Array = []
	for row: Variant in runs:
		if row is Dictionary:
			files.append(str((row as Dictionary).get("file", "")))
	var bundle: Dictionary = {
		"kind": "wdb_playtest_batch",
		"ver": 1,
		"written": Time.get_datetime_string_from_system(false, true),
		"n": runs.size(),
		"files": files,
		"runs": runs,
	}
	var jf: FileAccess = FileAccess.open(json_path, FileAccess.WRITE)
	if jf:
		jf.store_string(JSON.stringify(bundle))
		jf.close()
		out.append(json_path)
	var tf: FileAccess = FileAccess.open(txt_path, FileAccess.WRITE)
	if tf:
		tf.store_string(_digest())
		tf.close()
		out.append(txt_path)
	active = false
	runs = []
	stamp = ""
	_prune()
	return out


static func _rm(path: String) -> void:
	if path == "" or not FileAccess.file_exists(path):
		return
	DirAccess.remove_absolute(path)


static func _drop_batch(dir_path: String, json_name: String) -> void:
	var json_path: String = dir_path.path_join(json_name)
	var f: FileAccess = FileAccess.open(json_path, FileAccess.READ)
	if f:
		var parsed: Variant = JSON.parse_string(f.get_as_text())
		f.close()
		if parsed is Dictionary:
			var body: Dictionary = parsed
			for fn: Variant in body.get("files", []):
				_rm(dir_path.path_join(str(fn)))
			for row: Variant in body.get("runs", []):
				if row is Dictionary:
					var rf: String = str((row as Dictionary).get("file", ""))
					if rf != "":
						_rm(dir_path.path_join(rf))
	_rm(json_path)
	_rm(dir_path.path_join(json_name.trim_suffix(".json") + ".txt"))


static func _prune() -> void:
	var dir_path: String = PlaytestLogUtil._dir()
	var da: DirAccess = DirAccess.open(dir_path)
	if da == null:
		return
	var batches: Array = []
	da.list_dir_begin()
	var name: String = da.get_next()
	while name != "":
		if not da.current_is_dir() and name.begins_with("batch_") and name.ends_with(".json"):
			batches.append(name)
		name = da.get_next()
	da.list_dir_end()
	batches.sort()
	while batches.size() > KEEP:
		var drop: String = str(batches[0])
		batches.remove_at(0)
		_drop_batch(dir_path, drop)
	var keep: Dictionary = {}
	for bn: Variant in batches:
		keep[str(bn)] = true
		keep[str(bn).trim_suffix(".json") + ".txt"] = true
		var jf: FileAccess = FileAccess.open(dir_path.path_join(str(bn)), FileAccess.READ)
		if jf == null:
			continue
		var parsed: Variant = JSON.parse_string(jf.get_as_text())
		jf.close()
		if not (parsed is Dictionary):
			continue
		for fn: Variant in (parsed as Dictionary).get("files", []):
			keep[str(fn)] = true
		for row: Variant in (parsed as Dictionary).get("runs", []):
			if row is Dictionary:
				var rf: String = str((row as Dictionary).get("file", ""))
				if rf != "":
					keep[rf] = true
	da = DirAccess.open(dir_path)
	if da == null:
		return
	da.list_dir_begin()
	name = da.get_next()
	while name != "":
		if not da.current_is_dir() and not keep.has(name):
			if name.begins_with("batch_") or name.begins_with("run_"):
				_rm(dir_path.path_join(name))
		name = da.get_next()
	da.list_dir_end()


static func _digest() -> String:
	var lines: PackedStringArray = PackedStringArray()
	lines.append("WDB playtest batch %s  n=%d" % [stamp, runs.size()])
	lines.append("dir: " + PlaytestLogUtil._dir())
	lines.append("Send this .txt for a first pass. Attach the matching batch_*.json if a flag needs the raw events.")
	lines.append("")
	var i: int = 0
	for row: Variant in runs:
		i += 1
		if not (row is Dictionary):
			continue
		var body: Dictionary = row
		var header: Dictionary = body.get("header", {})
		if not (header is Dictionary):
			header = {}
		var tel: Dictionary = body.get("tel", {})
		if not (tel is Dictionary):
			tel = {}
		var events: Array = body.get("events", [])
		if not (events is Array):
			events = []
		var save: String = str(header.get("save", tel.get("save_type", "")))
		var wpn: String = str(header.get("weapon", tel.get("start_weapon", "")))
		var tool: String = str(header.get("tool", tel.get("tool", "")))
		var fail: String = str(body.get("fail", ""))
		var dur: float = float(tel.get("duration", 0.0))
		var fl: int = int(tel.get("deepest", 0))
		var kills: int = int(tel.get("kills", 0))
		var gold: int = int(tel.get("gold_gained", 0))
		var dealt: float = float(tel.get("dmg_dealt", 0.0))
		var taken: float = float(tel.get("dmg_taken", 0.0))
		lines.append("#%d %s / %s  tool=%s  fail=%s  t=%.1f fl=%d" % [i, save, wpn, tool, fail, dur, fl])
		lines.append("  file: %s" % str(body.get("file", "")))
		lines.append("  kills=%d gold=%d dealt=%.1f taken=%.1f spec=%s extract_t=%s clerk_t=%s" % [
			kills, gold, dealt, taken,
			str(tel.get("spec_n", 0)),
			str(tel.get("extract_t", -1)),
			str(tel.get("clerk_t", -1)),
		])
		lines.append("  mine_ok=%s wood_ok=%s gather_t=%s dash=%s" % [
			str(tel.get("mine_ok", 0)),
			str(tel.get("wood_ok", 0)),
			str(tel.get("gather_t", 0)),
			str(tel.get("dash_n", 0)),
		])
		var goals: Dictionary = _goal_counts(events)
		var gparts: PackedStringArray = PackedStringArray()
		for k: Variant in goals.keys():
			gparts.append("%s=%d" % [str(k), int(goals[k])])
		if gparts.size() > 0:
			lines.append("  goals: " + ", ".join(gparts))
		var flags: PackedStringArray = _flags(events)
		if flags.size() > 0:
			lines.append("  flags: " + " | ".join(flags))
		var flow: String = _goal_flow(events)
		if flow != "":
			lines.append("  flow: " + flow)
		lines.append("")
	return "\n".join(lines) + "\n"


static func _goal_counts(events: Array) -> Dictionary:
	var out: Dictionary = {}
	for ev: Variant in events:
		if not (ev is Dictionary) or str(ev.get("ev", "")) != "decide":
			continue
		var g: String = str(ev.get("goal", ""))
		if g == "":
			continue
		out[g] = int(out.get(g, 0)) + 1
	return out


static func _goal_flow(events: Array) -> String:
	var parts: PackedStringArray = PackedStringArray()
	var last: String = ""
	var n: int = 0
	for ev: Variant in events:
		if not (ev is Dictionary) or str(ev.get("ev", "")) != "decide":
			continue
		var g: String = str(ev.get("goal", ""))
		var why: String = str(ev.get("why", ""))
		var tag: String = g if why == "" else "%s:%s" % [g, why]
		if tag == last:
			n += 1
			continue
		if last != "":
			parts.append("%s×%d" % [last, n] if n > 1 else last)
		last = tag
		n = 1
	if last != "":
		parts.append("%s×%d" % [last, n] if n > 1 else last)
	if parts.size() > 24:
		parts.resize(24)
		parts.append("…")
	return " → ".join(parts)


static func _flags(events: Array) -> PackedStringArray:
	var out: PackedStringArray = PackedStringArray()
	var spin_n: int = 0
	var mis_n: int = 0
	var hold_enemy_s: float = 0.0
	var hold_t0: float = -1.0
	var gather_busy: int = 0
	var gather_n: int = 0
	var prev: Array = []
	var prev2: Array = []
	var spin_run: int = 0
	for ev: Variant in events:
		if not (ev is Dictionary):
			continue
		var kind: String = str(ev.get("ev", ""))
		if kind == "step":
			if ev.get("mis") == 1:
				mis_n += 1
			var cell: Variant = ev.get("cell", [])
			if cell is Array and (cell as Array).size() >= 2:
				var c: Array = [int(cell[0]), int(cell[1])]
				if prev2 == c and prev != c:
					spin_run += 1
					if spin_run == 3:
						spin_n += 1
				else:
					spin_run = 0
				prev2 = prev
				prev = c
		elif kind == "decide":
			var g: String = str(ev.get("goal", ""))
			if g == "gathering":
				gather_busy += 1
			if g == "gather":
				gather_n += 1
			var enemy_hold: bool = g == "hold" and (str(ev.get("kind", "")) == "" or str(ev.get("lock_k", "")).begins_with("<") or str(ev.get("tgt", "")).begins_with("@Character"))
			var t: float = float(ev.get("t", 0.0))
			if enemy_hold:
				if hold_t0 < 0.0:
					hold_t0 = t
			elif hold_t0 >= 0.0:
				hold_enemy_s += maxf(0.0, t - hold_t0)
				hold_t0 = -1.0
	if hold_t0 >= 0.0:
		hold_enemy_s += 1.0
	if spin_n > 0:
		out.append("spin_loops=%d" % spin_n)
	if mis_n > 0:
		out.append("mis_steps=%d" % mis_n)
	if hold_enemy_s >= 1.0:
		out.append("hold_enemy=%.1fs" % hold_enemy_s)
	if gather_busy > 0:
		out.append("gathering_busy=%d" % gather_busy)
	if gather_n > 0:
		out.append("gather_start=%d" % gather_n)
	return out
