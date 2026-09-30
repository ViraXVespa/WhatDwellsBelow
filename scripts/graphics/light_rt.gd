extends Object

## Origin and span are what the floor and wall shaders already sample. The RT is SUB 4 texels per tile.

const T := preload("res://scripts/data/tunables.gd")
const Stamp := preload("res://scripts/graphics/light_stamp.gd")
const Plan := preload("res://scripts/graphics/torch_plan.gd")
const HitchLog := preload("res://scripts/debug/hitch_log.gd")

const COL_TORCH := Color(1.0, 0.48, 0.16)
const COL_CRYSTAL := Color(0.35, 0.72, 1.0)
const COL_FIRE := Color(1.0, 0.40, 0.12)
const COL_SUN := Color(1.0, 0.86, 0.62)

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
static func _hub_occ(_x0: int, _z0: int, tw: int, th: int, layout: Node) -> Dictionary:
	var n: int = HUB_SUB
	var sw: int = tw * n
	var sh: int = th * n
	var solid := PackedByteArray()
	solid.resize(sw * sh)
	solid.fill(1)
	if layout == null:
		return {"solid": solid, "sw": sw, "sh": sh}
	var boxes: Array = []
	if layout.has_method("hall_pos"):
		boxes.append({"pos": layout.hall_pos(), "box": layout.hall_box})
		boxes.append({"pos": layout.wing_pos(), "box": layout.wing_box})
		boxes.append({"pos": layout.stall_pos(), "box": layout.stall_box})
	for raw in boxes:
		var item: Dictionary = raw
		var p: Vector3 = item["pos"]
		var b: Vector3 = item["box"]
		var x_a: float = p.x - b.x * 0.5
		var x_b: float = p.x + b.x * 0.5
		var z_a: float = p.z - b.z * 0.5
		var z_b: float = p.z + b.z * 0.5
		var fx0: int = clampi(int(floor((x_a - float(_x0)) * float(n))), 0, sw - 1)
		var fx1: int = clampi(int(ceil((x_b - float(_x0)) * float(n))), 0, sw)
		var fz0: int = clampi(int(floor((z_a - float(_z0)) * float(n))), 0, sh - 1)
		var fz1: int = clampi(int(ceil((z_b - float(_z0)) * float(n))), 0, sh)
		var fz: int = fz0
		while fz < fz1:
			var row: int = fz * sw
			var fx: int = fx0
			while fx < fx1:
				solid[row + fx] = 0
				fx += 1
			fz += 1
	return {"solid": solid, "sw": sw, "sh": sh}
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


static func _hub_day_finish(img: Image, x0: int, z0: int, layout: Node) -> void:
	if img == null:
		return
	var amb := Color(0.82, 0.74, 0.60, 1.0)
	var w: int = img.get_width()
	var h: int = img.get_height()
	var sub: float = float(img.get_width()) / maxf(span.x, 1.0)
	var boxes: Array = []
	if layout != null and layout.has_method("hall_pos"):
		boxes.append({"pos": layout.hall_pos(), "box": layout.hall_box})
		boxes.append({"pos": layout.wing_pos(), "box": layout.wing_box})
		boxes.append({"pos": layout.stall_pos(), "box": layout.stall_box})
	var away := Vector2(0.406138, 0.913811)
	var y: int = 0
	while y < h:
		var x: int = 0
		while x < w:
			var c: Color = img.get_pixel(x, y)
			if c.r + c.g + c.b < 0.12:
				c = amb
			else:
				c = Color(maxf(c.r, amb.r * 0.85), maxf(c.g, amb.g * 0.85), maxf(c.b, amb.b * 0.85), 1.0)
			var wx: float = float(x0) + (float(x) + 0.5) / sub
			var wz: float = float(z0) + (float(y) + 0.5) / sub
			if _hub_in_sun_shade(wx, wz, boxes, away):
				c = Color(c.r * 0.62, c.g * 0.60, c.b * 0.58, 1.0)
			img.set_pixel(x, y, c)
			x += 1
		y += 1

static func _hub_in_sun_shade(wx: float, wz: float, boxes: Array, away: Vector2) -> bool:
	if _hub_in_boxes(wx, wz, boxes):
		return false
	var t: float = 0.15
	while t <= 3.6:
		var px: float = wx - away.x * t
		var pz: float = wz - away.y * t
		if _hub_in_boxes(px, pz, boxes):
			return true
		t += 0.15
	return false

static func _hub_in_boxes(wx: float, wz: float, boxes: Array) -> bool:
	for raw in boxes:
		var item: Dictionary = raw
		var p: Vector3 = item["pos"]
		var b: Vector3 = item["box"]
		if absf(wx - p.x) <= b.x * 0.5 and absf(wz - p.z) <= b.z * 0.5:
			return true
	return false

static func _hub_lift_dark(img: Image) -> void:
	if img == null:
		return
	var amb := Color(0.86, 0.78, 0.64, 1.0)
	var w: int = img.get_width()
	var h: int = img.get_height()
	var y: int = 0
	while y < h:
		var x: int = 0
		while x < w:
			var c: Color = img.get_pixel(x, y)
			if c.r < amb.r or c.g < amb.g or c.b < amb.b:
				img.set_pixel(x, y, Color(maxf(c.r, amb.r), maxf(c.g, amb.g), maxf(c.b, amb.b), 1.0))
			x += 1
		y += 1

