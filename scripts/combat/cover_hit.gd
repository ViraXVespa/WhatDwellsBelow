extends Object

const Combat := preload("res://scripts/combat/combat.gd")
static func _mask_pack(spr: Sprite3D) -> Dictionary:
	var _fac = load("res://scripts/combat/cover.gd")
	if spr.has_meta("cover_pack"):
		return spr.get_meta("cover_pack")
	var empty := {"cells": PackedByteArray(), "cols": 0, "rows": 0, "width": 0.0, "height": 0.0, "locals": PackedVector3Array()}
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
	var locals := PackedVector3Array()
	var w: float = _fac._world_w(spr)
	var h: float = _fac._world_h(spr)
	for r in rows:
		var y0 := int(float(r) / float(rows) * float(th))
		var y1 := int(float(r + 1) / float(rows) * float(th))
		var v := (float(r) + 0.5) / float(rows)
		var lift := (0.5 - v) * h
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
			if hit == 1:
				var u := (float(col) + 0.5) / float(cols)
				locals.append(Vector3((u - 0.5) * w, lift, 0.0))
	var pack := {
		"cells": cells,
		"cols": cols,
		"rows": rows,
		"width": w,
		"height": h,
		"locals": locals
	}
	spr.set_meta("cover_pack", pack)
	return pack

static func hit_shot(origin: Vector3, dir: Vector2, radius: float, host: Node3D) -> float:
	var _fac = load("res://scripts/combat/cover.gd")
	if host == null or not is_instance_valid(host) or radius <= 0.001:
		return 0.0
	if not _fac._near_host(origin, radius, host):
		return 0.0
	var pts := _sprite_pts(host)
	if pts.is_empty():
		return 0.0
	var cam: Camera3D = _fac._cam(host)
	var aim := dir.normalized() if dir.length_squared() > 0.0001 else Vector2.ZERO
	var depth := maxf(radius * 3.2, 0.45)
	if cam == null:
		var hit := 0
		var tot := 6
		for i in tot:
			var u := (float(i) + 0.5) / float(tot)
			var p := Vector2(origin.x, origin.z) + aim * (depth * u)
			if _fac._near_pts(p, radius, pts):
				hit += 1
		return 0.0 if hit <= 0 else clampf(float(hit) / float(tot), 0.0, 1.0)
	var screens: Array[Vector2] = []
	for p in pts:
		screens.append(cam.unproject_position(p))
	var a: Vector2 = cam.unproject_position(origin)
	var b: Vector2 = cam.unproject_position(origin + Vector3(aim.x, 0.0, aim.y) * depth)
	var slop := 7.0
	var near := false
	var c := Vector2.ZERO
	for s in screens:
		c += s
		if _fac._seg_dist(s, a, b) <= slop:
			near = true
	if not near:
		return 0.0
	c /= float(screens.size())
	var span := 1.0
	for s in screens:
		span = maxf(span, s.distance_to(c))
	var d: float = _fac._seg_dist(c, a, b)
	var inner := span * 0.28
	if d <= inner:
		return 1.0
	if d >= span:
		return 0.35
	return lerpf(1.0, 0.35, (d - inner) / maxf(0.001, span - inner))

static func _sprite_pts(host: Node3D) -> Array[Vector3]:
	var _fac = load("res://scripts/combat/cover.gd")
	var spr: Sprite3D = _fac._spr_of(host)
	if spr == null or spr.texture == null:
		return [host.global_position + Vector3(0.0, 0.5, 0.0)]
	var frame: int = Engine.get_process_frames()
	if spr.has_meta("cover_pts_f") and int(spr.get_meta("cover_pts_f")) == frame:
		return spr.get_meta("cover_pts")
	var pack := _mask_pack(spr)
	var locals: PackedVector3Array = pack.get("locals", PackedVector3Array())
	var c: Vector3 = spr.global_position
	var rx: Vector3 = spr.global_transform.basis.x
	if rx.length_squared() <= 0.0001:
		rx = Vector3.RIGHT
	else:
		rx = rx.normalized()
	var up: Vector3 = spr.global_transform.basis.y
	if up.length_squared() <= 0.0001:
		up = Vector3.UP
	else:
		up = up.normalized()
	var pts: Array[Vector3] = []
	if not locals.is_empty():
		for off in locals:
			var along: float = off.x
			if spr.flip_h:
				along = -along
			pts.append(c + rx * along + up * off.y)
	else:
		pts = load("res://scripts/combat/cover_geom.gd")._sprite_pts_cells(spr, pack, c, rx, up)
	spr.set_meta("cover_pts_f", frame)
	spr.set_meta("cover_pts", pts)
	return pts
