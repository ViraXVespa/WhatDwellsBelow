extends Object

## Wall ribbon spans. Shared ends miter on the solid side; a long or parallel join bevels.

const T := preload("res://scripts/data/tunables.gd")
const Fold := preload("res://scripts/graphics/wall_mesh/mesh_fold.gd")
const Quad := preload("res://scripts/graphics/wall_mesh/mesh_quad.gd")

const Join := preload("res://scripts/graphics/wall_mesh/mesh_span_join.gd")
const Bevel := preload("res://scripts/graphics/wall_mesh/mesh_span_bevel.gd")
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
			Join._join_two(hits[0] as Dictionary, hits[1] as Dictionary, T.WALL_H, verts, norms, uvs, indices)
		else:
			Join._join_many(hits, T.WALL_H, verts, norms, uvs, indices)

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
