extends Object

## Wall ribbon spans, corner closes, and corner posts.

const T := preload("res://scripts/data/tunables.gd")
const Fold := preload("res://scripts/graphics/wall_mesh_fold.gd")
const Quad := preload("res://scripts/graphics/wall_mesh_quad.gd")

static func _push_span(run: Dictionary, verts: PackedVector3Array, norms: PackedVector3Array, uvs: PackedVector2Array, indices: PackedInt32Array) -> void:
	var o: Vector2 = run["origin"] as Vector2
	var d: Vector2 = run["delta"] as Vector2
	if d.length_squared() < 0.04:
		return
	var n2: Vector2 = run["normal"] as Vector2
	if n2.length_squared() < 0.0001:
		n2 = Vector2(-d.y, d.x)
	n2 = n2.normalized()
	var thick: float = float(run.get("thick", 0.25))
	if thick <= 0.0 or thick > 1.5:
		thick = 0.25
	thick = minf(thick, 0.3)
	var v: Vector2 = n2 * -thick
	var a: Vector2 = o
	var b: Vector2 = o + d
	var a2: Vector2 = a + v
	var b2: Vector2 = b + v
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
static func _close_ribbon_corners(runs: Array[Dictionary], verts: PackedVector3Array, norms: PackedVector3Array, uvs: PackedVector2Array, indices: PackedInt32Array) -> void:
	var pts: Dictionary = {}
	var i: int = 0
	while i < runs.size():
		var run: Dictionary = runs[i]
		var o: Vector2 = run["origin"] as Vector2
		var d: Vector2 = run["delta"] as Vector2
		var b: Vector2 = o + d
		var ka: Vector2i = Fold._pt_key(o)
		var kb: Vector2i = Fold._pt_key(b)
		if not pts.has(ka):
			pts[ka] = []
		if not pts.has(kb):
			pts[kb] = []
		(pts[ka] as Array).append({"i": i, "end": "a", "n": run.get("normal", Vector2.ZERO), "thick": float(run.get("thick", 0.25)), "p": o})
		(pts[kb] as Array).append({"i": i, "end": "b", "n": run.get("normal", Vector2.ZERO), "thick": float(run.get("thick", 0.25)), "p": b})
		i += 1
	for key in pts.keys():
		var hits: Array = pts[key]
		if hits.size() < 2:
			continue
		var nsum: Vector2 = Vector2.ZERO
		var thick: float = 0.25
		var p: Vector2 = (hits[0] as Dictionary)["p"]
		for raw in hits:
			var hit: Dictionary = raw
			var ri: int = int(hit["i"])
			var run2: Dictionary = runs[ri]
			if str(hit["end"]) == "a":
				run2["cap_a"] = false
			else:
				run2["cap_b"] = false
			nsum += hit["n"] as Vector2
			thick = maxf(thick, float(hit["thick"]))
			p = hit["p"] as Vector2
		if nsum.length_squared() < 0.0001:
			nsum = Vector2.DOWN
		_corner_post(p, nsum.normalized(), thick, T.WALL_H, verts, norms, uvs, indices)
static func _corner_post(p: Vector2, n2: Vector2, thick: float, h: float, verts: PackedVector3Array, norms: PackedVector3Array, uvs: PackedVector2Array, indices: PackedInt32Array) -> void:
	var t: float = clampf(thick, 0.2, 0.3)
	var nx: float = 0.0
	var nz: float = 0.0
	if absf(n2.x) >= 0.01:
		nx = -t if n2.x > 0.0 else t
	if absf(n2.y) >= 0.01:
		nz = -t if n2.y > 0.0 else t
	if absf(nx) < 0.01 and absf(nz) < 0.01:
		nx = -t
		nz = -t
	var x0: float = p.x if nx >= 0.0 else p.x + nx
	var x1: float = p.x + nx if nx >= 0.0 else p.x
	var z0: float = p.y if nz >= 0.0 else p.y + nz
	var z1: float = p.y + nz if nz >= 0.0 else p.y
	if x1 < x0:
		var sx: float = x0
		x0 = x1
		x1 = sx
	if z1 < z0:
		var sz: float = z0
		z0 = z1
		z1 = sz
	var y0: float = 0.0
	var y1: float = h
	var west: PackedVector3Array = PackedVector3Array()
	west.append(Vector3(x0, y0, z0))
	west.append(Vector3(x0, y0, z1))
	west.append(Vector3(x0, y1, z1))
	west.append(Vector3(x0, y1, z0))
	Quad._quad(west, Vector3.LEFT, verts, norms, uvs, indices)
	Quad._uv4(uvs, Vector2(0.0, 0.0), Vector2(t, 0.0), Vector2(t, h), Vector2(0.0, h))
	var east: PackedVector3Array = PackedVector3Array()
	east.append(Vector3(x1, y0, z1))
	east.append(Vector3(x1, y0, z0))
	east.append(Vector3(x1, y1, z0))
	east.append(Vector3(x1, y1, z1))
	Quad._quad(east, Vector3.RIGHT, verts, norms, uvs, indices)
	Quad._uv4(uvs, Vector2(0.0, 0.0), Vector2(t, 0.0), Vector2(t, h), Vector2(0.0, h))
	var north: PackedVector3Array = PackedVector3Array()
	north.append(Vector3(x0, y0, z1))
	north.append(Vector3(x1, y0, z1))
	north.append(Vector3(x1, y1, z1))
	north.append(Vector3(x0, y1, z1))
	Quad._quad(north, Vector3.FORWARD, verts, norms, uvs, indices)
	Quad._uv4(uvs, Vector2(0.0, 0.0), Vector2(t, 0.0), Vector2(t, h), Vector2(0.0, h))
	var south: PackedVector3Array = PackedVector3Array()
	south.append(Vector3(x1, y0, z0))
	south.append(Vector3(x0, y0, z0))
	south.append(Vector3(x0, y1, z0))
	south.append(Vector3(x1, y1, z0))
	Quad._quad(south, Vector3.BACK, verts, norms, uvs, indices)
	Quad._uv4(uvs, Vector2(0.0, 0.0), Vector2(t, 0.0), Vector2(t, h), Vector2(0.0, h))
	var top: PackedVector3Array = PackedVector3Array()
	top.append(Vector3(x0, y1, z0))
	top.append(Vector3(x0, y1, z1))
	top.append(Vector3(x1, y1, z1))
	top.append(Vector3(x1, y1, z0))
	Quad._quad(top, Vector3.UP, verts, norms, uvs, indices)
	Quad._uv4(uvs, Vector2(0.0, 0.0), Vector2(t, 0.0), Vector2(t, t), Vector2(0.0, t))
