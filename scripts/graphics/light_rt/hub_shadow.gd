extends Object

## Hub bake image helpers: fill, blur, and locked mesh/sprite shadows.

const RT_PATH := "res://scripts/graphics/light_rt.gd"

static func _hub_lock_shadows(img: Image, org: Vector2, layout: Node) -> int:
	var sun := Vector3(-0.42, -1.0, 0.9).normalized()
	var root: Node = layout.get_parent() if layout != null else null
	if root == null:
		printerr("bake_camp: no_scene")
		return 0
	var wrote: int = 0
	var nodes: Array = root.find_children("*", "MeshInstance3D", true, false)
	var i: int = 0
	while i < nodes.size():
		var node: MeshInstance3D = nodes[i]
		i += 1
		if node == null or not is_instance_valid(node) or not node.visible:
			continue
		var low: String = str(node.name).to_lower()
		var path: String = str(node.get_path()).to_lower()
		if low == "blob" or low.find("grass") >= 0 or low.find("ground") >= 0 or low.find("fence") >= 0 or path.find("fence") >= 0:
			continue
		var at: Vector3 = node.global_position
		if at.y > 0.2 and (at.x < 0.5 or at.z < -1.5):
			continue
		if node.global_position.length() < 0.5:
			printerr("bake_camp: drop unplaced %s parent=%s" % [node.name, node.get_parent().name if node.get_parent() else ""])
			continue
		wrote += _hub_project_mesh(img, org, node, sun)
	var sprites: Array = root.find_children("*", "Sprite3D", true, false)
	var s: int = 0
	while s < sprites.size():
		wrote += _hub_project_sprite(img, org, sprites[s] as Sprite3D, sun)
		s += 1
	printerr("bake_camp: meshes=%d sprites=%d" % [nodes.size(), sprites.size()])
	return wrote
static func _hub_ground(v: Vector3, sun: Vector3) -> Vector2:
	if v.y < 0.12 or sun.y > -0.05:
		return Vector2(-99999.0, -99999.0)
	var t: float = (0.02 - v.y) / sun.y
	if t <= 0.0:
		return Vector2(-99999.0, -99999.0)
	var g: Vector3 = v + sun * t
	return Vector2(g.x, g.z)

static func _hub_dark(img: Image, x0: int, z0: int, sub: float, a: Vector2, b: Vector2, c: Vector2) -> int:
	if a.x < -1000.0 or b.x < -1000.0 or c.x < -1000.0:
		return 0
	var minx: float = minf(a.x, minf(b.x, c.x))
	var maxx: float = maxf(a.x, maxf(b.x, c.x))
	var minz: float = minf(a.y, minf(b.y, c.y))
	var maxz: float = maxf(a.y, maxf(b.y, c.y))
	var w: int = img.get_width()
	var h: int = img.get_height()
	var px0: int = clampi(int(floor((minx - float(x0)) * sub)), 0, w - 1)
	var px1: int = clampi(int(ceil((maxx - float(x0)) * sub)), 0, w)
	var pz0: int = clampi(int(floor((minz - float(z0)) * sub)), 0, h - 1)
	var pz1: int = clampi(int(ceil((maxz - float(z0)) * sub)), 0, h)
	var area: float = (b.x - a.x) * (c.y - a.y) - (c.x - a.x) * (b.y - a.y)
	if absf(area) < 0.0001:
		return 0
	var wrote: int = 0
	var y: int = pz0
	while y < pz1:
		var x: int = px0
		while x < px1:
			var wx: float = float(x0) + (float(x) + 0.5) / sub
			var wz: float = float(z0) + (float(y) + 0.5) / sub
			var w0: float = (b.x - wx) * (c.y - wz) - (c.x - wx) * (b.y - wz)
			var w1: float = (c.x - wx) * (a.y - wz) - (a.x - wx) * (c.y - wz)
			var w2: float = (a.x - wx) * (b.y - wz) - (b.x - wx) * (a.y - wz)
			if w0 / area >= -0.02 and w1 / area >= -0.02 and w2 / area >= -0.02:
				var col: Color = img.get_pixel(x, y)
				img.set_pixel(x, y, Color(minf(col.r, 0.42), minf(col.g, 0.4), minf(col.b, 0.38), 1.0))
				wrote += 1
			x += 1
		y += 1
	return wrote

