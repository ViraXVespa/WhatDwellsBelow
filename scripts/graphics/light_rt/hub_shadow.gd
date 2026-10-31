extends Object

## Hub bake only: building shadows projected from the real meshes onto the yard image (the 3x3 blur: hub_blur.gd).
## Direction, reach and shade: hub_cast.gd (AWAY, REACH, shade_at).

const HubCast := preload("res://scripts/graphics/light_rt/hub_cast.gd")
const RT_PATH := "res://scripts/graphics/light_rt.gd"
const SKIP_H := 0.2
const PROPS_PATH := "res://scripts/graphics/light_rt/hub_props.gd"
const Roof := preload("res://scripts/graphics/light_rt/hub_roof.gd")
## Last bake's footprints (hub_blur.gd zones).
static var prot_rects: Array = []

## Darkens img under every shadow-casting mesh and building sprite below the Layout's parent (the camp in the tree).
## A building's parts (siblings under one body) share one top, so a wall and its roof fade as one shadow; a roof
## (covering mesh) shades no lighter than its body's wall top (eave), so the gable outline reads past the walls.
## Awnings are not protected (the yard under them is shaded; the cloth samples inside its wall, mesh_mat.awning_mat).
## Nothing is written inside a body's own footprint (its roof samples the atlas there). Another body's footprint with
## a roof is a receiver (hub_roof.gd): it is shaded where the ray clears that roof; other footprints stay clear.
## Returns pixels written.
static func _hub_mesh_shadows(img: Image, org: Vector2, layout: Node) -> int:
	var root: Node = layout.get_parent() if layout != null else null
	if root == null:
		printerr("bake_camp: no_scene")
		return 0
	var sub: float = float(load(RT_PATH).HUB_SUB)
	var casters: Array[GeometryInstance3D] = []
	var tops: Dictionary = {}
	var eaves: Dictionary = {}
	var covers: Dictionary = {}
	var feet: Dictionary = {}
	for found in root.find_children("*", "GeometryInstance3D", true, false):
		var node := found as GeometryInstance3D
		if not _hub_casts(node):
			continue
		casters.append(node)
		var bb: AABB = node.global_transform * node.get_aabb()
		var key: Node = node.get_parent()
		tops[key] = maxf(bb.end.y, float(tops.get(key, 0.5)))
		if _is_covering(node.name):
			covers[key] = (covers[key] as AABB).merge(bb) if covers.has(key) else bb
		else:
			eaves[key] = maxf(bb.end.y, float(eaves.get(key, 0.0)))
		# Ground-level parts OR elevated covering meshes (tarp/roof/gable/awning) protect their XZ footprint.
		if bb.position.y < SKIP_H or _is_covering(node.name):
			var fp := Rect2(bb.position.x, bb.position.z, bb.size.x, bb.size.z)
			feet[key] = (feet[key] as Rect2).merge(fp) if feet.has(key) else fp
	var prot: Array = feet.values()
	prot_rects = prot
	var recv: Array = []
	for k in feet:
		var r: Rect2 = feet[k]
		printerr("bake_dbg: prot %s %.3f %.3f %.3f %.3f" % [(k as Node).name, r.position.x, r.position.y, r.size.x, r.size.y])
		if covers.has(k):
			recv.append(Roof.make(k, r, covers[k]))
			printerr("bake_camp: roof_recv %s eave=%.3f ridge=%.3f" % [(k as Node).name, recv[-1]["eave"], recv[-1]["ridge"]])
	for sp in root.find_children("*", "SpriteBase3D", true, false):
		var sb: AABB = (sp as Node3D).global_transform * (sp as VisualInstance3D).get_aabb()
		printerr("bake_dbg: spr %s/%s %.3f %.3f %.3f %.3f %.3f %.3f" % [sp.get_parent().name, sp.name, sb.position.x, sb.position.y, sb.position.z, sb.size.x, sb.size.y, sb.size.z])
	for node in casters:
		var cb: AABB = node.global_transform * node.get_aabb()
		printerr("bake_dbg: cast %s/%s %.3f %.3f %.3f %.3f %.3f" % [node.get_parent().name, node.name, cb.position.x, cb.position.z, cb.size.x, cb.size.z, cb.end.y])
	var wrote: int = 0
	for node in casters:
		var key: Node = node.get_parent()
		var ctx: Dictionary = _ctx(key, float(tops[key]), feet, recv)
		if _is_covering(node.name):
			ctx["cap"] = float(eaves.get(key, ctx["top"]))
		if node is MeshInstance3D:
			wrote += _hub_project_mesh(img, org, sub, node, ctx)
		else:
			wrote += _hub_project_sprite(img, org, sub, node, ctx)
	var fence_px: int = 0
	# Fence boxes skip live shadows (cast_shadow off) but are real rails and posts: project them as they are.
	var fence_ctx: Dictionary = {"top": layout.fence_shadow_top(), "cap": layout.fence_shadow_top(), "skip": prot, "recv": []}
	for body in root.get_tree().get_nodes_in_group("hub_fence"):
		for mi in (body as Node).find_children("*", "MeshInstance3D", true, false):
			fence_px += _hub_project_mesh(img, org, sub, mi, fence_ctx)
	wrote += fence_px
	printerr("bake_camp: fence_px=%d" % fence_px)
	printerr("bake_camp: shadow_casters=%d" % casters.size())
	printerr("bake_camp: lamp_px=%d" % load(PROPS_PATH).lamp_glow(img, org, sub, root))
	load(PROPS_PATH).overlay_dbg(org, sub, root, layout)
	return wrote

