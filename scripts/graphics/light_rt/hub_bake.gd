extends Object

## Hub light RT build and bake. State stays on light_rt.gd.

const HubCast := preload("res://scripts/graphics/light_rt/hub_cast.gd")
const HubShadow := preload("res://scripts/graphics/light_rt/hub_shadow.gd")
const LoadTiming := preload("res://scripts/debug/load_timing.gd")
const RT_PATH := "res://scripts/graphics/light_rt.gd"
const HUB_FIELD := Color(0.98, 0.96, 0.93, 1.0)
## Bake stamp: hub_light.png loads (disk or export) only when its pixels hash to this. "" or any mismatch means
## the yard is computed at runtime. Rebake with tools/run_bake_camp.py, review the shots, paste its `stamp=` here.
const HUB_BAKE_STAMP := ""

## The PNG on disk when it exists (dev runs); otherwise the imported copy inside an export (web, packed desktop).
static func _baked_image(path: String) -> Image:
	var abs_path: String = ProjectSettings.globalize_path(path)
	var src: Image = null
	if FileAccess.file_exists(abs_path):
		src = Image.new()
		if src.load(abs_path) != OK:
			return null
	elif ResourceLoader.exists(path):
		var tex: Texture2D = load(path) as Texture2D
		src = tex.get_image() if tex != null else null
	if src == null:
		return null
	if src.is_compressed():
		src.decompress()
	if src.get_format() != Image.FORMAT_RGBA8:
		src.convert(Image.FORMAT_RGBA8)
	return src

static func _stamp_of(img: Image) -> String:
	return img.get_data().sha256_buffer().hex_encode().substr(0, 16)

static func _try_hub_baked() -> bool:
	if HUB_BAKE_STAMP == "":
		return false
	var rt: Variant = load(RT_PATH)
	var img: Image = _baked_image(rt.HUB_LIGHT_PATH)
	if img == null:
		return false
	if img.get_width() < 16 or img.get_height() < 16:
		return false
	if _stamp_of(img) != HUB_BAKE_STAMP:
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
	img.fill(HUB_FIELD)
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
## Bakes exactly what the runtime computes: a fresh field image through _hub_render, nothing else on top.
static func save_hub_bake() -> void:
	var rt: Variant = load(RT_PATH)
	if rt._img == null:
		push_error("bake_camp: rt._img null")
		return
	var img: Image = Image.create(rt._img.get_width(), rt._img.get_height(), false, Image.FORMAT_RGBA8)
	img.fill(HUB_FIELD)
	var nwrite: int = _hub_render(img, int(rt.origin.x), int(rt.origin.y), rt._hub_layout)
	var abs_path: String = ProjectSettings.globalize_path(rt.HUB_LIGHT_PATH)
	DirAccess.make_dir_recursive_absolute(abs_path.get_base_dir())
	img.save_png(abs_path)
	printerr("bake_camp: shadow_px=%d %dx%d" % [nwrite, img.get_width(), img.get_height()])
	printerr("bake_camp: stamp=%s" % _stamp_of(img))
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
		LoadTiming.note("hub_light", "baked")
		return
	LoadTiming.note("hub_light", "runtime")
	_hub_make_rt(x0, z0, tw, th)
	LoadTiming.mark("light_make_rt")
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
	if ax < 0.0 and _is_flat(img):
		_paint_flat(img, x0, z0, sub, mid, ax, az, warm)
		y = h
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
	# Only pixels within cr of the crystal change; skip the rest of the image.
	var gx0: int = clampi(int(floor((rt.hub_crystal.x - cr - float(x0)) * sub)) - 2, 0, w)
	var gx1: int = clampi(int(ceil((rt.hub_crystal.x + cr - float(x0)) * sub)) + 2, 0, w)
	var y2: int = clampi(int(floor((rt.hub_crystal.y - cr - float(z0)) * sub)) - 2, 0, h)
	var gy1: int = clampi(int(ceil((rt.hub_crystal.y + cr - float(z0)) * sub)) + 2, 0, h)
	while y2 < gy1:
		var x2: int = gx0
		while x2 < gx1:
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
static func _is_flat(img: Image) -> bool:
	if img.get_format() != Image.FORMAT_RGBA8:
		return false
	var ref: Image = Image.create(img.get_width(), img.get_height(), false, Image.FORMAT_RGBA8)
	ref.fill(img.get_pixel(0, 0))
	return ref.get_data() == img.get_data()
static func _mix(c: Color, warm: Color, k: float) -> Color:
	return Color(c.r + (warm.r - c.r) * k, c.g + (warm.g - c.g) * k, c.b + (warm.b - c.b) * k, 1.0)
static func _paint_flat(img: Image, x0: int, z0: int, sub: float, mid: Vector2, ax: float, az: float, warm: Color) -> void:
	# One flat colour in, so a pixel depends only on u = clamp(0.55 - along / 36). u is 0 or 1 outside a band
	# in each row (monotone in x): fill those spans natively, set pixels only in the band. Same maths per pixel.
	var w: int = img.get_width()
	var h: int = img.get_height()
	var c: Color = img.get_pixel(0, 0)
	var col0: Color = _mix(c, warm, 0.48 * 0.0)
	var col1: Color = _mix(c, warm, 0.48 * 1.0)
	var dr: float = warm.r - c.r
	var dg: float = warm.g - c.g
	var db: float = warm.b - c.b
	var xs := PackedFloat64Array()
	xs.resize(w)
	for x in w:
		xs[x] = (float(x0) + (float(x) + 0.5) / sub - mid.x) * ax
	for y in h:
		var rowz: float = (float(z0) + (float(y) + 0.5) / sub - mid.y) * az
		var a: int = _first_u(xs, rowz, w, false)
		var b: int = _first_u(xs, rowz, w, true)
		if a > 0:
			img.fill_rect(Rect2i(0, y, a, 1), col0)
		if b < w:
			img.fill_rect(Rect2i(b, y, w - b, 1), col1)
		for x in range(a, b):
			var k: float = 0.48 * clampf(0.55 - (xs[x] + rowz) / 36.0, 0.0, 1.0)
			img.set_pixel(x, y, Color(c.r + dr * k, c.g + dg * k, c.b + db * k, 1.0))
static func _first_u(xs: PackedFloat64Array, rowz: float, w: int, full: bool) -> int:
	# First x with u > 0 (or u >= 1 when full). u never decreases with x here.
	var lo: int = 0
	var hi: int = w
	while lo < hi:
		var m: int = (lo + hi) >> 1
		var u: float = clampf(0.55 - (xs[m] + rowz) / 36.0, 0.0, 1.0)
		if (u >= 1.0) if full else (u > 0.0):
			hi = m
		else:
			lo = m + 1
	return lo
## Day gradient, cast skirts, one blur on a field-filled image. The runtime yard and the bake both run this.
static func _hub_render(img: Image, x0: int, z0: int, layout: Node) -> int:
	_hub_paint_day(img, x0, z0, layout)
	LoadTiming.mark("light_paint")
	var wrote: int = HubCast._hub_cast_buildings(img, x0, z0, layout)
	LoadTiming.mark("light_cast")
	HubShadow._blur_hub(img)
	LoadTiming.mark("light_blur")
	return wrote
static func _hub_finish_yard(x0: int, z0: int, layout: Node) -> void:
	var rt: Variant = load(RT_PATH)
	if rt._img == null:
		return
	_hub_render(rt._img, x0, z0, layout)
	if rt._gpu != null:
		rt._gpu.set_image(rt._img)
	rt.tex = rt._gpu
	rt._push()