static func _hub_building_shade(img: Image, x0: int, z0: int, layout: Node) -> void:
	if img == null or layout == null or not layout.has_method("hall_pos"):
		return
	var away := Vector2(0.406138, 0.913811)
	var boxes: Array = [
		{"pos": layout.hall_pos(), "box": layout.hall_box, "len": 3.4},
		{"pos": layout.wing_pos(), "box": layout.wing_box, "len": 2.6},
		{"pos": layout.stall_pos(), "box": layout.stall_box, "len": 2.2},
	]
	if layout.get("hall_awning_depth") != null:
		var hp: Vector3 = layout.hall_pos()
		var hb: Vector3 = layout.hall_box
		var ad: float = float(layout.hall_awning_depth)
		boxes.append({"pos": Vector3(hp.x, 0.0, hp.z + hb.z * 0.5 + ad * 0.5), "box": Vector3(hb.x, 1.0, ad), "len": 1.4})
		var wp: Vector3 = layout.wing_pos()
		var wb: Vector3 = layout.wing_box
		var wad: float = float(layout.wing_awning_depth)
		boxes.append({"pos": Vector3(wp.x, 0.0, wp.z + wb.z * 0.5 + wad * 0.5), "box": Vector3(wb.x, 1.0, wad), "len": 1.2})
	var w: int = img.get_width()
	var h: int = img.get_height()
	var sub: float = float(HUB_SUB)
	var y: int = 0
	while y < h:
		var x: int = 0
		while x < w:
			var wx: float = float(x0) + (float(x) + 0.5) / sub
			var wz: float = float(z0) + (float(y) + 0.5) / sub
			if _hub_box_hit(wx, wz, boxes):
				x += 1
				continue
			var cover: float = _hub_shade_cover(wx, wz, boxes, away)
			if cover > 0.0:
				var c: Color = img.get_pixel(x, y)
				var k: float = lerpf(1.0, 0.58, cover)
				img.set_pixel(x, y, Color(c.r * k, c.g * k * 0.98, c.b * k * 0.96, 1.0))
			x += 1
		y += 1

static func _hub_box_hit(wx: float, wz: float, boxes: Array) -> bool:
	for raw in boxes:
		var item: Dictionary = raw
		var p: Vector3 = item["pos"]
		var b: Vector3 = item["box"]
		if absf(wx - p.x) <= b.x * 0.5 and absf(wz - p.z) <= b.z * 0.5:
			return true
	return false

