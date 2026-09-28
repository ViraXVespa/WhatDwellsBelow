extends RefCounted

const T := preload("res://scripts/data/tunables.gd")
const WallRects := preload("res://scripts/world/wall_rects.gd")
const WallMesh: GDScript = preload("res://scripts/graphics/wall_mesh.gd")
const LightRt := preload("res://scripts/graphics/light_rt.gd")
const HitchLog := preload("res://scripts/debug/hitch_log.gd")

const RING_IN := 1
const RING_OUT := 2
const CHUNK := 32
const PER_FRAME := 3

static var _floor_mesh: PlaneMesh


static func setup(host: Node) -> void:
	host.geo_jobs.clear()
	if host.has_meta("wdb_ribbon_n"):
		host.remove_meta("wdb_ribbon_n")
	if host.has_meta("wdb_ribbon"):
		host.remove_meta("wdb_ribbon")
	if host.geo_root != null and is_instance_valid(host.geo_root):
		host.geo_root.queue_free()
	host.geo_root = Node3D.new()
	host.geo_root.name = "GeoStream"
	host.add_child(host.geo_root)
	ensure_meshes()


static func ensure_meshes() -> void:
	if _floor_mesh == null:
		_floor_mesh = PlaneMesh.new()
		_floor_mesh.size = Vector2(T.TILE, T.TILE)


static func chunk_origin(c: Vector2i) -> Vector2i:
	var x := c.x
	var y := c.y
	if x < 0:
		x -= CHUNK - 1
	if y < 0:
		y -= CHUNK - 1
	return Vector2i(int(x / float(CHUNK)) * CHUNK, int(y / float(CHUNK)) * CHUNK)


static func chunk_center(origin: Vector2i, w: int, h: int) -> Vector2i:
	return Vector2i(origin.x + int(mini(CHUNK, w - origin.x) / 2.0), origin.y + int(mini(CHUNK, h - origin.y) / 2.0))


static func chunk_ring(a: Vector2i, b: Vector2i) -> int:
	return maxi(int(absi(a.x - b.x) / float(CHUNK)), int(absi(a.y - b.y) / float(CHUNK)))


static func job_at(host: Node, origin: Vector2i) -> Dictionary:
	for job in host.geo_jobs:
		if Vector2i(job.origin) == origin:
			return job
	var w: int = host.data.w
	var h: int = host.data.h
	var job := {
		"cell": chunk_center(origin, w, h),
		"origin": origin,
		"state": "pending",
		"node": null,
	}
	host.geo_jobs.append(job)
	return job


static func prime_visible(host: Node) -> void:
	if host.player == null:
		return
	ensure_meshes()
	var pc: Vector2i = host._player_cell()
	var origin := chunk_origin(pc)
	var w: int = host.data.w
	var h: int = host.data.h
	var dy: int = -RING_IN
	while dy <= RING_IN:
		var dx: int = -RING_IN
		while dx <= RING_IN:
			var o := Vector2i(origin.x + dx * CHUNK, origin.y + dy * CHUNK)
			dx += 1
			if o.x < 0 or o.y < 0 or o.x >= w or o.y >= h:
				continue
			var job: Dictionary = job_at(host, o)
			if str(job.state) != "pending":
				continue
			HitchLog.mark("geo_activate", Vector2i(job.origin))
			activate_job(host, job)
		dy += 1


static func follow(host: Node, delta: float) -> void:
	if host.player == null:
		return
	ensure_meshes()
	var pc: Vector2i = host._player_cell()
	var origin := chunk_origin(pc)
	var w: int = host.data.w
	var h: int = host.data.h
	var cur: Dictionary = job_at(host, origin)
	if str(cur.state) == "pending":
		HitchLog.mark("geo_activate", Vector2i(cur.origin))
		activate_job(host, cur)
	var last: Vector2i = Vector2i(-9999, -9999)
	if host.has_meta("wdb_geo_origin"):
		last = host.get_meta("wdb_geo_origin")
	host.set_meta("wdb_geo_origin", origin)
	var budget: int = 1
	if last != origin:
		budget = (2 * RING_IN + 1) * (2 * RING_IN + 1)
	var built := 0
	for dy in range(-RING_IN, RING_IN + 1):
		for dx in range(-RING_IN, RING_IN + 1):
			if dx == 0 and dy == 0:
				continue
			var o := Vector2i(origin.x + dx * CHUNK, origin.y + dy * CHUNK)
			if o.x < 0 or o.y < 0 or o.x >= w or o.y >= h:
				continue
			var job: Dictionary = job_at(host, o)
			if str(job.state) != "pending":
				continue
			if built >= budget:
				continue
			HitchLog.mark("geo_activate", Vector2i(job.origin))
			activate_job(host, job)
			built += 1
	LightRt.maintain(host)


