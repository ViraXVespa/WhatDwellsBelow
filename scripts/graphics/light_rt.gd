extends Object

## Origin and span are what the floor and wall shaders already sample. The RT is SUB 4 texels per tile.

const T := preload("res://scripts/data/tunables.gd")
const Stamp := preload("res://scripts/graphics/light_stamp.gd")
const Plan := preload("res://scripts/graphics/torch_plan.gd")

const COL_TORCH := Color(1.0, 0.48, 0.16)
const COL_CRYSTAL := Color(0.35, 0.72, 1.0)
const COL_FIRE := Color(1.0, 0.40, 0.12)
const COL_SUN := Color(1.0, 0.86, 0.62)

static var tex: Texture2D
static var origin := Vector2.ZERO
static var span := Vector2.ONE
static var _gpu: ImageTexture
static var _mats: Array[ShaderMaterial] = []
static var _props: Array[Node] = []
static var _sites: Array[Dictionary] = []
static var _planned := false
static var _plan_dirty := true
static var _rect := Rect2i(-1, -1, 0, 0)
static var _live := ""
static var _knob := ""
static var _bill: GDScript
static var _img: Image
static var _solid: PackedByteArray = PackedByteArray()
static var _sw := 0
static var _sh := 0
static var _sn := 0
static var _casts: Array[Dictionary] = []


static func texture() -> Texture2D:
	if tex != null:
		return tex
	var img: Image = Image.create(1, 1, false, Image.FORMAT_RGBA8)
	img.fill(Color.WHITE)
	tex = ImageTexture.create_from_image(img)
	return tex


static func bind(mat: ShaderMaterial) -> void:
	if mat == null:
		return
	if tex == null:
		texture()
	mat.set_shader_parameter("light_tex", tex)
	mat.set_shader_parameter("light_origin", origin)
	mat.set_shader_parameter("light_span", span)
	if not _mats.has(mat):
		_mats.append(mat)


static func prepare_hub(x0: int, z0: int, x1: int, z1: int, crystal_xz: Vector2) -> void:
	_props.clear()
	_sites.clear()
	_planned = false
	_plan_dirty = true
	_live = ""
	_knob = ""
	_rect = Rect2i(-1, -1, 0, 0)
	var tw: int = maxi(1, x1 - x0)
	var th: int = maxi(1, z1 - z0)
	var lights: Array = []
	var sun: Vector2 = Vector2((float(x0) + float(x1)) * 0.5, (float(z0) + float(z1)) * 0.5)
	lights.append(_light_at(sun.x, sun.y, x0, z0, "sun"))
	lights.append(_light_at(crystal_xz.x, crystal_xz.y, x0, z0, "crystal"))
	_publish(x0, z0, tw, th, lights, Color(0, 0, 0, 1), PackedByteArray(), 0, 0, 0)


static func note_prop(node: Node) -> void:
	if node == null:
		return
	var kind: String = str(node.get("kind"))
	if kind != "crystal" and kind != "campfire":
		return
	if not App.in_dungeon:
		return
	if not _props.has(node):
		_props.append(node)
	_plan_dirty = true


static func drop_prop(node: Node) -> void:
	_props.erase(node)
	_plan_dirty = true


static func maintain(host: Node) -> void:
	if host == null or host.get("data") == null:
		return
	var rect: Rect2i = _ring_rect(host)
	if rect.size.x < 1 or rect.size.y < 1:
		return
	var key: String = _knob_key()
	var live: String = _live_key(host)
	var need_plan: bool = _plan_dirty or not _planned
	var need_torch: bool = need_plan or live != _live
	var need_stamp: bool = need_plan or key != _knob or rect != _rect
	if not need_stamp and not need_torch:
		return
	if need_plan:
		_sites = Plan.build(host, _props)
		_planned = true
		_plan_dirty = false
	if need_stamp:
		_rect = rect
		_knob = key
		_publish_dungeon(host, rect)
	_live = live
	if need_torch:
		_refill(host)


