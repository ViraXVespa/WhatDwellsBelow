extends Object

## Dumpster menu built as a bin front. The world dumpster sprite stays on the prop.
## Lid, mouth, bags, and the rusted body are drawn for this menu. The cream plate
## stays for every other progress panel and only anchors this menu's prompt footer.

const ThemeS: GDScript = preload("res://scripts/ui/theme.gd")

const FRAME_POS: Vector2 = Vector2(460, 64)
const FRAME_SIZE: Vector2 = Vector2(1000, 748)
const FOOTER_ROOM: float = 72.0

const LID_POS: Vector2 = Vector2(36, 4)
const LID_SIZE: Vector2 = Vector2(928, 168)
const MOUTH_POS: Vector2 = Vector2(108, 156)
const MOUTH_SIZE: Vector2 = Vector2(784, 220)
const BODY_POS: Vector2 = Vector2(72, 318)
const BODY_SIZE: Vector2 = Vector2(856, 360)
const RIM_POS: Vector2 = Vector2(72, 304)
const RIM_SIZE: Vector2 = Vector2(856, 52)
const LABEL_POS: Vector2 = Vector2(150, 388)
const LABEL_SIZE: Vector2 = Vector2(700, 160)
const TITLE_POS: Vector2 = Vector2(174, 404)
const TITLE_SIZE: Vector2 = Vector2(652, 46)
const LINE_POS: Vector2 = Vector2(174, 452)
const LINE_SIZE: Vector2 = Vector2(652, 84)
const LEAVE_POS: Vector2 = Vector2(186, 564)
const LEAVE_SIZE: Vector2 = Vector2(628, 64)
const WHEEL_SIZE: Vector2 = Vector2(86, 86)
const WHEEL_L: Vector2 = Vector2(96, 648)
const WHEEL_R: Vector2 = Vector2(818, 648)
const BAG_L: Vector2 = Vector2(156, 188)
const BAG_R: Vector2 = Vector2(628, 180)
const BAG_C: Vector2 = Vector2(390, 206)
const SLAT_POS: Vector2 = Vector2(548, 196)

const STEEL: Color = Color(0.45, 0.52, 0.56, 1)
const STEEL_DARK: Color = Color(0.26, 0.31, 0.35, 1)
const RUST: Color = Color(0.62, 0.34, 0.16, 1)
const MOUTH: Color = Color(0.07, 0.08, 0.09, 1)
const BAG: Color = Color(0.18, 0.20, 0.14, 1)
const BAG_DEEP: Color = Color(0.11, 0.12, 0.10, 1)
const STICKER: Color = Color(0.76, 0.72, 0.62, 1)
const TAPE: Color = Color(0.55, 0.48, 0.32, 1)
const RUBBER: Color = Color(0.10, 0.10, 0.11, 1)
const HUB: Color = Color(0.55, 0.58, 0.60, 1)

static var _images: Dictionary = {}
static var _empty: StyleBoxEmpty

static func mount(host: CanvasLayer) -> void:
	var chrome: Control = Control.new()
	chrome.name = "dump_chrome"
	chrome.visible = false
	chrome.mouse_filter = Control.MOUSE_FILTER_IGNORE
	host.add_child(chrome)
	host.move_child(chrome, 1)
	_piece(chrome, "dump_lid", _lid_tex())
	_piece(chrome, "dump_mouth", _mouth_tex())
	_piece(chrome, "dump_bag_c", _bag_tex(2))
	_piece(chrome, "dump_bag_l", _bag_tex(0))
	_piece(chrome, "dump_bag_r", _bag_tex(1))
	_piece(chrome, "dump_slat", _slat_tex())
	_piece(chrome, "dump_wheel_l", _wheel_tex())
	_piece(chrome, "dump_wheel_r", _wheel_tex())
	_piece(chrome, "dump_body", _body_tex())
	_piece(chrome, "dump_rim", _rim_tex())
	_piece(chrome, "dump_label", _label_tex())
	var title: Label = ThemeS.lab("", 28, ThemeS.INK, HORIZONTAL_ALIGNMENT_CENTER, false)
	title.name = "dump_title"
	title.mouse_filter = Control.MOUSE_FILTER_IGNORE
	chrome.add_child(title)
	var line: Label = ThemeS.lab("", 22, ThemeS.INK_SOFT, HORIZONTAL_ALIGNMENT_CENTER, true)
	line.name = "dump_line"
	line.mouse_filter = Control.MOUSE_FILTER_IGNORE
	chrome.add_child(line)

