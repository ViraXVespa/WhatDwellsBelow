extends Object

const Combat := preload("res://scripts/combat/combat.gd")
const Hit := preload("res://scripts/combat/cover/cover_hit.gd")
const Geom := preload("res://scripts/combat/cover/geom.gd")

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

static func hit_shot(origin: Vector3, dir: Vector2, radius: float, host: Node3D) -> float:
	return Hit.hit_shot(origin, dir, radius, host)

static func warm_texture(tex: Texture2D) -> void:
	Hit.warm_texture(tex)

static func warm_sprite(spr: Sprite3D) -> void:
	Hit.warm_sprite(spr)

static func connected(cover: float) -> bool:
	return cover > 0.0001

static func dmg_mult(cover: float) -> float:
	return clampf(cover, 0.0, 1.0)

static func crit_ok(cover: float) -> bool:
	return cover >= 0.999

static func stops_arrow(cover: float) -> bool:
	return cover >= 0.85

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