static func tick(host: Node, delta: float) -> void:
	follow(host, delta)
	if host.player == null:
		return
	var origin := chunk_origin(host._player_cell())
	for job in host.geo_jobs:
		if str(job.state) == "live" and chunk_ring(Vector2i(job.origin), origin) > RING_OUT:
			sleep_job(host, job)


static func activate_job(host: Node, job: Dictionary) -> void:
	if str(job.state) != "pending":
		return
	var ox: int = int(job.origin.x)
	var oy: int = int(job.origin.y)
	var w: int = host.data.w
	var h: int = host.data.h
	var x1 := mini(w, ox + CHUNK)
	var y1 := mini(h, oy + CHUNK)
	var mask: Dictionary = _mask(host)
	var solid: PackedByteArray = mask["solid"]
	var sw: int = int(mask["sw"])
	var sh: int = int(mask["sh"])
	var n: int = int(mask["n"])
	var fine_m: float = float(mask["fine"])
	var grid: PackedByteArray = host.data.grid
	var floor_cells: Array[Vector2i] = WallRects.solid_cells(solid, sw, sh, n, ox, oy, x1, y1)
	var wall_cells: Array[Vector2i] = WallRects.volume_cells(solid, sw, sh, n, grid, w, h, ox, oy, x1, y1)
	HitchLog.mark("geo_cells")
	if floor_cells.is_empty() and wall_cells.is_empty():
		job.state = "cleared"
		return
	var root := Node3D.new()
	root.name = "Geo_%d_%d" % [ox, oy]
	host.geo_root.add_child(root)
	var outlined: bool = not _outline_spans(host).is_empty()
	var runs: Array[Dictionary] = []
	if outlined or not wall_cells.is_empty():
		runs = _wall_runs(host, solid, sw, sh, wall_cells, ox, oy, x1, y1, n)
	HitchLog.mark("geo_runs")
	if not floor_cells.is_empty():
		if outlined:
			var lip: Node3D = _emit_floor_lip(_outline_loops(host), ox * n, oy * n, x1 * n, y1 * n, fine_m, host.floor_mat)
			HitchLog.mark("geo_lip")
			root.add_child(lip)
			var mm: MultiMeshInstance3D = _first_mm(lip)
			if host.floor_mm == null and mm != null:
				host.floor_mm = mm
		else:
			var fm: MultiMeshInstance3D = _emit_floors(WallRects.merge(floor_cells), fine_m, host.floor_mat)
			root.add_child(fm)
			if host.floor_mm == null:
				host.floor_mm = fm
	if not runs.is_empty():
		var wall_inst: MeshInstance3D = MeshInstance3D.new()
		wall_inst.mesh = WallMesh.from_faces(runs)
		HitchLog.mark("geo_walls")
		wall_inst.scale = Vector3(fine_m, 1.0, fine_m)
		wall_inst.material_override = host.wall_mat
		wall_inst.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		root.add_child(wall_inst)
	if outlined:
		_add_ribbon_boxes(root, runs, fine_m)
		HitchLog.mark("geo_col")
	elif not wall_cells.is_empty():
		add_collision(root, wall_cells, fine_m)
	job.node = root
	job.state = "live"