## Fill context for one caster body: its own footprint and roofless footprints are skipped, other roofs receive.
static func _ctx(key: Node, top: float, feet: Dictionary, recv: Array) -> Dictionary:
	var skip: Array = []
	var others: Array = []
	for r: Dictionary in recv:
		if r["body"] != key:
			others.append(r)
	for k in feet:
		if k == key or not others.any(func(r: Dictionary) -> bool: return r["body"] == k):
			skip.append(feet[k])
	return {"top": top, "cap": top, "skip": skip, "recv": others}

static func _is_covering(name: String) -> bool:
	var n := name.to_lower()
	return n.contains("pitch") or n.contains("gable") or n.contains("roof") or n.contains("tarp")
static func _hub_casts(node: GeometryInstance3D) -> bool:
	if node == null or node.cast_shadow == GeometryInstance3D.SHADOW_CASTING_SETTING_OFF:
		return false
	if not node.is_visible_in_tree() and node.cast_shadow != GeometryInstance3D.SHADOW_CASTING_SETTING_SHADOWS_ONLY:
		return false
	if node is Sprite3D:
		if (node as Sprite3D).texture == null:
			return false
	elif not (node is MeshInstance3D) or (node as MeshInstance3D).mesh == null or (node as MeshInstance3D).mesh is PlaneMesh:
		return false
	return (node.global_transform * node.get_aabb()).size.y >= SKIP_H
static func _hub_ground(v: Vector3) -> Vector2:
	var h: float = maxf(v.y, 0.0) * HubCast.REACH
	return Vector2(v.x + HubCast.AWAY.x * h, v.z + HubCast.AWAY.y * h)

static func _hub_project_mesh(img: Image, org: Vector2, sub: float, node: MeshInstance3D, ctx: Dictionary) -> int:
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
			wrote += _hub_fill(img, org, sub, w, ctx)
			t += 3
	return wrote

static func _hub_in(rects: Array, wx: float, wz: float) -> bool:
	for r: Rect2 in rects:
		if wx >= r.position.x and wx <= r.end.x and wz >= r.position.y and wz <= r.end.y:
			return true
	return false