static func _publish_dungeon(host: Node, rect: Rect2i) -> void:
	var x0: int = rect.position.x
	var z0: int = rect.position.y
	var tw: int = rect.size.x
	var th: int = rect.size.y
	var solid: PackedByteArray = PackedByteArray()
	var sw: int = 0
	var sh: int = 0
	var n: int = 1
	if host.data.has("solid") and host.data["solid"] is PackedByteArray:
		solid = host.data["solid"]
		sw = int(host.data.get("solid_w", 0))
		sh = int(host.data.get("solid_h", 0))
		n = maxi(1, int(host.data.get("solid_n", 1)))
	var lights: Array = _dungeon_lights(host, x0, z0, tw, th)
	var spans: Array = []
	if host.data.has("outline_spans") and host.data["outline_spans"] is Array:
		spans = host.data["outline_spans"]
	_publish(x0, z0, tw, th, lights, Stamp.COL_FLOOR, solid, sw, sh, n, spans)


static func _publish(
	x0: int,
	z0: int,
	tw: int,
	th: int,
	lights: Array,
	ambient: Color,
	solid: PackedByteArray,
	sw: int,
	sh: int,
	n: int,
	spans: Array = []
) -> void:
	var img: Image = Image.create(tw * Stamp.SUB, th * Stamp.SUB, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 1))
	Stamp.paint(img, tw, th, lights, ambient, solid, sw, sh, n, x0, z0, spans)
	origin = Vector2(float(x0), float(z0))
	span = Vector2(float(tw), float(th))
	_img = img
	_solid = solid
	_sw = sw
	_sh = sh
	_sn = n
	_keep_casts(x0, z0, tw, th, lights)
	if _gpu == null:
		_gpu = ImageTexture.create_from_image(img)
	else:
		_gpu.set_image(img)
	tex = _gpu
	_push()


static func _dungeon_lights(host: Node, x0: int, z0: int, tw: int, th: int) -> Array:
	var focus: Vector2i = _focus(host)
	var cap: int = int(_bal("light_source_cap", T.LIGHT_SOURCE_CAP))
	var ranked: Array = []
	for node in _props:
		if not is_instance_valid(node):
			continue
		var kind: String = str(node.get("kind"))
		if kind != "crystal" and kind != "campfire":
			continue
		var cell: Vector2i = _node_cell(node)
		if not _inside(cell.x, cell.y, x0, z0, tw, th):
			continue
		var wx: float = float(cell.x) + 0.5
		var wz: float = float(cell.y) + 0.5
		if kind != "crystal":
			var body: Node3D = node as Node3D
			if body != null:
				wx = body.global_position.x
				wz = body.global_position.z
		var item: Dictionary = _light_at(wx, wz, x0, z0, kind)
		item["pri"] = 0
		item["dist"] = _dist(cell, focus)
		ranked.append(item)
	for raw_site in _sites:
		var site: Dictionary = raw_site as Dictionary
		var fx: int = int(site["fx"])
		var fz: int = int(site["fz"])
		if not _inside(fx, fz, x0, z0, tw, th):
			continue
		var lx: float = float(fx) + 0.5
		var lz: float = float(fz) + 0.5
		if site.has("lx"):
			lx = float(site["lx"])
		if site.has("lz"):
			lz = float(site["lz"])
		var torch: Dictionary = _light_at(lx, lz, x0, z0, "torch")
		torch["pri"] = 1
		torch["dist"] = _dist(Vector2i(fx, fz), focus)
		ranked.append(torch)
	var picked: Array = []
	var guard: int = 0
	while picked.size() < cap and guard < ranked.size() + 2:
		guard += 1
		var best_i: int = -1
		for i in ranked.size():
			if bool(ranked[i].get("used", false)):
				continue
			if best_i < 0 or _before(ranked[i], ranked[best_i]):
				best_i = i
		if best_i < 0:
			break
		ranked[best_i]["used"] = true
		picked.append(ranked[best_i])
	return picked


static func _before(a: Dictionary, b: Dictionary) -> bool:
	if int(a["pri"]) != int(b["pri"]):
		return int(a["pri"]) < int(b["pri"])
	return float(a["dist"]) < float(b["dist"])


static func _light_at(world_x: float, world_z: float, x0: int, z0: int, kind: String) -> Dictionary:
	return {
		"tx": int(floor(world_x)) - x0,
		"tz": int(floor(world_z)) - z0,
		"mx": world_x,
		"mz": world_z,
		"reach": _reach(kind),
		"energy": _energy(kind),
		"col": _color(kind),
	}


static func _reach(kind: String) -> float:
	if kind == "sun":
		return _bal("light_sun_range", T.LIGHT_SUN_RANGE)
	if kind == "crystal":
		return _bal("light_crystal_range", T.LIGHT_CRYSTAL_RANGE)
	if kind == "campfire":
		return _bal("light_fire_range", T.LIGHT_FIRE_RANGE)
	return _bal("light_torch_range", T.LIGHT_TORCH_RANGE)