static func _mask(host: Node) -> Dictionary:
	var w: int = int(host.data.w)
	var h: int = int(host.data.h)
	if host.data.has("solid") and host.data["solid"] is PackedByteArray:
		var fine: float = float(host.data.get("outline_fine_m", 0.25))
		if fine < 0.2:
			fine = 0.25
		return {
			"solid": host.data["solid"],
			"sw": int(host.data["solid_w"]),
			"sh": int(host.data["solid_h"]),
			"n": maxi(1, int(host.data["solid_n"])),
			"fine": fine,
		}
	return {"solid": host.data.grid, "sw": w, "sh": h, "n": 1, "fine": 1.0}


static func _emit_floors(rects: Array[Rect2i], fine_m: float, mat: Material) -> MultiMeshInstance3D:
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.mesh = _floor_mesh
	mm.instance_count = rects.size()
	for i in rects.size():
		var r: Rect2i = rects[i]
		var sx: float = float(r.size.x) * fine_m
		var sz: float = float(r.size.y) * fine_m
		var basis := Basis(Vector3(sx, 0.0, 0.0), Vector3(0.0, 1.0, 0.0), Vector3(0.0, 0.0, sz))
		var at := Vector3((float(r.position.x) + float(r.size.x) * 0.5) * fine_m, T.FLOOR_Y, (float(r.position.y) + float(r.size.y) * 0.5) * fine_m)
		mm.set_instance_transform(i, Transform3D(basis, at))
	var inst := MultiMeshInstance3D.new()
	inst.multimesh = mm
	if mat:
		inst.material_override = mat
	return inst


static func _outline_spans(host: Node) -> Array:
	if host.data == null or not host.data.has("outline_spans"):
		return []
	var raw: Variant = host.data["outline_spans"]
	if raw is Array:
		return raw
	return []


static func _outline_loops(host: Node) -> Array:
	if host.data == null or not host.data.has("outline_loops"):
		return []
	var raw: Variant = host.data["outline_loops"]
	if raw is Array:
		return raw
	return []


static func _wall_runs(host: Node, solid: PackedByteArray, sw: int, sh: int, wall_cells: Array[Vector2i], ox: int, oy: int, x1: int, y1: int, n: int) -> Array[Dictionary]:
	if _outline_spans(host).is_empty():
		return _faces_on_chunk(solid, sw, sh, wall_cells, ox * n, oy * n, x1 * n, y1 * n)
	return WallMesh.prepare(_spans_on_chunk(_outline_spans(host), ox * n, oy * n, x1 * n, y1 * n))


static func _prepared_spans(host: Node) -> Array:
	var raw: Array = _outline_spans(host)
	var mark: int = raw.size()
	if host.has_meta("wdb_ribbon_n") and int(host.get_meta("wdb_ribbon_n")) == mark and host.has_meta("wdb_ribbon"):
		var cached: Variant = host.get_meta("wdb_ribbon")
		if cached is Array:
			return cached
	var prepared: Array = WallMesh.prepare(raw)
	host.set_meta("wdb_ribbon", prepared)
	host.set_meta("wdb_ribbon_n", mark)
	return prepared


static func _spans_on_chunk(spans: Array, fx0: int, fy0: int, fx1: int, fy1: int) -> Array[Dictionary]:
	var kept: Array[Dictionary] = []
	var pad := 2.0
	var ix0: float = float(fx0) - pad
	var iy0: float = float(fy0) - pad
	var ix1: float = float(fx1) + pad
	var iy1: float = float(fy1) + pad
	var x0: float = float(fx0)
	var y0: float = float(fy0)
	var x1: float = float(fx1) - 0.0001
	var y1: float = float(fy1) - 0.0001
	for item in spans:
		if not (item is Dictionary):
			continue
		var run: Dictionary = item
		if not run.has("delta"):
			continue
		var o: Vector2 = run["origin"] as Vector2
		var d: Vector2 = run["delta"] as Vector2
		if _clip_span(o, d, ix0, iy0, ix1, iy1).is_empty():
			continue
		var piece: Dictionary = _clip_span(o, d, x0, y0, x1, y1)
		if piece.is_empty():
			continue
		var t0: float = float(piece["t0"])
		var t1: float = float(piece["t1"])
		kept.append({
			"origin": piece["origin"],
			"delta": piece["delta"],
			"normal": run["normal"],
			"thick": float(run.get("thick", 1.0)),
			"cap_a": t0 <= 0.001,
			"cap_b": t1 >= 0.999,
		})
	return kept


