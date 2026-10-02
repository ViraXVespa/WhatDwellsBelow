extends Object

const Rooms := preload("res://scripts/dungeon/gen/gen_rooms.gd")
const Threat := preload("res://scripts/combat/threat.gd")
const EnvKit := preload("res://scripts/graphics/env_kit.gd")
const GroundShader := preload("res://scripts/graphics/ground_shader.gd")
const WallShader: GDScript = preload("res://scripts/graphics/wall_shader.gd")

static func world(host: Node) -> void:
	EnvKit.apply(
		host, Color(0.03, 0.035, 0.05), Color(0.62, 0.68, 0.74), 0.85, Vector3(-52.0, 28.0, 0.0), 0.65, Color(0.82, 0.88, 0.95)
	)

static func collision_walls(host: Node) -> void:
	host.walls = StaticBody3D.new()
	host.walls.collision_layer = 1
	host.walls.collision_mask = 0
	host.add_child(host.walls)

static func box(body: StaticBody3D, size: Vector3, offset: Vector3) -> void:
	var cs := CollisionShape3D.new()
	var sh := BoxShape3D.new()
	sh.size = size
	cs.shape = sh
	cs.position = offset
	body.add_child(cs)

static func build_visuals(host: Node) -> void:
	host.floor_mat = GroundShader.material("res://assets/tiles/dungeon_floor.png", Color(0.18, 0.2, 0.24))
	host.wall_mat = WallShader.material("res://assets/tiles/wall_brick.png", Color(0.22, 0.22, 0.26))
	var StreamGeo = load("res://scripts/world/dungeon_geo_stream.gd")
	StreamGeo.setup(host)

static func build_travel(host: Node) -> void:
	var sp: Vector2i = host.data.get("spawn", Vector2i.ZERO)
	host.travel_dist = Rooms.bfs(host.data.grid, int(host.data.w), int(host.data.h), sp)
	var vals: Array[int] = []
	for i in host.travel_dist.size():
		if host.travel_dist[i] >= 0:
			vals.append(host.travel_dist[i])
	if vals.is_empty():
		host.travel_cap = 1
		return
	vals.sort()
	var pct := clampf(float(App.bal.enemy_cl_end_pct), 0.72, 0.96)
	var idx := clampi(int(round(float(vals.size() - 1) * pct)), 0, vals.size() - 1)
	host.travel_cap = maxi(1, vals[idx])

static func enemy_combat_lv(host: Node, pos: Vector3) -> int:
	return Threat.level_at(App.floor_n, host._world_cell(pos), host.travel_dist, int(host.data.w), host.travel_cap)
