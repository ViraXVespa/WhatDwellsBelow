extends Object

const Combat := preload("res://scripts/combat/combat.gd")
const Hit := preload("res://scripts/combat/cover_hit.gd")

static func _fan_hits_sprite(origin: Vector3, aim: Vector2, rng: float, half: float, host: Node3D) -> bool:
	var _fac = load("res://scripts/combat/cover.gd")
	var cam: Camera3D = _fac._cam(host)
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
		if _fac._in_poly(cam.unproject_position(p), poly):
			return true
	return false

static func _sprite_pts_cells(spr: Sprite3D, pack: Dictionary, c: Vector3, rx: Vector3, up: Vector3) -> Array[Vector3]:
	var cells: PackedByteArray = pack["cells"]
	var cols: int = pack["cols"]
	var rows: int = pack["rows"]
	if cells.is_empty() or cols <= 0 or rows <= 0:
		return []
	var w: float = pack["width"]
	var h: float = pack["height"]
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

static func _disk_hits_sprite(origin: Vector3, radius: float, host: Node3D) -> bool:
	var _fac = load("res://scripts/combat/cover.gd")
	var cam: Camera3D = _fac._cam(host)
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
		if _fac._in_poly(cam.unproject_position(p), poly):
			return true
	return false