static func _clip_span(o: Vector2, d: Vector2, x0: float, y0: float, x1: float, y1: float) -> Dictionary:
	var ts: Array = [0.0, 1.0]
	if not _clip_axis(o.x, d.x, x0, x1, ts):
		return {}
	if not _clip_axis(o.y, d.y, y0, y1, ts):
		return {}
	var t0: float = float(ts[0])
	var t1: float = float(ts[1])
	if t1 - t0 < 0.0001:
		return {}
	return {
		"origin": o + d * t0,
		"delta": d * (t1 - t0),
		"t0": t0,
		"t1": t1,
	}


static func _clip_axis(p: float, dp: float, min_v: float, max_v: float, ts: Array) -> bool:
	var t0: float = float(ts[0])
	var t1: float = float(ts[1])
	if absf(dp) < 0.0000001:
		if p < min_v or p > max_v:
			return false
		return true
	var a: float = (min_v - p) / dp
	var b: float = (max_v - p) / dp
	if a > b:
		var swap: float = a
		a = b
		b = swap
	if a > t0:
		t0 = a
	if b < t1:
		t1 = b
	if t0 > t1:
		return false
	ts[0] = t0
	ts[1] = t1
	return true


static func _faces_on_chunk(
	grid: PackedByteArray,
	w: int,
	h: int,
	wall_cells: Array[Vector2i],
	ox: int,
	oy: int,
	x1: int,
	y1: int
) -> Array[Dictionary]:
	var runs: Array[Dictionary] = WallRects.faces(grid, w, h, wall_cells)
	var kept: Array[Dictionary] = []
	for run: Dictionary in runs:
		if _run_looks_in(run, ox, oy, x1, y1):
			kept.append(run)
	return kept


static func _run_looks_in(run: Dictionary, ox: int, oy: int, x1: int, y1: int) -> bool:
	var origin: Vector2i = run["origin"] as Vector2i
	var span_cells: Vector2i = run["size"] as Vector2i
	var n2: Vector2i = run["normal"] as Vector2i
	var along: Vector2i = Vector2i(1, 0) if span_cells.x >= span_cells.y else Vector2i(0, 1)
	var length: int = maxi(span_cells.x, span_cells.y)
	for k in length:
		var wall: Vector2i = origin + Vector2i(along.x * k, along.y * k)
		var floor_cell: Vector2i = wall + n2
		if floor_cell.x >= ox and floor_cell.y >= oy and floor_cell.x < x1 and floor_cell.y < y1:
			return true
	return false


static func _first_mm(node: Node) -> MultiMeshInstance3D:
	for child in node.get_children():
		if child is MultiMeshInstance3D:
			return child as MultiMeshInstance3D
	return null


static func _emit_floor_lip(spans: Array, x0: int, y0: int, x1: int, y1: int, fine_m: float, mat: Material) -> Node3D:
	var holder: Node3D = Node3D.new()
	holder.name = "Floors"
	var loops: Array = spans
	var box: PackedVector2Array = PackedVector2Array()
	box.append(Vector2(float(x0), float(y0)))
	box.append(Vector2(float(x1), float(y0)))
	box.append(Vector2(float(x1), float(y1)))
	box.append(Vector2(float(x0), float(y1)))
	var pieces: Array = []
	for loop_v in loops:
		var loop: PackedVector2Array = loop_v
		if loop.size() < 3:
			continue
		var clipped: Array = Geometry2D.intersect_polygons(loop, box)
		for poly_v in clipped:
			var poly: PackedVector2Array = poly_v
			if poly.size() >= 3:
				pieces.append(poly)
	if not pieces.is_empty():
		var inst: MeshInstance3D = MeshInstance3D.new()
		inst.mesh = _loop_mesh(pieces, fine_m)
		inst.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		if mat:
			inst.material_override = mat
		holder.add_child(inst)
	return holder


