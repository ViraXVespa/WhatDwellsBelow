extends Object

const Hit := preload("res://scripts/combat/cover/cover_hit.gd")
const Shape := preload("res://scripts/combat/cover/cover_shape.gd")

static func _fan_hits_sprite(origin: Vector3, aim: Vector2, rng: float, half: float, host: Node3D) -> bool:
	var cam: Camera3D = Shape._cam(host)
	var pts := Hit._sprite_pts(host)
	if pts.is_empty():
		return false
	if cam == null:
		var o := Vector2(origin.x, origin.z)
		for p in pts:
			var d := Vector2(p.x, p.z) - o
			var L := d.length()
			if L > rng:
				continue
			if L <= 0.04 or absf(aim.angle_to(d / L)) <= half:
				return true
		return false
	var poly := PackedVector2Array()
	poly.append(cam.unproject_position(Vector3(origin.x, 0.04, origin.z)))
	var segs := 16
	for i in segs + 1:
		var a := -half + (float(i) / float(segs)) * half * 2.0
		var d := Vector2(aim.x * cos(a) - aim.y * sin(a), aim.x * sin(a) + aim.y * cos(a))
		poly.append(cam.unproject_position(origin + Vector3(d.x, 0.0, d.y) * rng))
	for p in pts:
		if Shape._in_poly(cam.unproject_position(p), poly):
			return true
	return false

static func _disk_hits_sprite(origin: Vector3, radius: float, host: Node3D) -> bool:
	var cam: Camera3D = Shape._cam(host)
	var pts := Hit._sprite_pts(host)
	if pts.is_empty():
		return false
	if cam == null:
		var o := Vector2(origin.x, origin.z)
		for p in pts:
			if Vector2(p.x, p.z).distance_to(o) <= radius:
				return true
		return false
	var poly := PackedVector2Array()
	var segs := 16
	for i in segs:
		var a := TAU * float(i) / float(segs)
		poly.append(cam.unproject_position(origin + Vector3(cos(a) * radius, 0.0, sin(a) * radius)))
	for p in pts:
		if Shape._in_poly(cam.unproject_position(p), poly):
			return true
	return false