static func apply(host: CanvasLayer) -> void:
	var chrome: Control = host.get_node_or_null("dump_chrome") as Control
	var plate: ColorRect = host.get_node_or_null("plate") as ColorRect
	var edge: ColorRect = host.get_node_or_null("plate_edge") as ColorRect
	var scroll: ScrollContainer = host.get_node_or_null("plate_scroll") as ScrollContainer
	if chrome == null or plate == null or edge == null or scroll == null:
		return
	var flavor: bool = str(host.get("mode")) == "flavor"
	chrome.visible = flavor
	if not flavor:
		scroll.remove_theme_stylebox_override("panel")
		return
	_place(chrome)
	edge.visible = false
	plate.color = Color(0, 0, 0, 0)
	plate.position = FRAME_POS
	plate.size = Vector2(FRAME_SIZE.x, FRAME_SIZE.y + FOOTER_ROOM)
	scroll.position = FRAME_POS + LEAVE_POS
	scroll.size = LEAVE_SIZE
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_SHOW_NEVER
	scroll.add_theme_stylebox_override("panel", _blank())
	host.box.add_theme_constant_override("separation", 0)

static func prepare(host: CanvasLayer, title: String, body: String) -> void:
	var chrome: Control = host.get_node_or_null("dump_chrome") as Control
	if chrome == null:
		return
	var title_l: Label = chrome.get_node("dump_title") as Label
	var line: Label = chrome.get_node("dump_line") as Label
	title_l.text = title
	line.text = body

static func dress(button: Button) -> void:
	button.alignment = HORIZONTAL_ALIGNMENT_CENTER
	button.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button.add_theme_color_override("font_color", ThemeS.INK)
	button.add_theme_color_override("font_hover_color", ThemeS.INK)
	button.add_theme_color_override("font_focus_color", ThemeS.INK)
	button.add_theme_color_override("font_pressed_color", ThemeS.INK)
	button.add_theme_color_override("font_disabled_color", ThemeS.INK_FAINT)
	button.add_theme_stylebox_override("normal", _flap_box(0.55, 2))
	button.add_theme_stylebox_override("hover", _flap_box(0.72, 3))
	button.add_theme_stylebox_override("pressed", _flap_box(0.34, 4))
	button.add_theme_stylebox_override("focus", _flap_box(0.64, 8))
	button.add_theme_stylebox_override("disabled", _flap_box(0.4, 1))

static func _place(chrome: Control) -> void:
	chrome.position = FRAME_POS
	chrome.size = FRAME_SIZE
	_at(chrome, "dump_lid", LID_POS, LID_SIZE)
	_at(chrome, "dump_mouth", MOUTH_POS, MOUTH_SIZE)
	_at(chrome, "dump_bag_c", BAG_C, Vector2(150, 170))
	_at(chrome, "dump_bag_l", BAG_L, Vector2(168, 200))
	_at(chrome, "dump_bag_r", BAG_R, Vector2(176, 210))
	_at(chrome, "dump_slat", SLAT_POS, Vector2(44, 128))
	var slat: Control = chrome.get_node("dump_slat") as Control
	slat.pivot_offset = Vector2(22, 120)
	slat.rotation = 0.4
	_at(chrome, "dump_wheel_l", WHEEL_L, WHEEL_SIZE)
	_at(chrome, "dump_wheel_r", WHEEL_R, WHEEL_SIZE)
	_at(chrome, "dump_body", BODY_POS, BODY_SIZE)
	_at(chrome, "dump_rim", RIM_POS, RIM_SIZE)
	_at(chrome, "dump_label", LABEL_POS, LABEL_SIZE)
	var title: Label = chrome.get_node("dump_title") as Label
	title.position = TITLE_POS
	title.size = TITLE_SIZE
	var line: Label = chrome.get_node("dump_line") as Label
	line.position = LINE_POS
	line.size = LINE_SIZE

static func _piece(parent: Control, node_name: String, tex: Texture2D) -> TextureRect:
	var rect: TextureRect = TextureRect.new()
	rect.name = node_name
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	rect.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	rect.stretch_mode = TextureRect.STRETCH_SCALE
	rect.texture = tex
	parent.add_child(rect)
	return rect

static func _at(chrome: Control, node_name: String, pos: Vector2, span: Vector2) -> void:
	var rect: Control = chrome.get_node(node_name) as Control
	rect.position = pos
	rect.size = span

static func _blank() -> StyleBoxEmpty:
	if _empty == null:
		_empty = StyleBoxEmpty.new()
	return _empty

static func _flap_box(lift: float, foot: int) -> StyleBoxTexture:
	var box: StyleBoxTexture = StyleBoxTexture.new()
	box.texture = _flap_tex(lift, foot)
	box.draw_center = true
	box.texture_margin_left = 16
	box.texture_margin_right = 16
	box.texture_margin_top = 6
	box.texture_margin_bottom = maxi(foot, 1)
	box.axis_stretch_horizontal = StyleBoxTexture.AXIS_STRETCH_MODE_STRETCH
	box.axis_stretch_vertical = StyleBoxTexture.AXIS_STRETCH_MODE_STRETCH
	box.content_margin_left = 18
	box.content_margin_right = 18
	box.content_margin_top = 6
	box.content_margin_bottom = 6
	return box