static func _span_loops(spans: Array) -> Array:
	var segs: Array = []
	for item in spans:
		if not (item is Dictionary):
			continue
		var run: Dictionary = item
		if not run.has("delta"):
			continue
		var o: Vector2 = run["origin"] as Vector2
		var d: Vector2 = run["delta"] as Vector2
		if d.length_squared() < 0.04:
			continue
		segs.append([o, o + d])
	var loops: Array = []
	var used: Array[bool] = []
	used.resize(segs.size())
	used.fill(false)
	for si in segs.size():
		if used[si]:
			continue
		var start: Vector2 = segs[si][0]
		var cur: Vector2 = segs[si][1]
		var poly: PackedVector2Array = PackedVector2Array()
		poly.append(start)
		poly.append(cur)
		used[si] = true
		var guard: int = 0
		while guard < segs.size() + 2:
			guard += 1
			if cur.distance_to(start) <= 0.25 and poly.size() >= 3:
				break
			var found: int = -1
			var flip: bool = false
			var best: float = 0.25
			for j in segs.size():
				if used[j]:
					continue
				var a: Vector2 = segs[j][0]
				var b: Vector2 = segs[j][1]
				var da: float = cur.distance_to(a)
				var db: float = cur.distance_to(b)
				if da <= best:
					best = da
					found = j
					flip = false
				if db <= best:
					best = db
					found = j
					flip = true
			if found < 0:
				break
			used[found] = true
			if flip:
				cur = segs[found][0]
			else:
				cur = segs[found][1]
			poly.append(cur)
		if poly.size() >= 3:
			if poly[poly.size() - 1].distance_to(poly[0]) <= 0.25:
				poly.remove_at(poly.size() - 1)
			loops.append(poly)
	return loops


static func _loop_mesh(pieces: Array, fine_m: float) -> ArrayMesh:
	var verts: PackedVector3Array = PackedVector3Array()
	var norms: PackedVector3Array = PackedVector3Array()
	var uvs: PackedVector2Array = PackedVector2Array()
	var indices: PackedInt32Array = PackedInt32Array()
	for piece in pieces:
		var poly: PackedVector2Array = piece as PackedVector2Array
		if poly.size() < 3:
			continue
		var tris: PackedInt32Array = Geometry2D.triangulate_polygon(poly)
		if tris.is_empty():
			poly.reverse()
			tris = Geometry2D.triangulate_polygon(poly)
		if tris.is_empty():
			continue
		var base: int = verts.size()
		for i in poly.size():
			var p: Vector2 = poly[i]
			var x: float = p.x * fine_m
			var z: float = p.y * fine_m
			verts.append(Vector3(x, T.FLOOR_Y, z))
			norms.append(Vector3.UP)
			uvs.append(Vector2(x, z))
		for k in tris.size():
			indices.append(base + int(tris[k]))
	var mesh: ArrayMesh = ArrayMesh.new()
	if verts.is_empty():
		return mesh
	var arrays: Array = []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = verts
	arrays[Mesh.ARRAY_NORMAL] = norms
	arrays[Mesh.ARRAY_TEX_UV] = uvs
	arrays[Mesh.ARRAY_INDEX] = indices
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return mesh


static func _floor_splint(run: Dictionary) -> PackedVector2Array:
	var o: Vector2 = run["origin"] as Vector2
	var d: Vector2 = run["delta"] as Vector2
	if d.length_squared() < 0.04:
		return PackedVector2Array()
	var nrm: Vector2 = run["normal"] as Vector2
	if nrm.length_squared() < 0.0001:
		nrm = Vector2(-d.y, d.x)
	if nrm.length_squared() < 0.0001:
		return PackedVector2Array()
	nrm = nrm.normalized()
	var w: float = 2.0
	var poly: PackedVector2Array = PackedVector2Array()
	poly.append(o)
	poly.append(o + d)
	poly.append(o + d + nrm * w)
	poly.append(o + nrm * w)
	return poly


static func _mark_span(cut: Dictionary, run: Dictionary) -> void:
	var o: Vector2 = run["origin"]
	var d: Vector2 = run["delta"]
	var span_l: float = d.length()
	if span_l < 0.2:
		return
	var steps: int = maxi(1, int(ceil(span_l * 2.0)))
	for s in range(steps + 1):
		var p: Vector2 = o + d * (float(s) / float(steps))
		var fx: int = int(floor(p.x))
		var fy: int = int(floor(p.y))
		for oy in range(-1, 2):
			for ox in range(-1, 2):
				cut[Vector2i(fx + ox, fy + oy)] = true


