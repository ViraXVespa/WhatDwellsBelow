extends Object

## Baked game version + current-series changelog. Git is the ledger; these JSON files are the copy Godot reads.

const VERSION_PATH := "res://scripts/data/version.json"
const LOG_PATH := "res://scripts/data/changelog.json"
const PAGES_CHANGELOG := "https://viraxvespa.github.io/WhatDwellsBelow/changelog/"


static func label() -> String:
	var d := _read_json(VERSION_PATH)
	var s := str(d.get("label", "")).strip_edges()
	if s != "":
		return s
	var e := int(d.get("epoch", 0))
	var series := int(d.get("series", 0))
	var patch := int(d.get("patch", 0))
	return "%d.%d.%d" % [e, series, patch]


static func series_key() -> String:
	var d := _read_json(VERSION_PATH)
	return "%d.%d" % [int(d.get("epoch", 0)), int(d.get("series", 0))]


static func cmp(a: String, b: String) -> int:
	var pa := _parts(a)
	var pb := _parts(b)
	for i in 3:
		if pa[i] < pb[i]:
			return -1
		if pa[i] > pb[i]:
			return 1
	return 0


static func is_blank(ver: String) -> bool:
	return ver.strip_edges() == ""


static func same_series(a: String, b: String) -> bool:
	var pa := _parts(a)
	var pb := _parts(b)
	return pa[0] == pb[0] and pa[1] == pb[1]


static func entries() -> Array:
	var raw: Variant = _read_json(LOG_PATH).get("entries", [])
	if raw is Array:
		return raw
	return []


static func unseen(last_seen: String) -> Dictionary:
	var cur := label()
	var out: Array = []
	var older_series := false
	if is_blank(last_seen):
		var one := _entry_for(cur)
		if not one.is_empty():
			out.append(one)
		return {"entries": out, "older_series": false, "current": cur}
	if cmp(cur, last_seen) <= 0:
		return {"entries": out, "older_series": false, "current": cur}
	if not same_series(last_seen, cur):
		older_series = true
	for e in entries():
		if typeof(e) != TYPE_DICTIONARY:
			continue
		var lab := str((e as Dictionary).get("label", ""))
		if lab == "":
			continue
		if older_series:
			if same_series(lab, cur) and cmp(lab, last_seen) > 0:
				out.append(e)
		elif cmp(lab, last_seen) > 0:
			out.append(e)
	out.sort_custom(func(x, y): return cmp(str(x.get("label", "")), str(y.get("label", ""))) > 0)
	return {"entries": out, "older_series": older_series, "current": cur}


static func format_entry(e: Dictionary) -> String:
	var lab := str(e.get("label", ""))
	var lines: PackedStringArray = ["## %s" % lab]
	var points: Variant = e.get("points", [])
	if points is Array:
		for p in points:
			if typeof(p) == TYPE_DICTIONARY:
				lines.append("- %s" % str((p as Dictionary).get("text", "")))
				var subs: Variant = (p as Dictionary).get("subs", [])
				if subs is Array:
					for s in subs:
						lines.append("-- %s" % str(s))
			else:
				lines.append("- %s" % str(p))
	var summary := str(e.get("summary", "")).strip_edges()
	if summary != "":
		lines.append("")
		lines.append("Summary: %s" % summary)
	return "\n".join(lines)


static func _entry_for(lab: String) -> Dictionary:
	for e in entries():
		if typeof(e) == TYPE_DICTIONARY and str((e as Dictionary).get("label", "")) == lab:
			return e
	return {}


static func _parts(ver: String) -> Array:
	var bits := ver.strip_edges().split(".")
	var out: Array = [0, 0, 0]
	for i in mini(3, bits.size()):
		if bits[i].is_valid_int():
			out[i] = int(bits[i])
	return out


static func _read_json(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		return {}
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		return {}
	var j := JSON.new()
	if j.parse(f.get_as_text()) != OK:
		return {}
	var parsed: Variant = j.data
	if parsed is Dictionary:
		return parsed
	return {}
