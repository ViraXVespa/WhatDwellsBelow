extends Object

## Rendered-pixel shadow contour check: building shadows must be the projected building polygons (hub_hulls.gd), straight
## edges stepped only at the ground cell. Buildings and sprites are hidden, the ground drawn with force_draw; along every
## outer hull edge (not inside another hull), points OFF cells inside and outside are compared on screen. Inside must be
## darker than outside by DIFF at >= OK of the points of each edge. plant "shift" moves the shader hulls 3 cells (the
## check keeps the true polygons), which must fail.

const Hulls := preload("res://scripts/graphics/light_rt/hub_hulls.gd")
const LightRt := preload("res://scripts/graphics/light_rt.gd")
const Chunky := preload("res://scripts/graphics/chunky.gd")
const OFF := 2.0  # ground cells each side of the edge
const DIFF := 0.06
const OK := 0.9
const STEP := 0.1  # metres between samples along an edge
const SHIFT := 3.0  # planted shift, cells
const MAX_POCKET := 0.02  # m2 of lit ground allowed inside one building's whole shadow

static var last := ""

static func run(plant: String = "") -> String:
	var tree: SceneTree = Engine.get_main_loop() as SceneTree
	var root: Node = tree.current_scene
	var cam: Camera3D = root.get_viewport().get_camera_3d()
	var hs: Array = Hulls.build(root)
	var g: float = Chunky.GRID_M
	Hulls.plant_shift = Vector2(SHIFT * g, SHIFT * g) if plant == "shift" else Vector2.ZERO
	Hulls.apply(root, LightRt._mats)
	var hid: Array = []
	var foot: Array = []  # building footprints: edges there are the wall base, under the building
	var y: float = 0.0
	for n in root.find_children("*", "VisualInstance3D", true, false):
		var v := n as VisualInstance3D
		if v.is_in_group("hub_ground"):
			y = maxf(y, v.global_position.y)
		elif v.visible and (v is MeshInstance3D or v is SpriteBase3D):
			var bb: AABB = v.global_transform * v.get_aabb()
			if v is MeshInstance3D and (v as MeshInstance3D).mesh is ArrayMesh and bb.size.y >= 0.2:
				foot.append(Rect2(bb.position.x, bb.position.z, bb.size.x, bb.size.z).grow(0.05))
			v.visible = false
			hid.append(v)
	RenderingServer.force_draw(false)
	var img: Image = root.get_viewport().get_texture().get_image()
	for v in hid:
		v.visible = true
	Hulls.plant_shift = Vector2.ZERO
	Hulls.apply(root, LightRt._mats)
	var bad: PackedStringArray = PackedStringArray()
	var edges := 0
	for hi in hs.size():
		var h: PackedVector2Array = hs[hi]
		for i in h.size():
			var a: Vector2 = h[i]
			var b: Vector2 = h[(i + 1) % h.size()]
			var len: float = a.distance_to(b)
			if len < 0.3:
				continue
			var nrm: Vector2 = -(b - a).normalized().orthogonal()  # positive-area hull: left of the edge is inside
			var tot := 0
			var good := 0
			for k in range(1, int(len / STEP)):
				var p: Vector2 = a.lerp(b, k * STEP / len)
				var pi: Vector2 = p + nrm * OFF * g
				var po: Vector2 = p - nrm * OFF * g
				if foot.any(func(r: Rect2) -> bool: return r.has_point(pi)):
					continue
				if _in_any(hs, po, hi) or _in_any(hs, pi, -1) == false:
					continue
				var si: Vector2 = cam.unproject_position(Vector3(pi.x, y, pi.y))
				var so: Vector2 = cam.unproject_position(Vector3(po.x, y, po.y))
				if cam.is_position_behind(Vector3(pi.x, y, pi.y)) or not _on(img, si) or not _on(img, so):
					continue
				tot += 1
				if img.get_pixelv(so).get_luminance() - img.get_pixelv(si).get_luminance() > DIFF:
					good += 1
			if tot < 4:
				continue
			edges += 1
			if float(good) / tot < OK:
				bad.append("h%d.e%d=%d/%d" % [hi, i, good, tot])
	var hole := Vector2.INF
	if plant == "gap":
		hole = Vector2.ZERO
		for v in hs[0]:
			hole += v / float((hs[0] as PackedVector2Array).size())
		hole += Vector2(0.0, 0.6)  # off the footprint, inside the cast
	var pk: PackedStringArray = pockets(hs, foot, hole)
	print("EDGE_POCKETS ", plant, " n=", pk.size(), " ", " ".join(pk.slice(0, 12)))
	if pk.size() * POCKET_M * POCKET_M > MAX_POCKET:
		bad.append("pockets=%d(%s)" % [pk.size(), pk[0]])
	last = "edges=%d bad=%d" % [edges, bad.size()]
	print("EDGE_PX ", plant, " ", last, " ", " ".join(bad))
	if edges == 0:
		return "no_edges"
	return " ".join(bad)

