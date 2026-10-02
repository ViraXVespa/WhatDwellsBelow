extends Object

## Origin and span are what the floor and wall shaders already sample. The RT is SUB 4 texels per tile.

const T := preload("res://scripts/data/tunables.gd")
const Stamp := preload("res://scripts/graphics/light_stamp.gd")
const Plan := preload("res://scripts/graphics/torch_plan.gd")
const HitchLog := preload("res://scripts/debug/hitch_log.gd")

const COL_TORCH := Color(1.0, 0.48, 0.16)
const COL_CRYSTAL := Color(0.35, 0.72, 1.0)
const COL_FIRE := Color(1.0, 0.40, 0.12)
const COL_SUN := Color(1.0, 0.78, 0.48)

const HUB_LIGHT_PATH := "res://assets/baked/hub_light.png"
const HUB_SUB := 16
static var tex: Texture2D
static var origin := Vector2.ZERO
static var span := Vector2.ONE
static var _gpu: ImageTexture
static var _mats: Array[ShaderMaterial] = []
static var _props: Array[Node] = []
static var _sites: Array[Dictionary] = []
static var _planned := false
static var _plan_partial := false
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
static var hub_crystal := Vector2.ZERO
static var _hub_layout: Node

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

static func _try_hub_baked() -> bool:
	var abs_path: String = ProjectSettings.globalize_path(HUB_LIGHT_PATH)
	if not FileAccess.file_exists(abs_path):
		return false
	var img := Image.new()
	if img.load(abs_path) != OK:
		return false
	if img.get_width() < 16 or img.get_height() < 16:
		return false
	_img = img
	_gpu = ImageTexture.create_from_image(img)
	tex = _gpu
	_push()
	return true

static func _hub_make_rt(x0: int, z0: int, tw: int, th: int) -> void:
	var n: int = HUB_SUB
	var iw: int = tw * n
	var ih: int = th * n
	var img: Image = Image.create(iw, ih, false, Image.FORMAT_RGBA8)
	img.fill(Color(0.98, 0.96, 0.93, 1.0))
	origin = Vector2(float(x0), float(z0))
	span = Vector2(float(tw), float(th))
	_img = img
	_gpu = ImageTexture.create_from_image(img)
	tex = _gpu
	_push()
	printerr("bake_camp: rt=%dx%d sub=%d tw=%d th=%d" % [iw, ih, n, tw, th])
static func rebuild_hub(x0: int, z0: int, x1: int, z1: int, crystal_xz: Vector2, layout: Node = null) -> void:
	_props.clear()
	_sites.clear()
	hub_crystal = crystal_xz
	_hub_layout = layout
	var tw: int = maxi(1, x1 - x0)
	var th: int = maxi(1, z1 - z0)
	origin = Vector2(float(x0), float(z0))
	span = Vector2(float(tw), float(th))
	_hub_make_rt(x0, z0, tw, th)
	_hub_finish_yard(x0, z0, layout)
static func rebind_tree(n: Node) -> void:
	if n == null:
		return
	if n is MeshInstance3D:
		var mi: MeshInstance3D = n
		if mi.material_override is ShaderMaterial:
			bind(mi.material_override)
	var i: int = 0
	while i < n.get_child_count():
		rebind_tree(n.get_child(i))
		i += 1

static func save_hub_bake() -> void:
	if _img == null:
		push_error("bake_camp: _img null")
		return
	var x0: int = int(origin.x)
	var z0: int = int(origin.y)
	_hub_fill_black(_img)
	_hub_paint_day(_img, x0, z0, _hub_layout)
	var nwrite: int = _hub_lock_shadows(_img, origin, _hub_layout)
	_blur_hub(_img)
	var abs_path: String = ProjectSettings.globalize_path(HUB_LIGHT_PATH)
	DirAccess.make_dir_recursive_absolute(abs_path.get_base_dir())
	_img.save_png(abs_path)
	printerr("bake_camp: shadow_px=%d %dx%d" % [nwrite, _img.get_width(), _img.get_height()])