static func _square(fx: int, fy: int) -> PackedVector2Array:
	var poly: PackedVector2Array = PackedVector2Array()
	var x0: float = float(fx)
	var y0: float = float(fy)
	poly.append(Vector2(x0, y0))
	poly.append(Vector2(x0 + 1.0, y0))
	poly.append(Vector2(x0 + 1.0, y0 + 1.0))
	poly.append(Vector2(x0, y0 + 1.0))
	return poly


static func _seg_dist(p: Vector2, o: Vector2, d: Vector2) -> float:
	var l2: float = d.length_squared()
	if l2 < 0.0001:
		return p.distance_to(o)
	var t: float = clampf((p - o).dot(d) / l2, 0.0, 1.0)
	return p.distance_to(o + d * t)


static func _near_span(run: Dictionary, fx: int, fy: int) -> bool:
	var center: Vector2 = Vector2(float(fx) + 0.5, float(fy) + 0.5)
	var origin: Vector2 = run["origin"] as Vector2
	var delta: Vector2 = run["delta"] as Vector2
	return _seg_dist(center, origin, delta) <= 1.8


static func _clip_cell(fx: int, fy: int, spans: Array) -> PackedVector2Array:
	var poly: PackedVector2Array = _square(fx, fy)
	for item in spans:
		if not (item is Dictionary):
			continue
		var run: Dictionary = item
		if not run.has("delta"):
			continue
		if not _near_span(run, fx, fy):
			continue
		var d: Vector2 = run["delta"] as Vector2
		var nrm: Vector2 = run["normal"] as Vector2
		if nrm.length_squared() < 0.0001:
			nrm = Vector2(-d.y, d.x)
		if nrm.length_squared() > 0.0001:
			nrm = nrm.normalized()
		var origin: Vector2 = run["origin"] as Vector2
		poly = _clip_half(poly, origin, nrm)
		if poly.size() < 3:
			return poly
	return poly


static func _clip_half(poly: PackedVector2Array, origin: Vector2, inward: Vector2) -> PackedVector2Array:
	var count: int = poly.size()
	var out: PackedVector2Array = PackedVector2Array()
	if count < 3:
		return out
	var prev: Vector2 = poly[count - 1]
	var prev_in: bool = (prev - origin).dot(inward) >= -0.02
	for i in count:
		var cur: Vector2 = poly[i]
		var cur_in: bool = (cur - origin).dot(inward) >= -0.02
		if cur_in:
			if not prev_in:
				out.append(_edge_hit(prev, cur, origin, inward))
			out.append(cur)
		elif prev_in:
			out.append(_edge_hit(prev, cur, origin, inward))
		prev = cur
		prev_in = cur_in
	return out


static func _edge_hit(a: Vector2, b: Vector2, origin: Vector2, inward: Vector2) -> Vector2:
	var da: float = (a - origin).dot(inward)
	var db: float = (b - origin).dot(inward)
	var den: float = da - db
	var t: float = 0.0
	if absf(den) > 0.00001:
		t = da / den
	return a + (b - a) * clampf(t, 0.0, 1.0)


static func _still_square(poly: PackedVector2Array, fx: int, fy: int) -> bool:
	if poly.size() != 4:
		return false
	var x0: float = float(fx)
	var y0: float = float(fy)
	var corners: Array[Vector2] = [
		Vector2(x0, y0),
		Vector2(x0 + 1.0, y0),
		Vector2(x0 + 1.0, y0 + 1.0),
		Vector2(x0, y0 + 1.0),
	]
	var hits: int = 0
	for corner in corners:
		var found: bool = false
		for i in poly.size():
			if poly[i].distance_squared_to(corner) <= 0.004:
				found = true
				break
		if found:
			hits += 1
	return hits == 4


