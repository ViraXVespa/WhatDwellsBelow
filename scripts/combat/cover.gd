extends Object

const Combat := preload("res://scripts/combat/combat.gd")


static func hit_arc(origin: Vector3, dir: Vector2, rng: float, arc_deg: float, host: Node3D) -> float:
	if host == null or not is_instance_valid(host) or rng <= 0.001:
		return 0.0
	var aim := dir.normalized() if dir.length_squared() > 0.0001 else Vector2.DOWN
	var half := deg_to_rad(maxf(1.0, arc_deg) * 0.5)
	if not _fan_hits_sprite(origin, aim, rng, half, host):
		return 0.0
	var reach := Combat.xz(host).distance_to(Vector2(origin.x, origin.z))
	return _radial_q(reach, rng)


static func hit_circle(origin: Vector3, radius: float, host: Node3D) -> float:
	if host == null or not is_instance_valid(host) or radius <= 0.001:
		return 0.0
	if not _disk_hits_sprite(origin, radius, host):
		return 0.0
	var reach := Combat.xz(host).distance_to(Vector2(origin.x, origin.z))
	return _radial_q(reach, radius)


static func hit_disk(origin: Vector3, radius: float, host: Node3D) -> float:
	return hit_shot(origin, Vector2.ZERO, radius, host)


static func hit_shot(origin: Vector3, dir: Vector2, radius: float, host: Node3D) -> float:
	if host == null or not is_instance_valid(host) or radius <= 0.001:
		return 0.0
	var pts := _sprite_pts(host)
	if pts.is_empty():
		return 0.0
	var cam := _cam(host)
	var aim := dir.normalized() if dir.length_squared() > 0.0001 else Vector2.ZERO
	var depth := maxf(radius * 3.2, 0.45)
	if cam == null:
		var hit := 0
		var tot := 6
		for i in tot:
			var u := (float(i) + 0.5) / float(tot)
			var p := Vector2(origin.x, origin.z) + aim * (depth * u)
			if _near_pts(p, radius, pts):
				hit += 1
		return 0.0 if hit <= 0 else clampf(float(hit) / float(tot), 0.0, 1.0)
	var screens: Array[Vector2] = []
	for p in pts:
		screens.append(cam.unproject_position(p))
	var a := cam.unproject_position(origin)
	var b := cam.unproject_position(origin + Vector3(aim.x, 0.0, aim.y) * depth)
	var slop := 7.0
	var near := false
	var c := Vector2.ZERO
	for s in screens:
		c += s
		if _seg_dist(s, a, b) <= slop:
			near = true
	if not near:
		return 0.0
	c /= float(screens.size())
	var span := 1.0
	for s in screens:
		span = maxf(span, s.distance_to(c))
	var d := _seg_dist(c, a, b)
	var inner := span * 0.28
	if d <= inner:
		return 1.0
	if d >= span:
		return 0.35
	return lerpf(1.0, 0.35, (d - inner) / maxf(0.001, span - inner))


static func connected(cover: float) -> bool:
	return cover > 0.0001


static func dmg_mult(cover: float) -> float:
	return clampf(cover, 0.0, 1.0)


static func crit_ok(cover: float) -> bool:
	return cover >= 0.999


static func stops_arrow(cover: float) -> bool:
	return cover >= 0.85


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
	var cam := _cam(host)
	var pts := _sprite_pts(host)
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
		if _in_poly(cam.unproject_position(p), poly):
			return true
	return false


static func _disk_hits_sprite(origin: Vector3, radius: float, host: Node3D) -> bool:
	var cam := _cam(host)
	var pts := _sprite_pts(host)
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
		if _in_poly(cam.unproject_position(p), poly):
			return true
	return false


static func _sprite_pts(host: Node3D) -> Array[Vector3]:
	var spr := _spr_of(host)
	if spr == null or spr.texture == null:
		return [host.global_position + Vector3(0.0, 0.5, 0.0)]
	var pack := _mask_pack(spr)
	var cells: PackedByteArray = pack["cells"]
	var cols: int = pack["cols"]
	var rows: int = pack["rows"]
	if cells.is_empty() or cols <= 0 or rows <= 0:
		return []
	var w: float = pack["width"]
	var h: float = pack["height"]
	var c := spr.global_position
	var rx := spr.global_transform.basis.x
	if rx.length_squared() <= 0.0001:
		rx = Vector3.RIGHT
	else:
		rx = rx.normalized()
	var up := spr.global_transform.basis.y
	if up.length_squared() <= 0.0001:
		up = Vector3.UP
	else:
		up = up.normalized()
	var pts: Array[Vector3] = []
	for i in cols:
		var u := (float(i) + 0.5) / float(cols)
		var along := (u - 0.5) * w
		if spr.flip_h:
			along = -along
		for r in rows:
			if cells[r * cols + i] == 0:
				continue
			var v := (float(r) + 0.5) / float(rows)
			var lift := (0.5 - v) * h
			pts.append(c + rx * along + up * lift)
	return pts


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
	if spr.has_meta("cover_pack"):
		return spr.get_meta("cover_pack")
	var empty := {"cells": PackedByteArray(), "cols": 0, "rows": 0, "width": 0.0, "height": 0.0}
	if spr.texture == null:
		return empty
	var img := spr.texture.get_image()
	if img == null:
		return empty
	if img.is_compressed():
		img = img.duplicate()
		img.decompress()
	var cols := 28
	var rows := 16
	var alpha := 0.4
	if App.bal:
		cols = clampi(int(App.bal.cover_cols), 12, 48)
		alpha = float(App.bal.cover_alpha)
	var tw := img.get_width()
	var th := img.get_height()
	var cells := PackedByteArray()
	cells.resize(cols * rows)
	for r in rows:
		var y0 := int(float(r) / float(rows) * float(th))
		var y1 := int(float(r + 1) / float(rows) * float(th))
		for col in cols:
			var x0 := int(float(col) / float(cols) * float(tw))
			var x1 := int(float(col + 1) / float(cols) * float(tw))
			var hit := 0
			for x in range(x0, maxi(x0 + 1, x1)):
				for y in range(y0, maxi(y0 + 1, y1)):
					if img.get_pixel(x, y).a >= alpha:
						hit = 1
						break
				if hit == 1:
					break
			cells[r * cols + col] = hit
	var pack := {
		"cells": cells,
		"cols": cols,
		"rows": rows,
		"width": _world_w(spr),
		"height": _world_h(spr)
	}
	spr.set_meta("cover_pack", pack)
	return pack