static func prepare_hub(x0: int, z0: int, x1: int, z1: int, crystal_xz: Vector2, layout: Node = null) -> void:
	_props.clear()
	_sites.clear()
	_planned = false
	_plan_dirty = true
	_live = ""
	_knob = ""
	_rect = Rect2i(-1, -1, 0, 0)
	hub_crystal = crystal_xz
	_hub_layout = layout
	var tw: int = maxi(1, x1 - x0)
	var th: int = maxi(1, z1 - z0)
	origin = Vector2(float(x0), float(z0))
	span = Vector2(float(tw), float(th))
	if _try_hub_baked():
		return
	_hub_make_rt(x0, z0, tw, th)
	_hub_finish_yard(x0, z0, layout)
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

static func note_prop(node: Node) -> void:
	if node == null:
		return
	var kind: String = str(node.get("kind"))
	if kind != "crystal" and kind != "campfire":
		return
	if not App.in_dungeon:
		return
	if _props.has(node):
		return
	_props.append(node)
	_plan_dirty = true

static func drop_prop(node: Node) -> void:
	_props.erase(node)
	_plan_dirty = true

static func reset_floor() -> void:
	_props.clear()
	_sites.clear()
	_planned = false
	_plan_partial = false
	_plan_dirty = true
	_live = ""
	_knob = ""
	_rect = Rect2i(-1, -1, 0, 0)
