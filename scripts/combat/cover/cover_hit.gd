extends Object

## Texel cells, once per texture. A slam used to scan every sprite in the circle with get_pixel.

static var _cells: Dictionary = {}

static func warm_texture(tex: Texture2D) -> void:
	if tex == null:
		return
	_cells_for(tex)

static func warm_sprite(spr: Sprite3D) -> void:
	if spr == null or spr.texture == null:
		return
	_mask_pack(spr)

static func warm_known() -> void:
	var roster: GDScript = load("res://scripts/combat/roster.gd") as GDScript
	var seen: Dictionary = {}
	for pool in roster.POOLS:
		for type_id in pool:
			var id: String = str(type_id)
			if seen.has(id):
				continue
			seen[id] = true
			_warm_path("res://assets/sprites/enemies/%s/idle_down.png" % id)
	_warm_path("res://assets/sprites/enemies/guardian/idle_down.png")
	_warm_path("res://assets/sprites/enemies/gate_master/idle_down.png")
	_warm_path("res://assets/fx/dummy.png")

static func _warm_path(path: String) -> void:
	if not ResourceLoader.exists(path):
		return
	var tex: Texture2D = load(path) as Texture2D
	warm_texture(tex)

static func _grid() -> Vector3:
	var cols: float = 28.0
	var alpha: float = 0.4
	if App.bal:
		cols = float(clampi(int(App.bal.cover_cols), 12, 48))
		alpha = float(App.bal.cover_alpha)
	return Vector3(cols, 16.0, alpha)

static func _cell_key(tex: Texture2D) -> String:
	var g: Vector3 = _grid()
	return "%s:%s:%s:%s" % [tex.get_instance_id(), int(g.x), int(g.y), g.z]

static func _cells_for(tex: Texture2D) -> PackedByteArray:
	var key: String = _cell_key(tex)
	if _cells.has(key):
		return _cells[key]
	var img: Image = tex.get_image()
	if img == null:
		return PackedByteArray()
	if img.is_compressed():
		img = img.duplicate()
		img.decompress()
	var g: Vector3 = _grid()
	var cols: int = int(g.x)
	var rows: int = int(g.y)
	var cells := PackedByteArray()
	cells.resize(cols * rows)
	_fill_cells(img, cells, cols, rows, g.z)
	_cells[key] = cells
	return cells

static func _fill_cells(img: Image, cells: PackedByteArray, cols: int, rows: int, alpha: float) -> void:
	var tw: int = img.get_width()
	var th: int = img.get_height()
	if tw <= 0 or th <= 0:
		return
	var bytes: PackedByteArray = img.get_data()
	var rgba: bool = img.get_format() == Image.FORMAT_RGBA8 and bytes.size() >= tw * th * 4
	for r in rows:
		var y0: int = int(float(r) / float(rows) * float(th))
		var y1: int = int(float(r + 1) / float(rows) * float(th))
		for col in cols:
			var x0: int = int(float(col) / float(cols) * float(tw))
			var x1: int = int(float(col + 1) / float(cols) * float(tw))
			var hit: int = 0
			for y in range(y0, maxi(y0 + 1, y1)):
				for x in range(x0, maxi(x0 + 1, x1)):
					var a: float = 0.0
					if rgba:
						a = float(bytes[(y * tw + x) * 4 + 3]) / 255.0
					else:
						a = img.get_pixel(x, y).a
					if a >= alpha:
						hit = 1
						break
				if hit == 1:
					break
			cells[r * cols + col] = hit

static func _locals(cells: PackedByteArray, cols: int, rows: int, w: float, h: float) -> PackedVector3Array:
	var locals := PackedVector3Array()
	if cols <= 0 or rows <= 0:
		return locals
	for r in rows:
		var v: float = (float(r) + 0.5) / float(rows)
		var lift: float = (0.5 - v) * h
		for col in cols:
			if int(cells[r * cols + col]) == 0:
				continue
			var u: float = (float(col) + 0.5) / float(cols)
			locals.append(Vector3((u - 0.5) * w, lift, 0.0))
	return locals

static func _mask_pack(spr: Sprite3D) -> Dictionary:
	var _fac = load("res://scripts/combat/cover.gd")
	if spr.texture == null:
		return {"cells": PackedByteArray(), "cols": 0, "rows": 0, "width": 0.0, "height": 0.0, "locals": PackedVector3Array(), "tex": 0}
	var tex_id: int = spr.texture.get_instance_id()
	if spr.has_meta("cover_pack"):
		var prev: Dictionary = spr.get_meta("cover_pack")
		if int(prev.get("tex", -1)) == tex_id:
			return prev
	var g: Vector3 = _grid()
	var cells: PackedByteArray = _cells_for(spr.texture)
	if cells.is_empty() and not _cells.has(_cell_key(spr.texture)):
		return {"cells": PackedByteArray(), "cols": 0, "rows": 0, "width": 0.0, "height": 0.0, "locals": PackedVector3Array(), "tex": tex_id}
	var w: float = _fac._world_w(spr)
	var h: float = _fac._world_h(spr)
	var pack: Dictionary = {
		"cells": cells,
		"cols": int(g.x),
		"rows": int(g.y),
		"width": w,
		"height": h,
		"locals": _locals(cells, int(g.x), int(g.y), w, h),
		"tex": tex_id,
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
		pts = load("res://scripts/combat/cover/geom.gd")._sprite_pts_cells(spr, pack, c, rx, up)
	spr.set_meta("cover_pts_f", frame)
	spr.set_meta("cover_pts", pts)
	return pts
