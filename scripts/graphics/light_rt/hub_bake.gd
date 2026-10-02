extends Object

## Hub light RT build and bake. State stays on light_rt.gd.

const HubCast := preload("res://scripts/graphics/light_rt/hub_cast.gd")
const HubShadow := preload("res://scripts/graphics/light_rt/hub_shadow.gd")
const RT_PATH := "res://scripts/graphics/light_rt.gd"

static func _try_hub_baked() -> bool:
	var rt: Variant = load(RT_PATH)
	var abs_path: String = ProjectSettings.globalize_path(rt.HUB_LIGHT_PATH)
	if not FileAccess.file_exists(abs_path):
		return false
	var img := Image.new()
	if img.load(abs_path) != OK:
		return false
	if img.get_width() < 16 or img.get_height() < 16:
		return false
	rt._img = img
	rt._gpu = ImageTexture.create_from_image(img)
	rt.tex = rt._gpu
	rt._push()
	return true

static func _hub_make_rt(x0: int, z0: int, tw: int, th: int) -> void:
	var rt: Variant = load(RT_PATH)
	var n: int = rt.HUB_SUB
	var iw: int = tw * n
	var ih: int = th * n
	var img: Image = Image.create(iw, ih, false, Image.FORMAT_RGBA8)
	img.fill(Color(0.98, 0.96, 0.93, 1.0))
	rt.origin = Vector2(float(x0), float(z0))
	rt.span = Vector2(float(tw), float(th))
	rt._img = img
	rt._gpu = ImageTexture.create_from_image(img)
	rt.tex = rt._gpu
	rt._push()
	printerr("bake_camp: rt=%dx%d sub=%d tw=%d th=%d" % [iw, ih, n, tw, th])
static func rebuild_hub(x0: int, z0: int, x1: int, z1: int, crystal_xz: Vector2, layout: Node = null) -> void:
	var rt: Variant = load(RT_PATH)
	rt._props.clear()
	rt._sites.clear()
	rt.hub_crystal = crystal_xz
	rt._hub_layout = layout
	var tw: int = maxi(1, x1 - x0)
	var th: int = maxi(1, z1 - z0)
	rt.origin = Vector2(float(x0), float(z0))
	rt.span = Vector2(float(tw), float(th))
	_hub_make_rt(x0, z0, tw, th)
	_hub_finish_yard(x0, z0, layout)
static func save_hub_bake() -> void:
	var rt: Variant = load(RT_PATH)
	if rt._img == null:
		push_error("bake_camp: rt._img null")
		return
	var x0: int = int(rt.origin.x)
	var z0: int = int(rt.origin.y)
	HubShadow._hub_fill_black(rt._img)
	_hub_paint_day(rt._img, x0, z0, rt._hub_layout)
	var nwrite: int = HubShadow._hub_lock_shadows(rt._img, rt.origin, rt._hub_layout)
	HubShadow._blur_hub(rt._img)
	var abs_path: String = ProjectSettings.globalize_path(rt.HUB_LIGHT_PATH)
	DirAccess.make_dir_recursive_absolute(abs_path.get_base_dir())
	rt._img.save_png(abs_path)
	printerr("bake_camp: shadow_px=%d %dx%d" % [nwrite, rt._img.get_width(), rt._img.get_height()])
static func prepare_hub(x0: int, z0: int, x1: int, z1: int, crystal_xz: Vector2, layout: Node = null) -> void:
	var rt: Variant = load(RT_PATH)
	rt._props.clear()
	rt._sites.clear()
	rt._planned = false
	rt._plan_dirty = true
	rt._live = ""
	rt._knob = ""
	rt._rect = Rect2i(-1, -1, 0, 0)
	rt.hub_crystal = crystal_xz
	rt._hub_layout = layout
	var tw: int = maxi(1, x1 - x0)
	var th: int = maxi(1, z1 - z0)
	rt.origin = Vector2(float(x0), float(z0))
	rt.span = Vector2(float(tw), float(th))
	if _try_hub_baked():
		return
	_hub_make_rt(x0, z0, tw, th)
	_hub_finish_yard(x0, z0, layout)
static func _hub_paint_day(img: Image, x0: int, z0: int, _layout: Node) -> void:
	var rt: Variant = load(RT_PATH)
	if img == null:
		return
	var away := Vector2(-0.406138, 0.913811)
	var an: float = away.length()
	var ax: float = away.x / maxf(an, 0.001)
	var az: float = away.y / maxf(an, 0.001)
	var tw: float = rt.span.x
	var th: float = rt.span.y
	var mid := Vector2(float(x0) + tw * 0.5, float(z0) + th * 0.5)
	var sub: float = float(rt.HUB_SUB)
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
	if rt.hub_crystal.length() < 0.2:
		return
	var cr: float = 4.2
	var y2: int = 0
	while y2 < h:
		var x2: int = 0
		while x2 < w:
			var wx2: float = float(x0) + (float(x2) + 0.5) / sub
			var wz2: float = float(z0) + (float(y2) + 0.5) / sub
			var dc: float = Vector2(wx2 - rt.hub_crystal.x, wz2 - rt.hub_crystal.y).length()
			if dc < cr:
				var u2: float = 1.0 - dc / cr
				u2 = u2 * u2
				var c2: Color = img.get_pixel(x2, y2)
				var k2: float = 0.38 * u2
				img.set_pixel(
					x2,
					y2,
					Color(
						c2.r + (rt.COL_CRYSTAL.r - c2.r) * k2,
						c2.g + (rt.COL_CRYSTAL.g - c2.g) * k2,
						c2.b + (rt.COL_CRYSTAL.b - c2.b) * k2,
						1.0
					)
				)
			x2 += 1
		y2 += 1
static func _hub_finish_yard(x0: int, z0: int, layout: Node) -> void:
	var rt: Variant = load(RT_PATH)
	if rt._img == null:
		return
	HubShadow._hub_fill_black(rt._img)
	_hub_paint_day(rt._img, x0, z0, layout)
	HubCast._hub_cast_buildings(rt._img, x0, z0, layout)
	HubShadow._blur_hub(rt._img)
	if rt._gpu != null:
		rt._gpu.set_image(rt._img)
	rt.tex = rt._gpu
	rt._push()
