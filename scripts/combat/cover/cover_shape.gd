extends Object

## Sprite shape and screen geometry shared by the cover facade and its helpers (moved from cover.gd).

const Combat := preload("res://scripts/combat/combat.gd")

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