static func maintain(host: Node) -> void:
	if host == null or host.get("data") == null:
		return
	var rect: Rect2i = _ring_rect(host)
	if rect.size.x < 1 or rect.size.y < 1:
		return
	var mode := ""
	if App.present:
		mode = str(App.present.get("_mode"))
	var entering: bool = mode == "enter_hold" or mode == "enter_fade" or _rect.size.x < 1
	var key: String = _knob_key()
	var live: String = _live_key(host)
	var need_plan: bool = _plan_dirty or not _planned or (_plan_partial and not entering)
	var need_torch: bool = live != _live
	var need_stamp: bool = key != _knob or rect != _rect
	if not need_plan and not need_stamp and not need_torch:
		return
	var LoadTiming: GDScript = load("res://scripts/debug/load_timing.gd") as GDScript
	if need_plan:
		_sites = Plan.build(host, _props, rect if entering else Rect2i())
		_plan_partial = entering
		HitchLog.mark("light_plan")
		if LoadTiming:
			LoadTiming.dnote("light_kind", "plan")
		_planned = true
		_plan_dirty = false
		return
	if need_stamp:
		HitchLog.mark("light_stamp")
		if LoadTiming:
			LoadTiming.dnote("light_kind", "stamp")
		_rect = rect
		_knob = key
		_publish_dungeon(host, rect)
		return
	HitchLog.mark("light_refill")
	if LoadTiming:
		LoadTiming.dnote("light_kind", "refill")
	_live = live
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
	var loops: Array = []
	if host.data.has("outline_loops") and host.data["outline_loops"] is Array:
		loops = host.data["outline_loops"]
	_publish(x0, z0, tw, th, lights, Stamp.COL_FLOOR, solid, sw, sh, n, loops)

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
	loops: Array = []
) -> void:
	var iw: int = tw * maxi(1, n)
	var ih: int = th * maxi(1, n)
	var img: Image = _img
	if img == null or img.get_width() != iw or img.get_height() != ih:
		img = Image.create(iw, ih, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 1))
	Stamp.paint(img, tw, th, lights, ambient, solid, sw, sh, n, x0, z0, loops)
	origin = Vector2(float(x0), float(z0))
	span = Vector2(float(tw), float(th))
	_img = img
	_solid = solid
	_sw = sw
	_sh = sh
	_sn = n
	_keep_casts(x0, z0, tw, th, lights)
	# hub lift skipped: warm fill flattened the yard RT
	if _gpu == null:
		_gpu = ImageTexture.create_from_image(img)
	else:
		_gpu.set_image(img)
	HitchLog.mark("light_gpu")
	tex = _gpu
	_push()
	HitchLog.mark("light_push")

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
		"kind": kind,
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
	var mode := ""
	if App.present:
		mode = str(App.present.get("_mode"))
	var entering: bool = mode == "enter_hold" or mode == "enter_fade" or _rect.size.x < 1
	var ring: int = int(stream.RING_IN) if entering else int(stream.RING_OUT)
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
	var hold: int = chunk
	if _rect.size.x >= chunk and _rect.size.y >= chunk:
		var hx0: int = _rect.position.x
		var hz0: int = _rect.position.y
		var hx1: int = hx0 + _rect.size.x
		var hz1: int = hz0 + _rect.size.y
		if entering:
			return _rect
		if pc.x >= hx0 + hold and pc.x < hx1 - hold and pc.y >= hz0 + hold and pc.y < hz1 - hold:
			return _rect
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
		if str(item.get("kind", "")) == "sun":
			continue
		_casts.append({
			"xz": Vector2(mx, mz),
			"reach": reach,
			"kind": str(item.get("kind", "")),
		})

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
static func _hub_paint_day(img: Image, x0: int, z0: int, _layout: Node) -> void:
	if img == null:
		return
	var away := Vector2(-0.406138, 0.913811)
	var an: float = away.length()
	var ax: float = away.x / maxf(an, 0.001)
	var az: float = away.y / maxf(an, 0.001)
	var tw: float = span.x
	var th: float = span.y
	var mid := Vector2(float(x0) + tw * 0.5, float(z0) + th * 0.5)
	var sub: float = float(HUB_SUB)
	var w: int = img.get_width()
	var h: int = img.get_height()
	var warm := Color(1.0, 0.82, 0.55)
	var y: int = 0
	while y < h:
		var x: int = 0
		while x < w:
			var wx: float = float(x0) + (float(x) + 0.5) / sub
			var wz: float = float(z0) + (float(y) + 0.5) / sub
			var along: float = (wx - mid.x) * ax + (wz - mid.y) * az
			var u: float = clampf(0.55 - along / 36.0, 0.0, 1.0)
			var c: Color = img.get_pixel(x, y)
			var k: float = 0.48 * u
			img.set_pixel(
				x,
				y,
				Color(c.r + (warm.r - c.r) * k, c.g + (warm.g - c.g) * k, c.b + (warm.b - c.b) * k, 1.0)
			)
			x += 1
		y += 1
	if hub_crystal.length() < 0.2:
		return
	var cr: float = 4.2
	var y2: int = 0
	while y2 < h:
		var x2: int = 0
		while x2 < w:
			var wx2: float = float(x0) + (float(x2) + 0.5) / sub
			var wz2: float = float(z0) + (float(y2) + 0.5) / sub
			var dc: float = Vector2(wx2 - hub_crystal.x, wz2 - hub_crystal.y).length()
			if dc < cr:
				var u2: float = 1.0 - dc / cr
				u2 = u2 * u2
				var c2: Color = img.get_pixel(x2, y2)
				var k2: float = 0.38 * u2
				img.set_pixel(
					x2,
					y2,
					Color(
						c2.r + (COL_CRYSTAL.r - c2.r) * k2,
						c2.g + (COL_CRYSTAL.g - c2.g) * k2,
						c2.b + (COL_CRYSTAL.b - c2.b) * k2,
						1.0
					)
				)
			x2 += 1
		y2 += 1
static func _hub_finish_yard(x0: int, z0: int, layout: Node) -> void:
	if _img == null:
		return
	_hub_fill_black(_img)
	_hub_paint_day(_img, x0, z0, layout)
	_hub_cast_buildings(_img, x0, z0, layout)
	_blur_hub(_img)
	if _gpu != null:
		_gpu.set_image(_img)
	tex = _gpu
	_push()
static func _hub_cast_buildings(img: Image, x0: int, z0: int, layout: Node) -> void:
	if img == null:
		return
	var away := Vector2(0.406138, 0.913811)
	var boxes: Array = _hub_yard_boxes(layout, false)
	var sub: float = float(HUB_SUB)
	var w: int = img.get_width()
	var h: int = img.get_height()
	var i: int = 0
	while i < boxes.size():
		var b: Dictionary = boxes[i]
		_hub_stamp_skirt(img, x0, z0, sub, w, h, b, away)
		i += 1
