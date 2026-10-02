extends RefCounted

const T := preload("res://scripts/data/tunables.gd")
const WallRects := preload("res://scripts/world/wall_rects.gd")
const Clip := preload("res://scripts/world/dungeon_geo/stream_clip.gd")
const Emit := preload("res://scripts/world/dungeon_geo/stream_emit.gd")
const LightRt := preload("res://scripts/graphics/light_rt.gd")
const HitchLog := preload("res://scripts/debug/hitch_log.gd")
const LoadTiming := preload("res://scripts/debug/load_timing.gd")

const RING_IN := 1
const RING_OUT := 2
const CHUNK := 32
const PER_FRAME := 3

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
	if host.has_meta("wdb_wall_mi"):
		host.remove_meta("wdb_wall_mi")
	ensure_meshes()
static func ensure_meshes() -> void:
	Emit.ensure_meshes()

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
	var origin := chunk_origin(host._player_cell())
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
static func follow(host: Node, _delta: float) -> void:
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
	host.set_meta("wdb_geo_origin", origin)
	var budget: int = PER_FRAME
	if int(host.get("frame_n")) <= 2:
		budget = 1
	var built := 0
	var dy: int = -RING_IN
	while dy <= RING_IN:
		var dx: int = -RING_IN
		while dx <= RING_IN:
			if dx == 0 and dy == 0:
				dx += 1
				continue
			var o := Vector2i(origin.x + dx * CHUNK, origin.y + dy * CHUNK)
			dx += 1
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
		dy += 1
	if built < budget:
		var dy2: int = -RING_OUT
		while dy2 <= RING_OUT and built < budget:
			var dx2: int = -RING_OUT
			while dx2 <= RING_OUT and built < budget:
				if maxi(absi(dx2), absi(dy2)) <= RING_IN:
					dx2 += 1
					continue
				var o2 := Vector2i(origin.x + dx2 * CHUNK, origin.y + dy2 * CHUNK)
				dx2 += 1
				if o2.x < 0 or o2.y < 0 or o2.x >= w or o2.y >= h:
					continue
				var job2: Dictionary = job_at(host, o2)
				if str(job2.state) != "pending":
					continue
				HitchLog.mark("geo_activate", Vector2i(job2.origin))
				activate_job(host, job2)
				built += 1
			dy2 += 1
	LoadTiming.dnote("geo_built", str(built))
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
	var mask: Dictionary = Emit._mask(host)
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
	var outlined: bool = not Clip._outline_spans(host).is_empty()
	var runs: Array[Dictionary] = []
	if outlined or not wall_cells.is_empty():
		runs = Clip._wall_runs(host, solid, sw, sh, wall_cells, ox, oy, x1, y1, n)
	HitchLog.mark("geo_runs")
	if not floor_cells.is_empty():
		if outlined:
			var lip: Node3D = Emit._emit_floor_lip(Clip._outline_loops(host), ox * n, oy * n, x1 * n, y1 * n, fine_m, host.floor_mat)
			HitchLog.mark("geo_lip")
			root.add_child(lip)
			var mm: MultiMeshInstance3D = Emit._first_mm(lip)
			if host.floor_mm == null and mm != null:
				host.floor_mm = mm
		else:
			var fm: MultiMeshInstance3D = Emit._emit_floors(WallRects.merge(floor_cells), fine_m, host.floor_mat)
			root.add_child(fm)
			if host.floor_mm == null:
				host.floor_mm = fm
			host.floor_mm = fm
		HitchLog.mark("geo_lip")
	if not runs.is_empty():
		var wall_inst: MeshInstance3D = Emit._ensure_wall_mesh(host, runs, fine_m)
		if wall_inst != null:
			root.add_child(wall_inst)
		HitchLog.mark("geo_walls")
	if outlined or not runs.is_empty():
		Emit._add_ribbon_boxes(root, runs, fine_m)
		HitchLog.mark("geo_col")
	elif not wall_cells.is_empty():
		add_collision(root, wall_cells, fine_m)
	job.node = root
	job.state = "live"

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