## A Sprite3D is an opaque quad (the building art): two triangles from its local bounds.
static func _hub_project_sprite(img: Image, org: Vector2, sub: float, spr: Sprite3D, ctx: Dictionary) -> int:
	var lb: AABB = spr.get_aabb()
	var xf: Transform3D = spr.global_transform
	var p0: Vector3 = xf * Vector3(lb.position.x, lb.position.y, 0.0)
	var p1: Vector3 = xf * Vector3(lb.end.x, lb.position.y, 0.0)
	var p2: Vector3 = xf * Vector3(lb.end.x, lb.end.y, 0.0)
	var p3: Vector3 = xf * Vector3(lb.position.x, lb.end.y, 0.0)
	return _hub_fill(img, org, sub, [p0, p1, p2], ctx) + _hub_fill(img, org, sub, [p0, p2, p3], ctx)

## Fills one projected triangle at pixel centres (closed edges, so neighbours leave no cracks). The caster height is
## interpolated per pixel and sets the shade, so a shadow is darkest at the wall and lightens toward its tip. Inside a
## receiver roof the triangle is read where the ray meets the roof (pixel + Roof.shift(roof height)), above it only.
static func _hub_fill(img: Image, org: Vector2, sub: float, w: Array, ctx: Dictionary) -> int:
	var a: Vector2 = _hub_ground(w[0])
	var b: Vector2 = _hub_ground(w[1])
	var c: Vector2 = _hub_ground(w[2])
	var area: float = (b.x - a.x) * (c.y - a.y) - (c.x - a.x) * (b.y - a.y)
	if absf(area) < 0.0001:
		return 0
	var recv: Array = ctx["recv"]
	var back: Vector2 = Roof.shift(Roof.reach(recv))
	var px0: int = clampi(int(floor((minf(a.x, minf(b.x, c.x)) - back.x - org.x) * sub)) - 1, 0, img.get_width() - 1)
	var px1: int = clampi(int(ceil((maxf(a.x, maxf(b.x, c.x)) - org.x) * sub)) + 1, 0, img.get_width())
	var pz0: int = clampi(int(floor((minf(a.y, minf(b.y, c.y)) - back.y - org.y) * sub)) - 1, 0, img.get_height() - 1)
	var pz1: int = clampi(int(ceil((maxf(a.y, maxf(b.y, c.y)) - org.y) * sub)) + 1, 0, img.get_height())
	var top: float = ctx["top"]
	var cap: float = ctx["cap"]
	var wrote: int = 0
	for y in range(pz0, pz1):
		var wz: float = org.y + (float(y) + 0.5) / sub
		for x in range(px0, px1):
			var wx: float = org.x + (float(x) + 0.5) / sub
			if _hub_in(ctx["skip"], wx, wz):
				continue
			var floor_h: float = 0.0
			var g := Vector2(wx, wz)
			var roof: Dictionary = Roof.at(recv, wx, wz) if not recv.is_empty() else {}
			if not roof.is_empty():
				floor_h = Roof.height(roof, wz)
				g += Roof.shift(floor_h)
			var l0: float = ((b.x - g.x) * (c.y - g.y) - (c.x - g.x) * (b.y - g.y)) / area
			var l1: float = ((c.x - g.x) * (a.y - g.y) - (a.x - g.x) * (c.y - g.y)) / area
			var l2: float = 1.0 - l0 - l1
			if l0 < -0.0001 or l1 < -0.0001 or l2 < -0.0001:
				continue
			var h: float = maxf(0.0, l0 * w[0].y + l1 * w[1].y + l2 * w[2].y)
			if not roof.is_empty() and h <= floor_h + 0.001:
				continue
			var shade: float = HubCast.shade_at(minf(h, cap) / top)
			var col: Color = img.get_pixel(x, y)
			if col.r > shade:
				img.set_pixel(x, y, Color(minf(col.r, shade), minf(col.g, shade), minf(col.b, shade), 1.0))
				wrote += 1
	return wrote
