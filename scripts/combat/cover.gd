extends Object

const Combat := preload("res://scripts/combat/combat.gd")
const Hit := preload("res://scripts/combat/cover_hit.gd")
const Geom := preload("res://scripts/combat/cover_geom.gd")


static func hit_arc(origin: Vector3, dir: Vector2, rng: float, arc_deg: float, host: Node3D) -> float:
	if host == null or not is_instance_valid(host) or rng <= 0.001:
		return 0.0
	var aim := dir.normalized() if dir.length_squared() > 0.0001 else Vector2.DOWN
	var half := deg_to_rad(maxf(1.0, arc_deg) * 0.5)
	if not Geom._fan_hits_sprite(origin, aim, rng, half, host):
		return 0.0
	var reach := Combat.xz(host).distance_to(Vector2(origin.x, origin.z))
	return _radial_q(reach, rng)

static func hit_circle(origin: Vector3, radius: float, host: Node3D) -> float:
	if host == null or not is_instance_valid(host) or radius <= 0.001:
		return 0.0
	if not Geom._disk_hits_sprite(origin, radius, host):
		return 0.0
	var reach := Combat.xz(host).distance_to(Vector2(origin.x, origin.z))
	return _radial_q(reach, radius)

static func hit_disk(origin: Vector3, radius: float, host: Node3D) -> float:
	return Hit.hit_shot(origin, Vector2.ZERO, radius, host)

static func hit_shot(origin: Vector3, dir: Vector2, radius: float, host: Node3D) -> float:
	return Hit.hit_shot(origin, dir, radius, host)

static func connected(cover: float) -> bool:
	return cover > 0.0001

static func dmg_mult(cover: float) -> float:
	return clampf(cover, 0.0, 1.0)

static func crit_ok(cover: float) -> bool:
	return cover >= 0.999

static func stops_arrow(cover: float) -> bool:
	return cover >= 0.85

static func _near_host(origin: Vector3, radius: float, host: Node3D) -> bool:
	var spr := _spr_of(host)
	var span := 1.35
	if spr:
		span = maxf(_world_w(spr), _world_h(spr)) * 0.6 + 0.35
	var lim: float = radius + span + maxf(radius * 3.2, 0.45)
	return Combat.xz(host).distance_to(Vector2(origin.x, origin.z)) <= lim

static func _seg_dist(p: Vector2, a: Vector2, b: Vector2) -> float:
	var ab := b - a
	var l2 := ab.length_squared()
	if l2 <= 0.0001:
		return p.distance_to(a)
	var t := clampf((p - a).dot(ab) / l2, 0.0, 1.0)
	return p.distance_to(a + ab * t)

static func _near_pts(p: Vector2, radius: float, pts: Array[Vector3]) -> bool:
	for q in pts:
		if Vector2(q.x, q.z).distance_to(p) <= radius:
			return true
	return false

static func _radial_q(dist: float, rng: float) -> float:
	var tip := 0.18
	var edge := 0.35
	if App.bal:
		tip = clampf(float(App.bal.cover_full), 0.05, 0.4)
		edge = clampf(float(App.bal.cover_edge_mult), 0.05, 1.0)
	if rng <= 0.001:
		return 1.0
	var t := clampf(dist / rng, 0.0, 1.0)
	var start := 1.0 - tip
	if t <= start:
		return 1.0
	var u := clampf((t - start) / tip, 0.0, 1.0)
	return lerpf(1.0, edge, u)

static func _fan_hits_sprite(origin: Vector3, aim: Vector2, rng: float, half: float, host: Node3D) -> bool:
	return Geom._fan_hits_sprite(origin, aim, rng, half, host)

static func _disk_hits_sprite(origin: Vector3, radius: float, host: Node3D) -> bool:
	return Geom._disk_hits_sprite(origin, radius, host)

static func _sprite_pts(host: Node3D) -> Array[Vector3]:
	return Hit._sprite_pts(host)

static func _sprite_pts_cells(spr: Sprite3D, pack: Dictionary, c: Vector3, rx: Vector3, up: Vector3) -> Array[Vector3]:
	return Geom._sprite_pts_cells(spr, pack, c, rx, up)

static func _cam(host: Node3D) -> Camera3D:
	if not host.is_inside_tree():
		return null
	return host.get_viewport().get_camera_3d()

static func _in_poly(p: Vector2, poly: PackedVector2Array) -> bool:
	var n := poly.size()
	if n < 3:
		return false
	var inside := false
	var j := n - 1
	for i in n:
		var aa := poly[i]
		var bb := poly[j]
		if ((aa.y > p.y) != (bb.y > p.y)) and (p.x < (bb.x - aa.x) * (p.y - aa.y) / ((bb.y - aa.y) + 0.0000001) + aa.x):
			inside = not inside
		j = i
	return inside

static func _spr_of(host: Node3D) -> Sprite3D:
	var s: Variant = host.get("spr")
	if s is Sprite3D:
		return s
	var b: Variant = host.get("body")
	if b is Sprite3D:
		return b
	return null

static func _world_w(spr: Sprite3D) -> float:
	if spr.texture == null:
		return 0.6
	return maxf(0.08, float(spr.texture.get_width()) * spr.pixel_size)

static func _world_h(spr: Sprite3D) -> float:
	if spr.texture == null:
		return 1.2
	return maxf(0.08, float(spr.texture.get_height()) * spr.pixel_size)

static func _mask_pack(spr: Sprite3D) -> Dictionary:
	return Hit._mask_pack(spr)
