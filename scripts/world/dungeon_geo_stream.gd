extends RefCounted

const T := preload("res://scripts/data/tunables.gd")
const Gen := preload("res://scripts/dungeon/gen.gd")

const RING_IN := 1
const RING_OUT := 2
const CHUNK := 32
const PER_FRAME := 3

static var _floor_mesh: PlaneMesh
static var _wall_mesh: BoxMesh


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
	if _wall_mesh == null:
		_wall_mesh = BoxMesh.new()
		_wall_mesh.size = Vector3(T.TILE, T.WALL_H, T.TILE)


static func chunk_origin(c: Vector2i) -> Vector2i:
	var x := c.x
	var y := c.y
	if x < 0:
		x -= CHUNK - 1
	if y < 0:
		y -= CHUNK - 1
	return Vector2i((x / CHUNK) * CHUNK, (y / CHUNK) * CHUNK)


static func chunk_center(origin: Vector2i, w: int, h: int) -> Vector2i:
	return Vector2i(origin.x + mini(CHUNK, w - origin.x) / 2, origin.y + mini(CHUNK, h - origin.y) / 2)


static func chunk_ring(a: Vector2i, b: Vector2i) -> int:
	return maxi(absi(a.x - b.x) / CHUNK, absi(a.y - b.y) / CHUNK)


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
	var grid: PackedByteArray = host.data.grid
	var x1 := mini(w, ox + CHUNK)
	var y1 := mini(h, oy + CHUNK)
	var floors: Array = []
	var wallp: Array = []
	var wall_cells: Array[Vector2i] = []
	for y in range(oy, y1):
		for x in range(ox, x1):
			if grid[Gen.idx(x, y, w)] == Gen.FLOOR:
				floors.append(Vector3(float(x) + 0.5, T.FLOOR_Y, float(y) + 0.5))
				continue
			if not wall_faces_floor(grid, w, h, x, y):
				continue
			wallp.append(Vector3(float(x) + 0.5, T.WALL_H * 0.5, float(y) + 0.5))
			wall_cells.append(Vector2i(x, y))
	if floors.is_empty() and wallp.is_empty():
		job.state = "cleared"
		return
	var root := Node3D.new()
	root.name = "Geo_%d_%d" % [ox, oy]
	host.geo_root.add_child(root)
	if not floors.is_empty():
		var fm := make_mm(floors, _floor_mesh, host.floor_mat)
		root.add_child(fm)
		if host.floor_mm == null:
			host.floor_mm = fm
	if not wallp.is_empty():
		root.add_child(make_mm(wallp, _wall_mesh, host.wall_mat))
	add_collision(root, wall_cells)
	job.node = root
	job.state = "live"


static func wall_faces_floor(grid: PackedByteArray, w: int, h: int, x: int, y: int) -> bool:
	for n in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
		var nx: int = x + n.x
		var ny: int = y + n.y
		if nx < 0 or ny < 0 or nx >= w or ny >= h:
			continue
		if grid[Gen.idx(nx, ny, w)] == Gen.FLOOR:
			return true
	return false


static func make_mm(positions: Array, mesh: Mesh, mat: Material) -> MultiMeshInstance3D:
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.mesh = mesh
	mm.instance_count = positions.size()
	for i in positions.size():
		var xf := Transform3D.IDENTITY
		xf.origin = positions[i]
		mm.set_instance_transform(i, xf)
	var inst := MultiMeshInstance3D.new()
	inst.multimesh = mm
	if mat:
		inst.material_override = mat
	return inst


static func add_collision(root: Node3D, walls: Array[Vector2i]) -> void:
	if walls.is_empty():
		return
	var used := {}
	for c in walls:
		used[c] = false
	var body := StaticBody3D.new()
	body.collision_layer = 1
	body.collision_mask = 0
	root.add_child(body)
	for c in walls:
		if used[c]:
			continue
		var x := c.x
		var y := c.y
		var xa := x
		while used.has(Vector2i(xa + 1, y)) and not used[Vector2i(xa + 1, y)]:
			xa += 1
		var ya := y
		var row_ok := true
		while row_ok:
			for xx in range(x, xa + 1):
				var below := Vector2i(xx, ya + 1)
				if not used.has(below) or used[below]:
					row_ok = false
					break
			if row_ok:
				ya += 1
		for yy in range(y, ya + 1):
			for xx in range(x, xa + 1):
				used[Vector2i(xx, yy)] = true
		var sx := float(xa - x + 1)
		var sz := float(ya - y + 1)
		var cs := CollisionShape3D.new()
		var sh := BoxShape3D.new()
		sh.size = Vector3(sx, T.WALL_H, sz)
		cs.shape = sh
		cs.position = Vector3(float(x) + sx * 0.5, T.WALL_H * 0.5, float(y) + sz * 0.5)
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