static func _flap_tex(lift: float, foot: int) -> Texture2D:
	var key: String = "flap-%d-%d" % [int(round(lift * 100.0)), foot]
	if _images.has(key):
		return _images[key]
	var w: int = 96
	var h: int = 28
	var img: Image = Image.create(w, h + foot, false, Image.FORMAT_RGBA8)
	var face: Color = STEEL.lerp(Color(0.82, 0.84, 0.82, 1), lift)
	for y: int in h:
		for x: int in w:
			var px: Color = face
			if y % 4 == 0:
				px = px.lerp(STEEL_DARK, 0.18)
			if x < 2 or x >= w - 2 or y < 2 or y >= h - 2:
				px = px.lerp(ThemeS.INK, 0.45)
			img.set_pixel(x, y, px)
	_bolt(img, 10, 13)
	_bolt(img, w - 11, 13)
	for y: int in foot:
		for x: int in w:
			img.set_pixel(x, h + y, ThemeS.INK)
	return _keep(key, img)

static func _lid_tex() -> Texture2D:
	if _images.has("lid"):
		return _images["lid"]
	var w: int = 120
	var h: int = 48
	var img: Image = Image.create(w, h, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	var inset: int = 26
	for y: int in h:
		var t: float = float(y) / float(h - 1)
		var cut: int = int(float(inset) * (1.0 - t))
		for x: int in range(cut, w - cut):
			var px: Color = STEEL.lerp(Color(0.78, 0.84, 0.86, 1), 0.28)
			if y < 3 or x == cut or x == w - cut - 1:
				px = px.lerp(ThemeS.INK, 0.4)
			if y >= h - 5:
				px = STEEL_DARK
			if (x * 13 + y * 5) % 47 < 2:
				px = px.lerp(RUST, 0.65)
			img.set_pixel(x, y, px)
	for x: int in range(48, 72):
		img.set_pixel(x, 8, STEEL_DARK)
		img.set_pixel(x, 9, HUB)
		img.set_pixel(x, 10, STEEL_DARK)
	img.set_pixel(50, 11, STEEL_DARK)
	img.set_pixel(51, 12, STEEL_DARK)
	img.set_pixel(68, 11, STEEL_DARK)
	img.set_pixel(69, 12, STEEL_DARK)
	return _keep("lid", img)

static func _mouth_tex() -> Texture2D:
	if _images.has("mouth"):
		return _images["mouth"]
	var img: Image = Image.create(32, 32, false, Image.FORMAT_RGBA8)
	for y: int in 32:
		for x: int in 32:
			var px: Color = MOUTH
			if y < 6:
				px = px.lerp(Color(0, 0, 0, 1), 0.45)
			if x < 2 or x > 29:
				px = px.lerp(STEEL_DARK, 0.35)
			img.set_pixel(x, y, px)
	return _keep("mouth", img)

static func _body_tex() -> Texture2D:
	if _images.has("body"):
		return _images["body"]
	var w: int = 96
	var h: int = 72
	var img: Image = Image.create(w, h, false, Image.FORMAT_RGBA8)
	for y: int in h:
		for x: int in w:
			var px: Color = STEEL
			if x < 4 or x >= w - 4:
				px = STEEL_DARK
			var rib: int = y % 18
			if rib == 0:
				px = px.lerp(STEEL_DARK, 0.55)
			elif rib == 1:
				px = px.lerp(Color(0.85, 0.90, 0.92, 1), 0.35)
			var stripe: int = (x * 7) % 23
			if (stripe == 0 or stripe == 1) and y > 10 and (y + x) % 11 < 7:
				px = px.lerp(RUST, 0.62)
			if (x - 28) * (x - 28) + (y - 44) * (y - 44) < 28:
				px = px.lerp(RUST, 0.5)
			if x < 2 or y < 2 or x >= w - 2:
				px = px.lerp(ThemeS.INK, 0.35)
			img.set_pixel(x, y, px)
	_bolt(img, 8, 8)
	_bolt(img, w - 9, 8)
	_bolt(img, 8, h - 10)
	_bolt(img, w - 9, h - 10)
	return _keep("body", img)

static func _rim_tex() -> Texture2D:
	if _images.has("rim"):
		return _images["rim"]
	var w: int = 96
	var h: int = 16
	var img: Image = Image.create(w, h, false, Image.FORMAT_RGBA8)
	for y: int in h:
		for x: int in w:
			var px: Color = STEEL_DARK.lerp(STEEL, 0.35)
			if y < 3:
				px = px.lerp(Color(0.80, 0.86, 0.88, 1), 0.45)
			if y > h - 4:
				px = px.lerp(Color(0, 0, 0, 1), 0.35)
			img.set_pixel(x, y, px)
	for x: int in [12, 48, 84]:
		_bolt(img, x, 8)
	return _keep("rim", img)

static func _label_tex() -> Texture2D:
	if _images.has("label"):
		return _images["label"]
	var w: int = 80
	var h: int = 36
	var img: Image = Image.create(w, h, false, Image.FORMAT_RGBA8)
	var dirt: Color = Color(0.42, 0.32, 0.22, 1)
	for y: int in h:
		for x: int in w:
			var px: Color = STICKER
			if x < 2 or y < 2 or x >= w - 2 or y >= h - 2:
				px = px.lerp(dirt, 0.55)
			elif (x * 17 + y * 13) % 97 == 0:
				px = px.lerp(dirt, 0.35)
			img.set_pixel(x, y, px)
	for y: int in range(1, 7):
		for x: int in range(2, 16):
			img.set_pixel(x, y, TAPE)
		for x: int in range(w - 16, w - 2):
			img.set_pixel(x, y, TAPE)
	return _keep("label", img)

static func _bag_tex(kind: int) -> Texture2D:
	var key: String = "bag-%d" % kind
	if _images.has(key):
		return _images[key]
	var img: Image = Image.create(48, 56, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	var col: Color = BAG
	if kind == 1:
		col = BAG.lerp(Color(0.30, 0.32, 0.22, 1), 0.4)
	elif kind == 2:
		col = BAG_DEEP
	var mid: float = 24.0
	for y: int in 56:
		var half: float = 18.0
		if y < 7:
			half = 3.0
		elif y < 16:
			half = 3.0 + float(y - 7) * 1.7
		else:
			half = 16.0 + sin(float(y) * 0.55 + float(kind) * 1.4) * 2.5
		for x: int in 48:
			if absf(float(x) - mid) > half:
				continue
			var px: Color = col
			if float(x) < mid - 4.0:
				px = px.lerp(Color(0.40, 0.44, 0.32, 1), 0.28)
			if y < 7:
				px = px.lerp(TAPE, 0.45)
			if absi(x - int(mid)) <= 1 and y > 14 and y < 48:
				px = px.lerp(Color(0, 0, 0, 1), 0.28)
			img.set_pixel(x, y, px)
	return _keep(key, img)

static func _slat_tex() -> Texture2D:
	if _images.has("slat"):
		return _images["slat"]
	var img: Image = Image.create(10, 36, false, Image.FORMAT_RGBA8)
	var wood: Color = Color(0.62, 0.52, 0.36, 1)
	for y: int in 36:
		for x: int in 10:
			var px: Color = wood
			if x == 0 or x == 9:
				px = px.lerp(ThemeS.INK, 0.45)
			img.set_pixel(x, y, px)
	return _keep("slat", img)

static func _wheel_tex() -> Texture2D:
	if _images.has("wheel"):
		return _images["wheel"]
	var img: Image = Image.create(32, 32, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	for y: int in range(0, 16):
		img.set_pixel(8, y, STEEL_DARK)
		img.set_pixel(9, y, STEEL)
		img.set_pixel(22, y, STEEL)
		img.set_pixel(23, y, STEEL_DARK)
	for y: int in 32:
		for x: int in 32:
			var dx: int = x - 16
			var dy: int = y - 18
			var d2: int = dx * dx + dy * dy
			if d2 > 13 * 13:
				continue
			if d2 >= 7 * 7:
				img.set_pixel(x, y, RUBBER)
			elif d2 >= 3 * 3:
				img.set_pixel(x, y, HUB.lerp(STEEL_DARK, 0.25))
			else:
				img.set_pixel(x, y, STEEL_DARK)
	return _keep("wheel", img)

static func _bolt(img: Image, cx: int, cy: int) -> void:
	_dot(img, cx, cy, 2, HUB.lerp(STEEL_DARK, 0.2))
	if cx >= 0 and cy >= 0 and cx < img.get_width() and cy < img.get_height():
		img.set_pixel(cx, cy, STEEL_DARK)

static func _dot(img: Image, cx: int, cy: int, radius: int, col: Color) -> void:
	for y: int in range(cy - radius, cy + radius + 1):
		for x: int in range(cx - radius, cx + radius + 1):
			if x < 0 or y < 0 or x >= img.get_width() or y >= img.get_height():
				continue
			var dx: int = x - cx
			var dy: int = y - cy
			if dx * dx + dy * dy <= radius * radius:
				img.set_pixel(x, y, col)

static func _keep(key: String, img: Image) -> Texture2D:
	var tex: ImageTexture = ImageTexture.create_from_image(img)
	_images[key] = tex
	return tex
