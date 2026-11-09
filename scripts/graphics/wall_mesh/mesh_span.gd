extends Object

## Wall ribbon spans. Shared ends miter on the solid side; a long or parallel join bevels.

const T := preload("res://scripts/data/tunables.gd")
const Fold := preload("res://scripts/graphics/wall_mesh/mesh_fold.gd")
const Quad := preload("res://scripts/graphics/wall_mesh/mesh_quad.gd")

static func _push_span(run: Dictionary, verts: PackedVector3Array, norms: PackedVector3Array, uvs: PackedVector2Array, indices: PackedInt32Array) -> void:
	var o: Vector2 = run["origin"] as Vector2
	var d: Vector2 = run["delta"] as Vector2
	if d.length_squared() < 0.04:
		return
	var n2: Vector2 = _span_normal(run)
	var thick: float = _span_thick(run)
	var a: Vector2 = o
	var b: Vector2 = o + d
	var a2: Vector2 = a - n2 * thick
	var b2: Vector2 = b - n2 * thick
	if run.has("back_a"):
		a2 = run["back_a"] as Vector2
	if run.has("back_b"):
		b2 = run["back_b"] as Vector2
	var h: float = T.WALL_H
	var run_len: float = d.length()
	var nf: Vector3 = Vector3(n2.x, 0.0, n2.y)
	Quad._uv2_in = n2
	var cap_a: bool = true
	var cap_b: bool = true
	if run.has("cap_a"):
		cap_a = run["cap_a"] == true
	if run.has("cap_b"):
		cap_b = run["cap_b"] == true
	var front: PackedVector3Array = PackedVector3Array()
	front.append(Vector3(a.x, 0.0, a.y))
	front.append(Vector3(b.x, 0.0, b.y))
	front.append(Vector3(b.x, h, b.y))
	front.append(Vector3(a.x, h, a.y))
	Quad._quad(front, nf, verts, norms, uvs, indices)
	Quad._uv4(uvs, Vector2(0.0, 0.0), Vector2(run_len, 0.0), Vector2(run_len, h), Vector2(0.0, h))
	var back: PackedVector3Array = PackedVector3Array()
	back.append(Vector3(b2.x, 0.0, b2.y))
	back.append(Vector3(a2.x, 0.0, a2.y))
	back.append(Vector3(a2.x, h, a2.y))
	back.append(Vector3(b2.x, h, b2.y))
	Quad._quad(back, -nf, verts, norms, uvs, indices)
	Quad._uv4(uvs, Vector2(run_len, 0.0), Vector2(0.0, 0.0), Vector2(0.0, h), Vector2(run_len, h))
	var top: PackedVector3Array = PackedVector3Array()
	top.append(Vector3(a.x, h, a.y))
	top.append(Vector3(b.x, h, b.y))
	top.append(Vector3(b2.x, h, b2.y))
	top.append(Vector3(a2.x, h, a2.y))
	Quad._quad(top, Vector3.UP, verts, norms, uvs, indices)
	Quad._uv4(uvs, Vector2(0.0, 0.0), Vector2(run_len, 0.0), Vector2(run_len, thick), Vector2(0.0, thick))
	if cap_a:
		var e0: PackedVector3Array = PackedVector3Array()
		e0.append(Vector3(a.x, 0.0, a.y))
		e0.append(Vector3(a.x, h, a.y))
		e0.append(Vector3(a2.x, h, a2.y))
		e0.append(Vector3(a2.x, 0.0, a2.y))
		var n_start: Vector3 = Vector3(-d.x, 0.0, -d.y).normalized()
		Quad._quad(e0, n_start, verts, norms, uvs, indices)
		Quad._uv4(uvs, Vector2(0.0, 0.0), Vector2(0.0, h), Vector2(thick, h), Vector2(thick, 0.0))
	Quad._uv2_in = n2
	if cap_b:
		var e1: PackedVector3Array = PackedVector3Array()
		e1.append(Vector3(b.x, 0.0, b.y))
		e1.append(Vector3(b2.x, 0.0, b2.y))
		e1.append(Vector3(b2.x, h, b2.y))
		e1.append(Vector3(b.x, h, b.y))
		var n_end: Vector3 = Vector3(d.x, 0.0, d.y).normalized()
		Quad._quad(e1, n_end, verts, norms, uvs, indices)
		Quad._uv4(uvs, Vector2(0.0, 0.0), Vector2(thick, 0.0), Vector2(thick, h), Vector2(0.0, h))
static func _span_normal(run: Dictionary) -> Vector2:
	var d: Vector2 = run["delta"] as Vector2
	var n2: Vector2 = run["normal"] as Vector2
	if n2.length_squared() < 0.0001:
		n2 = Vector2(-d.y, d.x)
	if n2.length_squared() < 0.0001:
		return Vector2.DOWN
	return n2.normalized()

static func _span_thick(run: Dictionary) -> float:
	var thick: float = float(run.get("thick", 0.25))
	if thick <= 0.0 or thick > 1.5:
		thick = 0.25
	return minf(thick, 0.3)

