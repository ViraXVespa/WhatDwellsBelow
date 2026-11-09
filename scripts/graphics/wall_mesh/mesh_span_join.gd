extends Object

## Split from mesh_span.gd: _join_two, _join_many, _sort_hits....

const Bevel := preload("res://scripts/graphics/wall_mesh/mesh_span_bevel.gd")

static func _join_two(raw_a: Dictionary, raw_b: Dictionary, h: float, verts: PackedVector3Array, norms: PackedVector3Array, uvs: PackedVector2Array, indices: PackedInt32Array) -> void:
	var p: Vector2 = raw_a["p"] as Vector2
	var meet_v: Variant = _back_meet(raw_a["back"] as Vector2, raw_a["d"] as Vector2, raw_b["back"] as Vector2, raw_b["d"] as Vector2)
	var thick: float = maxf(float(raw_a["thick"]), float(raw_b["thick"]))
	if meet_v is Vector2:
		var meet: Vector2 = meet_v as Vector2
		if _miter_ok(p, meet, raw_a["n"] as Vector2, raw_b["n"] as Vector2, thick):
			_clear_cap(raw_a)
			_clear_cap(raw_b)
			_set_back(raw_a, meet)
			_set_back(raw_b, meet)
			return
	var b0: Vector2 = raw_a["back"] as Vector2
	var b1: Vector2 = raw_b["back"] as Vector2
	if b0.distance_squared_to(b1) < 0.0004:
		_clear_cap(raw_a)
		_clear_cap(raw_b)
		return
	var floor_angs: Array[float] = []
	floor_angs.append(float(raw_a["fang"]))
	floor_angs.append(float(raw_b["fang"]))
	if Bevel._bevel_if_gap(raw_a, raw_b, floor_angs, h, verts, norms, uvs, indices):
		_clear_cap(raw_a)
		_clear_cap(raw_b)

static func _join_many(hits: Array, h: float, verts: PackedVector3Array, norms: PackedVector3Array, uvs: PackedVector2Array, indices: PackedInt32Array) -> void:
	_sort_hits(hits)
	var floor_angs: Array[float] = []
	var i: int = 0
	while i < hits.size():
		var hit: Dictionary = hits[i]
		_clear_cap(hit)
		floor_angs.append(float(hit["fang"]))
		i += 1
	i = 0
	while i < hits.size():
		var nxt: int = i + 1
		if nxt >= hits.size():
			nxt = 0
		Bevel._bevel_if_gap(hits[i] as Dictionary, hits[nxt] as Dictionary, floor_angs, h, verts, norms, uvs, indices)
		i += 1

static func _sort_hits(hits: Array) -> void:
	var i: int = 1
	while i < hits.size():
		var raw: Dictionary = hits[i]
		var ang: float = float(raw["ang"])
		var j: int = i - 1
		while j >= 0 and float((hits[j] as Dictionary)["ang"]) > ang:
			hits[j + 1] = hits[j]
			j -= 1
		hits[j + 1] = raw
		i += 1

static func _back_meet(p0: Vector2, d0: Vector2, p1: Vector2, d1: Vector2) -> Variant:
	var cross: float = d0.x * d1.y - d0.y * d1.x
	if absf(cross) < 0.000001:
		return null
	var diff: Vector2 = p1 - p0
	var s: float = (diff.x * d1.y - diff.y * d1.x) / cross
	return p0 + d0 * s

static func _miter_ok(p: Vector2, meet: Vector2, n0: Vector2, n1: Vector2, thick: float) -> bool:
	var gap: Vector2 = meet - p
	if gap.length() > thick * 4.0:
		return false
	if gap.dot(-n0) < thick * 0.25:
		return false
	if gap.dot(-n1) < thick * 0.25:
		return false
	return true

static func _clear_cap(hit: Dictionary) -> void:
	var run: Dictionary = hit["run"] as Dictionary
	if str(hit["end"]) == "a":
		run["cap_a"] = false
	else:
		run["cap_b"] = false

static func _set_back(hit: Dictionary, p: Vector2) -> void:
	var run: Dictionary = hit["run"] as Dictionary
	if str(hit["end"]) == "a":
		run["back_a"] = p
	else:
		run["back_b"] = p