static func _energy(kind: String) -> float:
	if kind == "sun":
		return _bal("light_sun_energy", T.LIGHT_SUN_ENERGY)
	if kind == "crystal":
		return _bal("light_crystal_energy", T.LIGHT_CRYSTAL_ENERGY)
	if kind == "campfire":
		return _bal("light_fire_energy", T.LIGHT_FIRE_ENERGY)
	return _bal("light_torch_energy", T.LIGHT_TORCH_ENERGY)


static func _color(kind: String) -> Color:
	if kind == "sun":
		return COL_SUN
	if kind == "crystal":
		return COL_CRYSTAL
	if kind == "campfire":
		return COL_FIRE
	return COL_TORCH


static func _bal(key: String, fallback: float) -> float:
	if App.bal == null:
		return fallback
	var v: float = App.bal.getv(key)
	if v <= 0.0:
		return fallback
	return v


static func _knob_key() -> String:
	return "%s|%s|%s|%s|%s|%s|%s|%s|%s" % [
		_bal("light_torch_range", T.LIGHT_TORCH_RANGE),
		_bal("light_torch_energy", T.LIGHT_TORCH_ENERGY),
		_bal("light_crystal_range", T.LIGHT_CRYSTAL_RANGE),
		_bal("light_crystal_energy", T.LIGHT_CRYSTAL_ENERGY),
		_bal("light_fire_range", T.LIGHT_FIRE_RANGE),
		_bal("light_fire_energy", T.LIGHT_FIRE_ENERGY),
		_bal("light_sun_range", T.LIGHT_SUN_RANGE),
		_bal("light_sun_energy", T.LIGHT_SUN_ENERGY),
		_bal("light_source_cap", T.LIGHT_SOURCE_CAP),
	]


static func _ring_rect(host: Node) -> Rect2i:
	var stream: GDScript = load("res://scripts/world/dungeon_geo_stream.gd") as GDScript
	var pc: Vector2i = _focus(host)
	var origin_cell: Vector2i = stream.chunk_origin(pc)
	var ring: int = int(stream.RING_OUT)
	var chunk: int = int(stream.CHUNK)
	var map_w: int = int(host.data.w)
	var map_h: int = int(host.data.h)
	var x0: int = origin_cell.x - ring * chunk
	var z0: int = origin_cell.y - ring * chunk
	var x1: int = origin_cell.x + (ring + 1) * chunk
	var z1: int = origin_cell.y + (ring + 1) * chunk
	x0 = clampi(x0, 0, maxi(0, map_w - 1))
	z0 = clampi(z0, 0, maxi(0, map_h - 1))
	x1 = clampi(x1, x0 + 1, map_w)
	z1 = clampi(z1, z0 + 1, map_h)
	return Rect2i(x0, z0, x1 - x0, z1 - z0)


static func _focus(host: Node) -> Vector2i:
	if host.player != null:
		return host._player_cell()
	var sp: Variant = host.data.get("spawn", Vector2i.ZERO)
	if sp is Vector2i:
		return sp
	return Vector2i.ZERO


static func _live_key(host: Node) -> String:
	var parts: PackedStringArray = PackedStringArray()
	for job in host.geo_jobs:
		if str(job.state) != "live":
			continue
		var o: Vector2i = job.origin
		parts.append("%d,%d" % [o.x, o.y])
	return "|".join(parts)


static func _refill(host: Node) -> void:
	if _bill == null:
		_bill = load("res://scripts/graphics/torch_bill.gd") as GDScript
	var stream: GDScript = load("res://scripts/world/dungeon_geo_stream.gd") as GDScript
	_bill.refill(host, _sites, int(stream.CHUNK))


static func _node_cell(node: Node) -> Vector2i:
	if str(node.get("kind")) == "crystal":
		var raw: Variant = node.get("crystal_cell")
		if raw is Vector2i:
			return raw
	var body: Node3D = node as Node3D
	return Vector2i(int(round(body.global_position.x - 0.5)), int(round(body.global_position.z - 0.5)))


static func _inside(x: int, z: int, x0: int, z0: int, tw: int, th: int) -> bool:
	return x >= x0 and z >= z0 and x < x0 + tw and z < z0 + th


static func _dist(cell: Vector2i, focus: Vector2i) -> float:
	var dx: float = float(cell.x - focus.x)
	var dz: float = float(cell.y - focus.y)
	return sqrt(dx * dx + dz * dz)


