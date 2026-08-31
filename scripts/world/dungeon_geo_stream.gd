extends RefCounted

const T := preload("res://scripts/data/tunables.gd")
const Gen := preload("res://scripts/dungeon/gen.gd")

const STREAM_IN := 28
const STREAM_OUT := 42
const CHUNK := 16
const PER_TICK := 8
const BOOT_TICK := 24


static func setup(host: Node) -> void:
	host.geo_jobs.clear()
	if host.geo_root != null and is_instance_valid(host.geo_root):
		host.geo_root.queue_free()
	host.geo_root = Node3D.new()
	host.geo_root.name = "GeoStream"
	host.add_child(host.geo_root)
	queue_chunks(host)


static func queue_chunks(host: Node) -> void:
	var w: int = host.data.w
	var h: int = host.data.h
	var y := 0
	while y < h:
		var x := 0
		while x < w:
			if chunk_useful(host, x, y):
				var cx := x + mini(CHUNK, w - x) / 2
				var cy := y + mini(CHUNK, h - y) / 2
				host.geo_jobs.append({
					"cell": Vector2i(cx, cy),
					"origin": Vector2i(x, y),
					"state": "pending",
					"node": null,
				})
			x += CHUNK
		y += CHUNK


static func chunk_useful(host: Node, ox: int, oy: int) -> bool:
	var w: int = host.data.w
	var h: int = host.data.h
	var grid: PackedByteArray = host.data.grid
	var x1 := mini(w, ox + CHUNK)
	var y1 := mini(h, oy + CHUNK)
	for y in range(oy, y1):
		for x in range(ox, x1):
			if grid[Gen.idx(x, y, w)] == Gen.FLOOR:
				return true
			for n in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
				var nx: int = x + n.x
				var ny: int = y + n.y
				if nx < 0 or ny < 0 or nx >= w or ny >= h:
					continue
				if grid[Gen.idx(nx, ny, w)] == Gen.FLOOR:
					return true
	return false


static func tick(host: Node, delta: float) -> void:
	if host.player == null and host.geo_jobs.is_empty():
		return
	var pc: Vector2i = host._player_cell()
	var budget := BOOT_TICK if delta >= 0.9 else PER_TICK
	var built := 0
	for job in host.geo_jobs:
		var st := str(job.state)
		var d: int = host._cell_manhattan(pc, Vector2i(job.cell))
		if st == "pending" and d <= STREAM_IN:
			if built >= budget:
				continue
			activate_job(host, job)
			built += 1
		elif st == "live" and d >= STREAM_OUT:
			sleep_job(host, job)


static func activate_job(host: Node, job: Dictionary) -> void:
	if str(job.state) != "pending":
		return
	var Geo = load("res://scripts/world/dungeon_geo.gd")
	var ox: int = int(job.origin.x)
	var oy: int = int(job.origin.y)
	var w: int = host.data.w
	var h: int = host.data.h
	var grid: PackedByteArray = host.data.grid
	var x1 := mini(w, ox + CHUNK)
	var y1 := mini(h, oy + CHUNK)
	var floors: Array = []
	var wallp: Array = []
	for y in range(oy, y1):
		for x in range(ox, x1):
			if grid[Gen.idx(x, y, w)] == Gen.FLOOR:
				floors.append(Vector3(float(x) + 0.5, T.FLOOR_Y, float(y) + 0.5))
				continue
			var near := false
			for n in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
				var nx: int = x + n.x
				var ny: int = y + n.y
				if nx < 0 or ny < 0 or nx >= w or ny >= h:
					continue
				if grid[Gen.idx(nx, ny, w)] == Gen.FLOOR:
					near = true
					break
			if near:
				wallp.append(Vector3(float(x) + 0.5, T.WALL_H * 0.5, float(y) + 0.5))
	var root := Node3D.new()
	root.name = "Geo_%d_%d" % [ox, oy]
	host.geo_root.add_child(root)
	if not floors.is_empty():
		var fm: MultiMeshInstance3D = Geo.mm_planes(floors, "res://assets/tiles/foundation_floor.png", Color(0.18, 0.2, 0.24))
		if host.floor_mat:
			fm.material_override = host.floor_mat
		root.add_child(fm)
		if host.floor_mm == null:
			host.floor_mm = fm
	if not wallp.is_empty():
		var wm: MultiMeshInstance3D = Geo.mm_boxes(wallp, "res://assets/tiles/foundation_wall.png", Color(0.22, 0.22, 0.26))
		if host.wall_mat:
			wm.material_override = host.wall_mat
		root.add_child(wm)
	add_collision(host, root, ox, oy, x1, y1)
	job.node = root
	job.state = "live"


static func add_collision(host: Node, root: Node3D, ox: int, oy: int, x1: int, y1: int) -> void:
	var w: int = host.data.w
	var grid: PackedByteArray = host.data.grid
	var used := {}
	var body := StaticBody3D.new()
	body.collision_layer = 1
	body.collision_mask = 0
	root.add_child(body)
	var Geo = load("res://scripts/world/dungeon_geo.gd")
	for y in range(oy, y1):
		for x in range(ox, x1):
			if grid[Gen.idx(x, y, w)] != Gen.WALL or used.has(Vector2i(x, y)):
				continue
			var xa := x
			while xa + 1 < x1 and grid[Gen.idx(xa + 1, y, w)] == Gen.WALL and not used.has(Vector2i(xa + 1, y)):
				xa += 1
			var ya := y
			var row_ok := true
			while row_ok:
				for xx in range(x, xa + 1):
					if ya + 1 >= y1 or grid[Gen.idx(xx, ya + 1, w)] != Gen.WALL or used.has(Vector2i(xx, ya + 1)):
						row_ok = false
						break
				if row_ok:
					ya += 1
			for yy in range(y, ya + 1):
				for xx in range(x, xa + 1):
					used[Vector2i(xx, yy)] = true
			var sx := float(xa - x + 1)
			var sz := float(ya - y + 1)
			Geo.box(body, Vector3(sx, T.WALL_H, sz), Vector3(float(x) + sx * 0.5, T.WALL_H * 0.5, float(y) + sz * 0.5))


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