static func _on(img: Image, p: Vector2) -> bool:
	return p.x >= 0 and p.y >= 0 and p.x < img.get_width() and p.y < img.get_height()

## Inside any hull except `skip` (CCW: every cross >= 0).
static func _in_any(hs: Array, p: Vector2, skip: int) -> bool:
	for j in hs.size():
		if j == skip:
			continue
		var h: PackedVector2Array = hs[j]
		var inside := true
		for i in h.size():
			if (h[(i + 1) % h.size()] - h[i]).cross(p - h[i]) < 0.0:
				inside = false
				break
		if inside:
			return true
	return false

## Light pockets: sunlit ground cells (the shader's shade test, Hulls.sun_at on the bake; off every footprint) that cannot
## reach open ground without crossing shade: a hole inside a shadow, or a slot between a building base and its shadow
## or between adjacent buildings' shadows. plant "gap" opens a 0.2 m lit hole in the first building's cast. Flood fill on a POCKET_M grid over the hulls' bounds; rows "x,z:cells".
const POCKET_M := 0.05

static func pockets(hs: Array, foot: Array, hole := Vector2.INF) -> PackedStringArray:
	var r := Rect2((hs[0] as PackedVector2Array)[0], Vector2.ZERO)
	for h: PackedVector2Array in hs:
		for v in h:
			r = r.expand(v)
	r = r.grow(0.5)
	var w: int = int(r.size.x / POCKET_M)
	var d: int = int(r.size.y / POCKET_M)
	var lit := PackedByteArray()
	lit.resize(w * d)
	for j in d:
		for i in w:
			var q: Vector2 = r.position + Vector2(i + 0.5, j + 0.5) * POCKET_M
			var on := 1
			var c: Color = LightRt.sample_xz(q)
			if foot.any(func(f: Rect2) -> bool: return f.has_point(q)) or Hulls.sun_at(q, maxf(c.r, maxf(c.g, c.b))) == 0.0:
				on = 0
			if q.distance_to(hole) < 0.2:
				on = 1  # planted: a lit hole inside a shadow
			lit[j * w + i] = on
	var stack: Array[int] = []
	for i in w:
		stack.append(i)
		stack.append((d - 1) * w + i)
	for j in d:
		stack.append(j * w)
		stack.append(j * w + w - 1)
	while not stack.is_empty():
		var k: int = stack.pop_back()
		if lit[k] != 1:
			continue
		lit[k] = 2  # reaches open ground
		var x: int = k % w
		var z: int = k / w
		if x > 0: stack.append(k - 1)
		if x < w - 1: stack.append(k + 1)
		if z > 0: stack.append(k - w)
		if z < d - 1: stack.append(k + w)
	var out: PackedStringArray = PackedStringArray()
	for k in lit.size():
		if lit[k] == 1:
			out.append("%.2f,%.2f" % [r.position.x + (k % w + 0.5) * POCKET_M, r.position.y + (k / w + 0.5) * POCKET_M])
	return out