static func _hub_shade_cover(wx: float, wz: float, boxes: Array, away: Vector2) -> float:
	var best: float = 0.0
	for raw in boxes:
		var item: Dictionary = raw
		var slen: float = float(item["len"])
		var t: float = 0.12
		while t <= slen:
			var px: float = wx - away.x * t
			var pz: float = wz - away.y * t
			if _hub_box_hit(px, pz, [item]):
				best = maxf(best, 1.0 - t / slen)
				break
			t += 0.12
	return best

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
static func _hub_paint_day(img: Image, x0: int, z0: int, layout: Node) -> void:
	if img == null:
		return
	var away := Vector2(0.406138, 0.913811)
	var tw: float = span.x
	var th: float = span.y
	var mid := Vector2(float(x0) + tw * 0.5, float(z0) + th * 0.5)
	var sun: Vector2 = mid - away * 80.0
	sun.x = clampf(sun.x, float(x0) + 0.6, float(x0) + tw - 0.6)
	sun.y = clampf(sun.y, float(z0) + 0.6, float(z0) + th - 0.6)
	var reach: float = maxf(96.0, Vector2(tw, th).length())
	var boxes: Array = _hub_yard_boxes(layout, false)
	var sub: float = float(HUB_SUB)
	var w: int = img.get_width()
	var h: int = img.get_height()
	var y: int = 0
	while y < h:
		var x: int = 0
		while x < w:
			var wx: float = float(x0) + (float(x) + 0.5) / sub
			var wz: float = float(z0) + (float(y) + 0.5) / sub
			var blocked := false
			var bi: int = 0
			while bi < boxes.size():
				var b: Dictionary = boxes[bi]
				if _hub_inside(wx, wz, b):
					blocked = true
					break
				bi += 1
			if blocked:
				x += 1
				continue
			var d: float = Vector2(wx - sun.x, wz - sun.y).length()
			var u: float = clampf(1.0 - d / reach, 0.0, 1.0)
			u = u * u
			var c: Color = img.get_pixel(x, y)
			var k: float = 0.30 * u
			img.set_pixel(
				x,
				y,
				Color(c.r + (COL_SUN.r - c.r) * k, c.g + (COL_SUN.g - c.g) * k, c.b + (COL_SUN.b - c.b) * k, 1.0)
			)
			x += 1
		y += 1
	if hub_crystal.length() < 0.2:
		return
	var cr: float = 3.2
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
				var k2: float = 0.34 * u2
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
	var slen: float = maxf(float(b["len"]), 0.5)
	var cx: float = float(b["x"])
	var cz: float = float(b["z"])
	var hx: float = float(b["hx"])
	var hz: float = float(b["hz"])
	var rad: float = 0.42
	var pad: float = slen + rad + 0.35
	var px0: int = clampi(int(floor((cx - hx - pad - float(x0)) * sub)), 0, w - 1)
	var px1: int = clampi(int(ceil((cx + hx + pad - float(x0)) * sub)), 0, w)
	var pz0: int = clampi(int(floor((cz - hz - pad - float(z0)) * sub)), 0, h - 1)
	var pz1: int = clampi(int(ceil((cz + hz + pad - float(z0)) * sub)), 0, h)
	var wrote: int = 0
	var y: int = pz0
	while y < pz1:
		var x: int = px0
		while x < px1:
			var wx: float = float(x0) + (float(x) + 0.5) / sub
			var wz: float = float(z0) + (float(y) + 0.5) / sub
			if _hub_inside(wx, wz, b):
				x += 1
				continue
			var px: float = wx - cx
			var pz: float = wz - cz
			var qx: float = absf(px) - maxf(hx - rad, 0.08)
			var qz: float = absf(pz) - maxf(hz - rad, 0.08)
			var sdf: float = Vector2(maxf(qx, 0.0), maxf(qz, 0.0)).length()
			sdf += minf(maxf(qx, qz), 0.0)
			sdf -= rad
			if sdf <= 0.0:
				x += 1
				continue
			var side: float = px * away.x + pz * away.y
			var reach: float = slen
			if side < 0.1:
				reach = 0.2
			if sdf > reach:
				x += 1
				continue
			var t: float = clampf(sdf / maxf(reach, 0.2), 0.0, 1.0)
			var s: float = t * t * (3.0 - 2.0 * t)
			var k: float = lerpf(0.50, 1.0, s)
			if side < 0.1:
				k = lerpf(0.88, 1.0, s)
			if k >= 0.995:
				x += 1
				continue
			var c: Color = img.get_pixel(x, y)
			img.set_pixel(x, y, Color(c.r * k, c.g * k, c.b * k, 1.0))
			wrote += 1
			x += 1
		y += 1
	return wrote
static func _hub_roof_box(pos: Vector3, box: Vector3, eave: float, slen: float) -> Dictionary:
	return {
		"x": pos.x,
		"z": pos.z + eave * 0.35,
		"hx": box.x * 0.5 + 0.08,
		"hz": box.z * 0.5 + eave + 0.35,
		"len": slen
	}
static func _hub_yard_boxes(layout: Node, bake: bool) -> Array:
	var hall_len: float = 4.6 if bake else 4.4
	var wing_len: float = 3.9 if bake else 3.6
	var stall_len: float = 2.5 if bake else 2.4
	var boxes: Array = []
	if layout != null and layout.has_method("hall_pos"):
		boxes.append(_hub_box_of(layout.hall_pos(), layout.hall_box, hall_len))
		boxes.append(_hub_box_of(layout.wing_pos(), layout.wing_box, wing_len))
		boxes.append(_hub_box_of(layout.stall_pos(), layout.stall_box, stall_len))
	else:
		boxes.append(_hub_box_of(Vector3(8.2, 0.0, 6.0), Vector3(5.6, 3.4, 4.2), hall_len))
		boxes.append(_hub_box_of(Vector3(25.0, 0.0, 8.0), Vector3(4.6, 2.4, 3.4), stall_len))
	return boxes
static func _hub_box_of(pos: Vector3, box: Vector3, slen: float) -> Dictionary:
	return {"x": pos.x, "z": pos.z, "hx": box.x * 0.5 + 0.06, "hz": box.z * 0.5 + 0.06, "len": slen}

static func _hub_inside(wx: float, wz: float, b: Dictionary) -> bool:
	return absf(wx - float(b["x"])) <= float(b["hx"]) and absf(wz - float(b["z"])) <= float(b["hz"])


static func _hub_lock_shadows(img: Image, org: Vector2, layout: Node) -> int:
	var boxes: Array = _hub_yard_boxes(layout, true)
	printerr("bake_camp: boxes=%d" % boxes.size())
	var away := Vector2(0.406138, 0.913811)
	var sub: float = float(HUB_SUB)
	var wrote: int = 0
	var x0: int = int(org.x)
	var z0: int = int(org.y)
	var w: int = img.get_width()
	var h: int = img.get_height()
	var bi: int = 0
	while bi < boxes.size():
		var b: Dictionary = boxes[bi]
		wrote += _hub_stamp_skirt(img, x0, z0, sub, w, h, b, away)
		bi += 1
	return wrote
static func _hub_stamp_lock_box(
	img: Image, org: Vector2, sub: float, w: int, h: int, b: Dictionary, away: Vector2
) -> int:
	return _hub_stamp_skirt(img, int(org.x), int(org.y), sub, w, h, b, away)
