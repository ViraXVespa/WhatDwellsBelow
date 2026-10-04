extends Object

## Hub bake only: building shadows projected from the real meshes onto the yard image, then the 3x3 blur.
## Same direction, reach and shade as the cast skirts in hub_cast.gd, so the two never disagree.

const HubCast := preload("res://scripts/graphics/light_rt/hub_cast.gd")
const RT_PATH := "res://scripts/graphics/light_rt.gd"
const SKIP_H := 0.2

## Darkens img under every shadow-casting mesh and building sprite below the Layout's parent (the camp in the tree).
## A building's parts (siblings under one body) share one top, so a wall and its roof fade as one shadow.
## Nothing is written inside a building's footprint (the parts that stand on the ground): its roof samples the atlas there.
## Returns pixels written.
static func _hub_mesh_shadows(img: Image, org: Vector2, layout: Node) -> int:
	var root: Node = layout.get_parent() if layout != null else null
	if root == null:
		printerr("bake_camp: no_scene")
		return 0
	var sub: float = float(load(RT_PATH).HUB_SUB)
	var casters: Array[GeometryInstance3D] = []
	var tops: Dictionary = {}
	var feet: Dictionary = {}
	for found in root.find_children("*", "GeometryInstance3D", true, false):
		var node := found as GeometryInstance3D
		if not _hub_casts(node):
			continue
		casters.append(node)
		var top: float = (node.global_transform * node.get_aabb()).end.y
		tops[node.get_parent()] = maxf(top, float(tops.get(node.get_parent(), 0.5)))
		var bb: AABB = node.global_transform * node.get_aabb()
		if bb.position.y < SKIP_H:
			var fp := Rect2(bb.position.x, bb.position.z, bb.size.x, bb.size.z)
			feet[node.get_parent()] = (feet[node.get_parent()] as Rect2).merge(fp) if feet.has(node.get_parent()) else fp
	var prot: Array = feet.values()
	var wrote: int = 0
	for node in casters:
		var top: float = tops[node.get_parent()]
		if node is MeshInstance3D:
			wrote += _hub_project_mesh(img, org, sub, node, top, prot)
		else:
			wrote += _hub_project_sprite(img, org, sub, node, top, prot)
	printerr("bake_camp: shadow_casters=%d" % casters.size())
	return wrote

## Meshes and building sprites that stand on the yard. Fence rails and posts are built with shadows off; ground
## planes and anything under SKIP_H are flat.
static func _hub_casts(node: GeometryInstance3D) -> bool:
	if node == null or not node.is_visible_in_tree() or node.cast_shadow == GeometryInstance3D.SHADOW_CASTING_SETTING_OFF:
		return false
	if node is Sprite3D:
		if (node as Sprite3D).texture == null:
			return false
	elif not (node is MeshInstance3D) or (node as MeshInstance3D).mesh == null or (node as MeshInstance3D).mesh is PlaneMesh:
		return false
	return (node.global_transform * node.get_aabb()).size.y >= SKIP_H

## World point to ground: a point h up lands HubCast.REACH * h along HubCast.AWAY. Ground and below stays put.
static func _hub_ground(v: Vector3) -> Vector2:
	var h: float = maxf(v.y, 0.0) * HubCast.REACH
	return Vector2(v.x + HubCast.AWAY.x * h, v.z + HubCast.AWAY.y * h)

static func _hub_project_mesh(img: Image, org: Vector2, sub: float, node: MeshInstance3D, top: float, prot: Array) -> int:
	var xf: Transform3D = node.global_transform
	var wrote: int = 0
	for si in node.mesh.get_surface_count():
		var arrays: Array = node.mesh.surface_get_arrays(si)
		if arrays.is_empty() or arrays[Mesh.ARRAY_VERTEX] == null:
			continue
		var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		var raw = arrays[Mesh.ARRAY_INDEX]
		var idx: PackedInt32Array = raw if raw != null else PackedInt32Array()
		var n: int = idx.size() if raw != null else verts.size()
		var t: int = 0
		while t + 2 < n:
			var w: Array[Vector3] = []
			for k in 3:
				w.append(xf * verts[idx[t + k] if raw != null else t + k])
			wrote += _hub_fill(img, org, sub, w, top, prot)
			t += 3
	return wrote

static func _hub_in(rects: Array, wx: float, wz: float) -> bool:
	for r: Rect2 in rects:
		if wx >= r.position.x and wx <= r.end.x and wz >= r.position.y and wz <= r.end.y:
			return true
	return false