static func _lip_mesh(pieces: Array, fine_m: float) -> ArrayMesh:
	var verts: PackedVector3Array = PackedVector3Array()
	var norms: PackedVector3Array = PackedVector3Array()
	var uvs: PackedVector2Array = PackedVector2Array()
	var indices: PackedInt32Array = PackedInt32Array()
	for piece in pieces:
		var poly: PackedVector2Array = piece as PackedVector2Array
		if poly.size() < 3:
			continue
		var base: int = verts.size()
		for i in poly.size():
			var p: Vector2 = poly[i]
			var x: float = p.x * fine_m
			var z: float = p.y * fine_m
			verts.append(Vector3(x, T.FLOOR_Y, z))
			norms.append(Vector3.UP)
			uvs.append(Vector2(x, z))
		for i in range(1, poly.size() - 1):
			indices.append(base)
			indices.append(base + i)
			indices.append(base + i + 1)
	var mesh: ArrayMesh = ArrayMesh.new()
	if verts.is_empty():
		return mesh
	var arrays: Array = []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = verts
	arrays[Mesh.ARRAY_NORMAL] = norms
	arrays[Mesh.ARRAY_TEX_UV] = uvs
	arrays[Mesh.ARRAY_INDEX] = indices
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return mesh


static func _add_ribbon_boxes(root: Node3D, spans: Array, fine_m: float) -> void:
	if spans.is_empty():
		return
	var body: StaticBody3D = StaticBody3D.new()
	body.collision_layer = 1
	body.collision_mask = 0
	root.add_child(body)
	for item in spans:
		if not (item is Dictionary):
			continue
		var run: Dictionary = item
		if not run.has("delta"):
			continue
		var o: Vector2 = run["origin"] as Vector2
		var d: Vector2 = run["delta"] as Vector2
		var span_l: float = d.length()
		if span_l < 0.2:
			continue
		var tangent: Vector2 = d / span_l
		var left: Vector2 = Vector2(-tangent.y, tangent.x)
		var inward: Vector2 = left
		var nrm: Vector2 = run["normal"] as Vector2
		if nrm.length_squared() < 0.0001:
			nrm = left
		else:
			nrm = nrm.normalized()
		if inward.dot(nrm) < 0.0:
			inward = -inward
		var thick: float = float(run.get("thick", 1.0))
		if thick <= 0.0 or thick > 1.5:
			thick = 1.0
		var mid: Vector2 = o + d * 0.5 - inward * (thick * 0.5)
		var basis: Basis = Basis(Vector3(tangent.x, 0.0, tangent.y), Vector3.UP, Vector3(left.x, 0.0, left.y))
		var box: BoxShape3D = BoxShape3D.new()
		box.size = Vector3(span_l * fine_m, T.WALL_H, thick * fine_m)
		var cs: CollisionShape3D = CollisionShape3D.new()
		cs.shape = box
		cs.transform = Transform3D(basis, Vector3(mid.x * fine_m, T.WALL_H * 0.5, mid.y * fine_m))
		body.add_child(cs)


static func add_collision(root: Node3D, walls: Array[Vector2i], fine_m: float) -> void:
	if walls.is_empty():
		return
	var body := StaticBody3D.new()
	body.collision_layer = 1
	body.collision_mask = 0
	root.add_child(body)
	var rects: Array[Rect2i] = WallRects.merge(walls)
	for r: Rect2i in rects:
		var sx: float = float(r.size.x) * fine_m
		var sz: float = float(r.size.y) * fine_m
		var cs := CollisionShape3D.new()
		var box := BoxShape3D.new()
		box.size = Vector3(sx, T.WALL_H, sz)
		cs.shape = box
		cs.position = Vector3((float(r.position.x) + float(r.size.x) * 0.5) * fine_m, T.WALL_H * 0.5, (float(r.position.y) + float(r.size.y) * 0.5) * fine_m)
		body.add_child(cs)


static func sleep_job(host: Node, job: Dictionary) -> void:
	if str(job.state) != "live":
		return
	var n: Node = job.get("node", null)
	if n != null and is_instance_valid(n):
		if host.floor_mm != null and n.is_ancestor_of(host.floor_mm):
			host.floor_mm = null
		n.queue_free()
	job.node = null
	job.state = "pending"