static func _push() -> void:
	var keep: Array[ShaderMaterial] = []
	for mat in _mats:
		if mat == null or not is_instance_valid(mat):
			continue
		mat.set_shader_parameter("light_tex", tex)
		mat.set_shader_parameter("light_origin", origin)
		mat.set_shader_parameter("light_span", span)
		keep.append(mat)
	_mats = keep


static func sample_xz(world: Vector2) -> Color:
	# Same luv as the floor and wall shaders. Bilinear across texels.
	if _img == null:
		return Color.WHITE
	var sp: Vector2 = span
	if sp.x < 0.001 or sp.y < 0.001:
		return Color.WHITE
	var w: int = _img.get_width()
	var h: int = _img.get_height()
	if w < 1 or h < 1:
		return Color.WHITE
	var luv: Vector2 = (world - origin) / sp
	var u: float = clampf(luv.x, 0.0, 1.0)
	var v: float = clampf(luv.y, 0.0, 1.0)
	var max_x: float = maxf(float(w) - 1.0001, 0.0)
	var max_y: float = maxf(float(h) - 1.0001, 0.0)
	var px: float = clampf(u * float(w) - 0.5, 0.0, max_x)
	var py: float = clampf(v * float(h) - 0.5, 0.0, max_y)
	var x0: int = int(floor(px))
	var y0: int = int(floor(py))
	var x1: int = mini(x0 + 1, w - 1)
	var y1: int = mini(y0 + 1, h - 1)
	var fx: float = px - float(x0)
	var fy: float = py - float(y0)
	var c00: Color = _img.get_pixel(x0, y0)
	var c10: Color = _img.get_pixel(x1, y0)
	var c01: Color = _img.get_pixel(x0, y1)
	var c11: Color = _img.get_pixel(x1, y1)
	return c00.lerp(c10, fx).lerp(c01.lerp(c11, fx), fy)


static func floor_open(world: Vector2) -> bool:
	if _img == null:
		return false
	var sp: Vector2 = span
	if sp.x < 0.001 or sp.y < 0.001:
		return false
	if world.x < origin.x or world.y < origin.y:
		return false
	if world.x >= origin.x + sp.x or world.y >= origin.y + sp.y:
		return false
	if _sn < 1 or _solid.is_empty():
		return true
	return Stamp.solid_open(_solid, _sw, _sh, _sn, world.x, world.y)


static func nearest_cast(world: Vector2) -> Dictionary:
	var found := false
	var best := Vector2.ZERO
	var best_d := 0.0
	var best_r := 0.0
	for src in _casts:
		var item: Dictionary = src
		var xz: Vector2 = item["xz"]
		var reach: float = float(item["reach"])
		var dist: float = world.distance_to(xz)
		if dist > reach:
			continue
		if found and dist >= best_d:
			continue
		found = true
		best = xz
		best_d = dist
		best_r = reach
	return {"ok": found, "xz": best, "dist": best_d, "reach": best_r}


static func nearest_casts(world: Vector2, cap: int = 3) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var limit: int = cap
	if limit < 1:
		return out
	for src in _casts:
		var item: Dictionary = src
		var xz: Vector2 = item["xz"]
		var reach: float = float(item["reach"])
		var dist: float = world.distance_to(xz)
		if dist > reach:
			continue
		var row: Dictionary = {"ok": true, "xz": xz, "dist": dist, "reach": reach}
		var at: int = out.size()
		for i in out.size():
			var prev: Dictionary = out[i]
			if dist < float(prev["dist"]):
				at = i
				break
		if at >= limit:
			continue
		out.insert(at, row)
		if out.size() > limit:
			out.resize(limit)
	return out


static func _keep_casts(x0: int, z0: int, tw: int, th: int, lights: Array) -> void:
	_casts.clear()
	var x1: float = float(x0 + tw)
	var z1: float = float(z0 + th)
	for src in lights:
		var item: Dictionary = src
		var mx: float = float(item["mx"])
		var mz: float = float(item["mz"])
		if mx < float(x0) or mz < float(z0) or mx >= x1 or mz >= z1:
			continue
		if not Stamp.near_open(_solid, _sw, _sh, _sn, mx, mz):
			continue
		var reach: float = float(item["reach"])
		if reach < 0.25:
			continue
		_casts.append({
			"xz": Vector2(mx, mz),
			"reach": reach,
		})
