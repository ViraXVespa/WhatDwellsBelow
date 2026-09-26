extends RefCounted

const T := preload("res://scripts/data/tunables.gd")
const Gen := preload("res://scripts/dungeon/gen.gd")
const MmEmit := preload("res://scripts/graphics/mm_emit.gd")
const WallRects := preload("res://scripts/world/wall_rects.gd")
const WallMesh: GDScript = preload("res://scripts/graphics/wall_mesh.gd")
const LightRt := preload("res://scripts/graphics/light_rt.gd")

const RING_IN := 1
const RING_OUT := 2
const CHUNK := 32
const PER_FRAME := 3

static var _floor_mesh: PlaneMesh


static func setup(host: Node) -> void:
	host.geo_jobs.clear()
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
		activate_job(host, cur)
	var budget := 9 if delta >= 0.9 else PER_FRAME
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
	LightRt.maintain(host)


static func activate_job(host: Node, job: Dictionary) -> void:
	if str(job.state) != "pending":
		return
	var ox: int = int(job.origin.x)
	var oy: int = int(job.origin.y)
	var w: int = host.data.w
	var h: int = host.data.h
	var grid: PackedByteArray = host.data.grid
	var x1 := mini(w, ox + CHUNK)
	var y1 := mini(h, oy + CHUNK)
	var floors: Array = []
	var wall_cells: Array[Vector2i] = []
	var seen_wall: Dictionary = {}
	var dirs: Array[Vector2i] = [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]
	for y in range(oy, y1):
		for x in range(ox, x1):
			if grid[Gen.idx(x, y, w)] != Gen.FLOOR:
				continue
			floors.append(Vector3(float(x) + 0.5, T.FLOOR_Y, float(y) + 0.5))
			for n: Vector2i in dirs:
				var nx: int = x + n.x
				var ny: int = y + n.y
				if nx < 0 or ny < 0 or nx >= w or ny >= h:
					continue
				if grid[Gen.idx(nx, ny, w)] == Gen.FLOOR:
					continue
				var wc: Vector2i = Vector2i(nx, ny)
				if seen_wall.has(wc):
					continue
				seen_wall[wc] = true
				wall_cells.append(wc)
	if floors.is_empty() and wall_cells.is_empty():
		job.state = "cleared"
		return
	var root := Node3D.new()
	root.name = "Geo_%d_%d" % [ox, oy]
	host.geo_root.add_child(root)
	if not floors.is_empty():
		var fm: MultiMeshInstance3D = MmEmit.make_mm(floors, _floor_mesh, host.floor_mat)
		root.add_child(fm)
		if host.floor_mm == null:
			host.floor_mm = fm
	if not wall_cells.is_empty():
		var runs: Array[Dictionary] = _faces_on_chunk(grid, w, h, wall_cells, ox, oy, x1, y1)
		if not runs.is_empty():
			var wall_inst: MeshInstance3D = MeshInstance3D.new()
			wall_inst.mesh = WallMesh.from_faces(runs)
			wall_inst.material_override = host.wall_mat
			wall_inst.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			root.add_child(wall_inst)
	var collide: Array[Vector2i] = []
	for wc2: Vector2i in wall_cells:
		if wc2.x < ox or wc2.y < oy or wc2.x >= x1 or wc2.y >= y1:
			continue
		collide.append(wc2)
	add_collision(root, collide)
	job.node = root
	job.state = "live"


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


static func add_collision(root: Node3D, walls: Array[Vector2i]) -> void:
	if walls.is_empty():
		return
	var body := StaticBody3D.new()
	body.collision_layer = 1
	body.collision_mask = 0
	root.add_child(body)
	var rects: Array[Rect2i] = WallRects.merge(walls)
	for r in rects:
		var sx := float(r.size.x)
		var sz := float(r.size.y)
		var cs := CollisionShape3D.new()
		var sh := BoxShape3D.new()
		sh.size = Vector3(sx, T.WALL_H, sz)
		cs.shape = sh
		cs.position = Vector3(float(r.position.x) + sx * 0.5, T.WALL_H * 0.5, float(r.position.y) + sz * 0.5)
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