static func _hub_project_mesh(img: Image, org: Vector2, node: MeshInstance3D, sun: Vector3) -> int:
	var rt: Variant = load(RT_PATH)
	if node == null or node.mesh == null or not node.visible:
		return 0
	var mesh: Mesh = node.mesh
	var xf: Transform3D = node.global_transform
	var sub: float = float(rt.HUB_SUB)
	var wrote: int = 0
	var si: int = 0
	while si < mesh.get_surface_count():
		var arrays: Array = mesh.surface_get_arrays(si)
		if arrays.is_empty() or arrays[Mesh.ARRAY_VERTEX] == null:
			si += 1
			continue
		var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		var raw = arrays[Mesh.ARRAY_INDEX]
		var indexed: bool = raw != null
		var idx: PackedInt32Array = raw if indexed else PackedInt32Array()
		var n: int = idx.size() if indexed else verts.size()
		var t: int = 0
		while t + 2 < n:
			var i0: int = idx[t] if indexed else t
			var i1: int = idx[t + 1] if indexed else t + 1
			var i2: int = idx[t + 2] if indexed else t + 2
			if i0 < verts.size() and i1 < verts.size() and i2 < verts.size():
				var a: Vector2 = _hub_ground(xf * verts[i0], sun)
				var b: Vector2 = _hub_ground(xf * verts[i1], sun)
				var c: Vector2 = _hub_ground(xf * verts[i2], sun)
				wrote += _hub_dark(img, int(org.x), int(org.y), sub, a, b, c)
			t += 3
		si += 1
	return wrote
static func _hub_project_sprite(img: Image, org: Vector2, spr: Sprite3D, sun: Vector3) -> int:
	var rt: Variant = load(RT_PATH)
	if spr == null or spr.texture == null:
		return 0
	var tw: float = float(spr.texture.get_width()) * spr.pixel_size
	var th: float = float(spr.texture.get_height()) * spr.pixel_size
	if spr.region_enabled:
		tw = spr.region_rect.size.x * spr.pixel_size
		th = spr.region_rect.size.y * spr.pixel_size
	var c: Vector3 = spr.global_position
	var xf: Transform3D = spr.global_transform
	var p0: Vector3 = xf * Vector3(-tw * 0.5, -th * 0.5, 0.0)
	var p1: Vector3 = xf * Vector3(tw * 0.5, -th * 0.5, 0.0)
	var p2: Vector3 = xf * Vector3(tw * 0.5, th * 0.5, 0.0)
	var p3: Vector3 = xf * Vector3(-tw * 0.5, th * 0.5, 0.0)
	var sub: float = float(rt.HUB_SUB)
	var wrote: int = 0
	wrote += _hub_dark(img, int(org.x), int(org.y), sub, _hub_ground(p0, sun), _hub_ground(p1, sun), _hub_ground(p2, sun))
	wrote += _hub_dark(img, int(org.x), int(org.y), sub, _hub_ground(p0, sun), _hub_ground(p2, sun), _hub_ground(p3, sun))
	return wrote

static func _hub_fill_black(img: Image) -> void:
	if img == null:
		return
	var field := Color(0.98, 0.96, 0.93, 1.0)
	var w: int = img.get_width()
	var h: int = img.get_height()
	var y: int = 0
	while y < h:
		var x: int = 0
		while x < w:
			var c: Color = img.get_pixel(x, y)
			if c.r <= 0.02 and c.g <= 0.02 and c.b <= 0.02:
				img.set_pixel(x, y, field)
			x += 1
		y += 1
static func _blur_hub(img: Image) -> void:
	var w: int = img.get_width()
	var h: int = img.get_height()
	var copy: Image = img.duplicate()
	var y: int = 0
	while y < h:
		var x: int = 0
		while x < w:
			var acc := Color(0, 0, 0, 0)
			var n: float = 0.0
			for oy in range(-1, 2):
				var py: int = y + oy
				if py < 0 or py >= h:
					continue
				for ox in range(-1, 2):
					var px: int = x + ox
					if px < 0 or px >= w:
						continue
					acc += copy.get_pixel(px, py)
					n += 1.0
			img.set_pixel(x, y, acc / n)
			x += 1
		y += 1