static func _hub_stamp_skirt(
	img: Image, x0: int, z0: int, sub: float, w: int, h: int, b: Dictionary, away: Vector2
) -> int:
	var reach: float = float(b["h"]) * 0.85
	var cx: float = float(b["x"])
	var cz: float = float(b["z"])
	var hx: float = float(b["hx"])
	var hz: float = float(b["hz"])
	var an: float = away.length()
	var ax: float = away.x / maxf(an, 0.001)
	var az: float = away.y / maxf(an, 0.001)
	var pad: float = reach + 0.45
	var px0: int = clampi(int(floor((cx - hx - pad - float(x0)) * sub)), 0, w - 1)
	var px1: int = clampi(int(ceil((cx + hx + pad - float(x0)) * sub)), 0, w)
	var pz0: int = clampi(int(floor((cz - hz - pad - float(z0)) * sub)), 0, h - 1)
	var pz1: int = clampi(int(ceil((cz + hz + pad - float(z0)) * sub)), 0, h)
	var kind: String = str(b.get("kind", ""))
	var wrote: int = 0
	var y: int = pz0
	while y < pz1:
		var x: int = px0
		while x < px1:
			var wx: float = float(x0) + (float(x) + 0.5) / sub
			var wz: float = float(z0) + (float(y) + 0.5) / sub
			var inside: bool = _hub_inside(wx, wz, b)
			if inside and kind != "tarp":
				x += 1
				continue
			var best: float = 1.0
			if inside and kind == "tarp":
				best = 0.8
			var step: int = 0
			while step < 20:
				var t: float = reach * float(step) / 19.0
				var sx: float = wx - ax * t
				var sz: float = wz - az * t
				var roof: float = _hub_roof_h(sx, sz, b)
				if roof > t / 0.85 + 0.03:
					var fade: float = clampf(t / maxf(reach, 0.001), 0.0, 1.0)
					var tip: float = clampf((fade - 0.62) / 0.38, 0.0, 1.0)
					best = minf(best, lerpf(0.46, 0.86, tip))
				step += 1
			if best > 0.96:
				x += 1
				continue
			var c: Color = img.get_pixel(x, y)
			img.set_pixel(x, y, Color(minf(c.r, best), minf(c.g, best), minf(c.b, best), 1.0))
			wrote += 1
			x += 1
		y += 1
	return wrote
static func _hub_yard_boxes(layout: Node, _bake: bool) -> Array:
	var boxes: Array = []
	if layout != null and layout.has_method("hall_pos"):
		var hp: Vector3 = layout.hall_pos()
		var hb: Vector3 = layout.hall_box
		boxes.append(_hub_gable(hp, hb))
		var wp: Vector3 = layout.wing_pos()
		var wb: Vector3 = layout.wing_box
		boxes.append(_hub_gable(wp, wb))
		var ad: float = 0.7
		if layout.get("hall_awning_depth") != null:
			ad = float(layout.hall_awning_depth)
		boxes.append(_hub_awning(hp, hb, ad))
		boxes.append(_hub_awning(wp, wb, ad))
		var sp: Vector3 = layout.stall_pos()
		var sb: Vector3 = layout.stall_box
		boxes.append(_hub_tarp(sp, sb))
		_hub_prop_blobs(layout, boxes)
		boxes.append(_hub_post(sp, sb, -1.0, -1.0))
		boxes.append(_hub_post(sp, sb, 1.0, -1.0))
		boxes.append(_hub_post(sp, sb, -1.0, 1.0))
		boxes.append(_hub_post(sp, sb, 1.0, 1.0))
	else:
		boxes.append(_hub_gable(Vector3(8.2, 0.0, 6.0), Vector3(5.6, 3.4, 4.2)))
		boxes.append(_hub_tarp(Vector3(25.0, 0.0, 8.0), Vector3(4.6, 2.4, 3.4)))
	return boxes