## Degree 2 shares a back-edge miter. Longer than about 4× thick, or parallel, bevels instead.
static func _weld_joins(runs: Array[Dictionary], verts: PackedVector3Array, norms: PackedVector3Array, uvs: PackedVector2Array, indices: PackedInt32Array) -> void:
	var pts: Dictionary = {}
	var i: int = 0
	while i < runs.size():
		var run: Dictionary = runs[i]
		var d: Vector2 = run["delta"] as Vector2
		if d.length_squared() < 0.04:
			i += 1
			continue
		var o: Vector2 = run["origin"] as Vector2
		var n2: Vector2 = _span_normal(run)
		var thick: float = _span_thick(run)
		_note_end(pts, run, o, "a", n2, d, thick)
		_note_end(pts, run, o + d, "b", n2, d, thick)
		i += 1
	for key in pts.keys():
		var hits: Array = pts[key]
		if hits.size() < 2:
			continue
		if hits.size() == 2:
			_join_two(hits[0] as Dictionary, hits[1] as Dictionary, T.WALL_H, verts, norms, uvs, indices)
		else:
			_join_many(hits, T.WALL_H, verts, norms, uvs, indices)

static func _note_end(pts: Dictionary, run: Dictionary, p: Vector2, end: String, n2: Vector2, d: Vector2, thick: float) -> void:
	var key: Vector2i = Fold._pt_key(p)
	if not pts.has(key):
		pts[key] = []
	var back: Vector2 = p - n2 * thick
	var hit: Dictionary = {
		"run": run,
		"end": end,
		"p": p,
		"n": n2,
		"d": d,
		"thick": thick,
		"back": back,
		"ang": atan2(back.y - p.y, back.x - p.x),
		"fang": atan2(n2.y, n2.x),
	}
	(pts[key] as Array).append(hit)

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
	if _bevel_if_gap(raw_a, raw_b, floor_angs, h, verts, norms, uvs, indices):
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
		_bevel_if_gap(hits[i] as Dictionary, hits[nxt] as Dictionary, floor_angs, h, verts, norms, uvs, indices)
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

static func _bevel_if_gap(raw_a: Dictionary, raw_b: Dictionary, floor_angs: Array[float], h: float, verts: PackedVector3Array, norms: PackedVector3Array, uvs: PackedVector2Array, indices: PackedInt32Array) -> bool:
	var b0: Vector2 = raw_a["back"] as Vector2
	var b1: Vector2 = raw_b["back"] as Vector2
	if b0.distance_squared_to(b1) < 0.0004:
		return false
	var sweep: float = fposmod(float(raw_b["ang"]) - float(raw_a["ang"]), TAU)
	var start: float = float(raw_a["ang"])
	if sweep > PI:
		sweep = TAU - sweep
		start = float(raw_b["ang"])
	if sweep < 0.02 or sweep > PI:
		return false
	if not _wedge_clear(start, sweep, floor_angs):
		return false
	_emit_bevel(raw_a["p"] as Vector2, b0, b1, h, verts, norms, uvs, indices)
	return true

static func _wedge_clear(start: float, sweep: float, floor_angs: Array[float]) -> bool:
	var i: int = 0
	while i < floor_angs.size():
		var rel: float = fposmod(floor_angs[i] - start, TAU)
		if rel > 0.05 and rel < sweep - 0.05:
			return false
		i += 1
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

static func _emit_bevel(p: Vector2, b0: Vector2, b1: Vector2, h: float, verts: PackedVector3Array, norms: PackedVector3Array, uvs: PackedVector2Array, indices: PackedInt32Array) -> void:
	if absf((b0 - p).cross(b1 - p)) < 0.0001:
		return
	var edge: Vector2 = b1 - b0
	var right: Vector2 = Vector2(edge.y, -edge.x)
	var out_dir: Vector2 = (b0 + b1) * 0.5 - p
	if right.dot(out_dir) < 0.0:
		var swap_b: Vector2 = b0
		b0 = b1
		b1 = swap_b
		edge = b1 - b0
		right = Vector2(edge.y, -edge.x)
	var face_n: Vector2 = right.normalized()
	if face_n.length_squared() < 0.0001:
		return
	var span_w: float = edge.length()
	Quad._uv2_in = face_n
	var side: PackedVector3Array = PackedVector3Array()
	side.append(Vector3(b0.x, 0.0, b0.y))
	side.append(Vector3(b1.x, 0.0, b1.y))
	side.append(Vector3(b1.x, h, b1.y))
	side.append(Vector3(b0.x, h, b0.y))
	Quad._quad(side, Vector3(face_n.x, 0.0, face_n.y), verts, norms, uvs, indices)
	Quad._uv4(uvs, Vector2(0.0, 0.0), Vector2(span_w, 0.0), Vector2(span_w, h), Vector2(0.0, h))
	var t0: Vector2 = b0
	var t1: Vector2 = b1
	if (t0 - p).cross(t1 - p) < 0.0:
		t0 = b1
		t1 = b0
	var top: PackedVector3Array = PackedVector3Array()
	top.append(Vector3(p.x, h, p.y))
	top.append(Vector3(t0.x, h, t0.y))
	top.append(Vector3(t1.x, h, t1.y))
	_tri(top, Vector3.UP, verts, norms, uvs, indices)
	_uv3(uvs, Vector2(0.0, 0.0), Vector2(span_w, 0.0), Vector2(0.0, span_w))

static func _tri(corners: PackedVector3Array, n: Vector3, verts: PackedVector3Array, norms: PackedVector3Array, uvs: PackedVector2Array, indices: PackedInt32Array) -> void:
	var base: int = verts.size()
	var i: int = 0
	while i < corners.size():
		verts.append(corners[i])
		norms.append(n)
		uvs.append(Vector2.ZERO)
		Quad._uv2_buf.append(Quad._uv2_in)
		i += 1
	indices.append(base)
	indices.append(base + 1)
	indices.append(base + 2)

static func _uv3(uvs: PackedVector2Array, a: Vector2, b: Vector2, c: Vector2) -> void:
	var base: int = uvs.size() - 3
	uvs[base] = a
	uvs[base + 1] = b
	uvs[base + 2] = c