## A Sprite3D is an opaque quad (the building art): two triangles from its local bounds.
static func _hub_project_sprite(img: Image, org: Vector2, sub: float, spr: Sprite3D, top: float, prot: Array) -> int:
	var lb: AABB = spr.get_aabb()
	var xf: Transform3D = spr.global_transform
	var p0: Vector3 = xf * Vector3(lb.position.x, lb.position.y, 0.0)
	var p1: Vector3 = xf * Vector3(lb.end.x, lb.position.y, 0.0)
	var p2: Vector3 = xf * Vector3(lb.end.x, lb.end.y, 0.0)
	var p3: Vector3 = xf * Vector3(lb.position.x, lb.end.y, 0.0)
	return _hub_fill(img, org, sub, [p0, p1, p2], top, prot) + _hub_fill(img, org, sub, [p0, p2, p3], top, prot)

## Fills one projected triangle at pixel centres (closed edges, so neighbours leave no cracks). The caster height is
## interpolated per pixel and sets the shade, so a shadow is darkest at the wall and lightens toward its tip.
static func _hub_fill(img: Image, org: Vector2, sub: float, w: Array, top: float, prot: Array) -> int:
	var a: Vector2 = _hub_ground(w[0])
	var b: Vector2 = _hub_ground(w[1])
	var c: Vector2 = _hub_ground(w[2])
	var area: float = (b.x - a.x) * (c.y - a.y) - (c.x - a.x) * (b.y - a.y)
	if absf(area) < 0.0001:
		return 0
	var px0: int = clampi(int(floor((minf(a.x, minf(b.x, c.x)) - org.x) * sub)) - 1, 0, img.get_width() - 1)
	var px1: int = clampi(int(ceil((maxf(a.x, maxf(b.x, c.x)) - org.x) * sub)) + 1, 0, img.get_width())
	var pz0: int = clampi(int(floor((minf(a.y, minf(b.y, c.y)) - org.y) * sub)) - 1, 0, img.get_height() - 1)
	var pz1: int = clampi(int(ceil((maxf(a.y, maxf(b.y, c.y)) - org.y) * sub)) + 1, 0, img.get_height())
	var wrote: int = 0
	for y in range(pz0, pz1):
		var wz: float = org.y + (float(y) + 0.5) / sub
		for x in range(px0, px1):
			var wx: float = org.x + (float(x) + 0.5) / sub
			var l0: float = ((b.x - wx) * (c.y - wz) - (c.x - wx) * (b.y - wz)) / area
			var l1: float = ((c.x - wx) * (a.y - wz) - (a.x - wx) * (c.y - wz)) / area
			var l2: float = 1.0 - l0 - l1
			if l0 < -0.0001 or l1 < -0.0001 or l2 < -0.0001:
				continue
			if _hub_in(prot, wx, wz):
				continue
			var h: float = maxf(0.0, l0 * w[0].y + l1 * w[1].y + l2 * w[2].y)
			var shade: float = HubCast.shade_at(h / top)
			var col: Color = img.get_pixel(x, y)
			if col.r > shade:
				img.set_pixel(x, y, Color(minf(col.r, shade), minf(col.g, shade), minf(col.b, shade), 1.0))
				wrote += 1
	return wrote
static func _row(img: Image, y: int, w: int) -> PackedColorArray:
	var r := PackedColorArray()
	r.resize(w)
	for x in w:
		r[x] = img.get_pixel(x, y)
	return r
static func _blur_hub(img: Image) -> void:
	# 3x3 mean, edges renormalised. Same Color math and add order as the generic form (byte-identical).
	# Interior pixels read three cached source rows (each pixel fetched once, not nine times).
	var w: int = img.get_width()
	var h: int = img.get_height()
	var copy: Image = img.duplicate()
	var up: PackedColorArray
	var mid: PackedColorArray = _row(copy, 0, w)
	var down: PackedColorArray = _row(copy, 1, w) if h > 1 else mid
	var y: int = 0
	while y < h:
		var inner_y: bool = y > 0 and y < h - 1
		if inner_y:
			for x in range(1, w - 1):
				img.set_pixel(x, y, (
					up[x - 1] + up[x] + up[x + 1] + mid[x - 1] + mid[x] + mid[x + 1]
					+ down[x - 1] + down[x] + down[x + 1]
				) / 9.0)
		var edges: Array = [0, w - 1] if inner_y else range(w)
		for x in edges:
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
		up = mid
		mid = down
		down = _row(copy, y + 2, w) if y + 2 < h else mid
		y += 1