static func _hub_prop_blobs(layout: Node, boxes: Array) -> void:
	if layout == null:
		return
	var names: Array = ["anvil", "dumpster", "board", "notice", "crystal", "dummy", "vendor"]
	var i: int = 0
	while i < names.size():
		var meth: String = str(names[i]) + "_pos"
		if layout.has_method(meth):
			var p: Vector3 = layout.call(meth)
			boxes.append({
				"kind": "post",
				"x": p.x,
				"z": p.z,
				"hx": 0.34,
				"hz": 0.26,
				"eave": 0.65,
				"ridge": 0.65,
				"h": 0.85
			})
		i += 1
static func _hub_gable(pos: Vector3, box: Vector3) -> Dictionary:
	var eave: float = maxf(box.y, 1.2) * 0.78
	return {
		"kind": "gable",
		"x": pos.x,
		"z": pos.z,
		"hx": box.x * 0.5,
		"hz": box.z * 0.5,
		"eave": eave,
		"ridge": eave + 0.5,
		"h": eave + 0.5
	}
static func _hub_awning(pos: Vector3, box: Vector3, depth: float) -> Dictionary:
	var eave: float = maxf(box.y, 1.2) * 0.78
	var span: float = maxf(depth, 0.4)
	return {
		"kind": "awning",
		"x": pos.x,
		"z": pos.z + box.z * 0.5 + span * 0.5,
		"hx": box.x * 0.5,
		"hz": span * 0.5,
		"eave": eave,
		"hem": eave * 0.66,
		"h": eave * 0.7
	}
static func _hub_tarp(pos: Vector3, box: Vector3) -> Dictionary:
	return {
		"kind": "tarp",
		"x": pos.x,
		"z": pos.z,
		"hx": box.x * 0.5,
		"hz": box.z * 0.5,
		"eave": 1.05,
		"ridge": 1.7,
		"h": 1.7
	}

static func _hub_post(pos: Vector3, box: Vector3, sx: float, sz: float) -> Dictionary:
	return {
		"kind": "post",
		"x": pos.x + sx * box.x * 0.42,
		"z": pos.z + sz * box.z * 0.42,
		"hx": 0.1,
		"hz": 0.1,
		"eave": 1.05,
		"ridge": 1.05,
		"h": 1.05
	}
static func _hub_roof_h(wx: float, wz: float, b: Dictionary) -> float:
	var dx: float = absf(wx - float(b["x"])) - float(b["hx"])
	var dz: float = absf(wz - float(b["z"])) - float(b["hz"])
	if dx > 0.04 or dz > 0.04:
		return 0.0
	var kind: String = str(b.get("kind", "box"))
	if kind == "gable" or kind == "tarp":
		var along: float = absf(wz - float(b["z"])) / maxf(float(b["hz"]), 0.001)
		return lerpf(float(b["ridge"]), float(b["eave"]), clampf(along, 0.0, 1.0))
	if kind == "awning":
		var wall_z: float = float(b["z"]) - float(b["hz"])
		var along_s: float = (wz - wall_z) / maxf(float(b["hz"]) * 2.0, 0.001)
		return lerpf(float(b["eave"]), float(b["hem"]), clampf(along_s, 0.0, 1.0))
	return float(b.get("h", 1.0))
static func _hub_inside(wx: float, wz: float, b: Dictionary) -> bool:
	return absf(wx - float(b["x"])) <= float(b["hx"]) and absf(wz - float(b["z"])) <= float(b["hz"])

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
		var at: Vector3 = node.global_position
		if at.x < 1.0 or at.x > 33.0 or at.z < -2.0 or at.z > 26.0:
			printerr("sweep skip %s at=%s" % [node.get_path(), at])
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
	if node == null or node.mesh == null or not node.visible:
		return 0
	var mesh: Mesh = node.mesh
	var xf: Transform3D = node.global_transform
	var sub: float = float(HUB_SUB)
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
	var sub: float = float(HUB_SUB)
	var wrote: int = 0
	wrote += _hub_dark(img, int(org.x), int(org.y), sub, _hub_ground(p0, sun), _hub_ground(p1, sun), _hub_ground(p2, sun))
	wrote += _hub_dark(img, int(org.x), int(org.y), sub, _hub_ground(p0, sun), _hub_ground(p2, sun), _hub_ground(p3, sun))
	return wrote
