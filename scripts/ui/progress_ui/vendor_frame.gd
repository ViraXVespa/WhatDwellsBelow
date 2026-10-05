extends Object

## Vendor menu built as a stall front. The world stall sprite stays on the building.
## Posts, awning, and counter are drawn for this menu. The cream plate stays for
## every other progress panel and only anchors this menu's prompt footer.

const ThemeS: GDScript = preload("res://scripts/ui/theme.gd")
const Plate: GDScript = preload("res://scripts/ui/plate_chrome.gd")

const FRAME_POS: Vector2 = Vector2(390, 110)
const FRAME_SIZE: Vector2 = Vector2(1140, 680)
const PLATE_POS: Vector2 = Vector2(360, 80)
const PLATE_SIZE: Vector2 = Vector2(1200, 920)
const SCROLL_POS: Vector2 = Vector2(384, 104)
const SCROLL_SIZE: Vector2 = Vector2(1152, 832)
const FOOTER_ROOM: float = 72.0
const POST_W: float = 56.0
const BEAM_H: float = 40.0
const AWNING_H: float = 176.0
const COUNTER_H: float = 390.0
const NAME_W: float = 640.0
const NAME_H: float = 92.0

const WOOD: Color = Color(0.55, 0.40, 0.27, 1)
const OLIVE: Color = Color(0.44, 0.41, 0.25, 1)
const CLAY: Color = Color(0.55, 0.24, 0.20, 1)
const MOUTH: Color = Color(0.11, 0.07, 0.08, 1)
const PAPER: Color = Color(0.94, 0.86, 0.72, 1)

static var _images: Dictionary = {}

static func mount(host: CanvasLayer) -> void:
	var chrome: Control = Control.new()
	chrome.name = "stall_chrome"
	chrome.visible = false
	chrome.mouse_filter = Control.MOUSE_FILTER_IGNORE
	host.add_child(chrome)
	host.move_child(chrome, 1)
	_piece(chrome, "stall_mouth", _fill_tex(MOUTH))
	_piece(chrome, "stall_post_l", _post_tex(false))
	_piece(chrome, "stall_post_r", _post_tex(true))
	_piece(chrome, "stall_beam", _grain_tex(160, 32, 0.42, 0))
	_piece(chrome, "stall_awning", _awning_tex(560, 96))
	_piece(chrome, "stall_counter", _grain_tex(160, 48, 0.12, 0))
	_piece(chrome, "stall_crate", _crate_tex())
	_piece(chrome, "stall_pot", _pot_tex())
	for i: int in 7:
		var kind: int = i % 3
		var tex: Texture2D = _herb_tex()
		if kind == 0:
			tex = _bulb_tex()
		elif kind == 1:
			tex = _tool_tex()
		_piece(chrome, "stall_hang_%d" % i, tex)
	var board: TextureRect = _piece(chrome, "stall_board", _grain_tex(160, 40, 0.8, 3))
	board.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var title: Label = ThemeS.lab("", 32, ThemeS.INK, HORIZONTAL_ALIGNMENT_CENTER, false)
	title.name = "stall_title"
	title.mouse_filter = Control.MOUSE_FILTER_IGNORE
	chrome.add_child(title)
	var bank: Label = ThemeS.lab("", 18, ThemeS.INK, HORIZONTAL_ALIGNMENT_CENTER, true)
	bank.name = "stall_bank"
	bank.mouse_filter = Control.MOUSE_FILTER_IGNORE
	chrome.add_child(bank)
	var note: Label = ThemeS.lab("", 20, PAPER, HORIZONTAL_ALIGNMENT_CENTER, true)
	note.name = "stall_status"
	note.mouse_filter = Control.MOUSE_FILTER_IGNORE
	chrome.add_child(note)

static func apply(host: CanvasLayer) -> void:
	var chrome: Control = host.get_node_or_null("stall_chrome") as Control
	var plate: ColorRect = host.get_node_or_null("plate") as ColorRect
	var edge: ColorRect = host.get_node_or_null("plate_edge") as ColorRect
	var scroll: ScrollContainer = host.get_node_or_null("plate_scroll") as ScrollContainer
	if chrome == null or plate == null or edge == null or scroll == null:
		return
	var vendor: bool = str(host.get("mode")) == "vendor"
	chrome.visible = vendor
	edge.visible = not vendor
	if vendor:
		_place(chrome)
		plate.color = Color(0, 0, 0, 0)
		plate.position = FRAME_POS
		plate.size = Vector2(FRAME_SIZE.x, FRAME_SIZE.y + FOOTER_ROOM)
		var inner_x: float = POST_W + 108.0
		var inner_w: float = FRAME_SIZE.x - POST_W * 2.0 - 216.0
		scroll.position = FRAME_POS + Vector2(inner_x, FRAME_SIZE.y - COUNTER_H + 36.0)
		scroll.size = Vector2(inner_w, COUNTER_H - 56.0)
		scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
		scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_SHOW_NEVER
		host.box.add_theme_constant_override("separation", 8)
	else:
		plate.color = Plate.PLATE
		plate.position = PLATE_POS
		plate.size = PLATE_SIZE
		edge.position = PLATE_POS
		edge.size = Vector2(PLATE_SIZE.x, float(Plate.EDGE_H))
		scroll.position = SCROLL_POS
		scroll.size = SCROLL_SIZE
		scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
		scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
		host.box.add_theme_constant_override("separation", 8)

static func prepare(host: CanvasLayer) -> void:
	var chrome: Control = host.get_node_or_null("stall_chrome") as Control
	if chrome == null:
		return
	var title: Label = chrome.get_node("stall_title") as Label
	var bank: Label = chrome.get_node("stall_bank") as Label
	title.text = App.tr("shop.vendor_stall")
	bank.text = App.tr("shop.bank_g_ore_potions_and") % [App.bank_gold, App.bank_ore]
	host.status = chrome.get_node("stall_status") as Label
	host.status.text = ""

static func dress(button: Button, primary: bool) -> void:
	button.alignment = HORIZONTAL_ALIGNMENT_CENTER
	button.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var lift: float = 0.7 if primary else 0.86
	var foot: int = 4 if primary else 1
	button.add_theme_stylebox_override("normal", _plank_box(lift, foot))
	button.add_theme_stylebox_override("hover", _plank_box(minf(lift + 0.1, 0.92), maxi(foot, 3)))
	button.add_theme_stylebox_override("pressed", _plank_box(0.42, 6))
	button.add_theme_stylebox_override("focus", _plank_box(0.4, 8))
	button.add_theme_stylebox_override("disabled", _plank_box(0.75, 1))

static func refresh_bank(host: CanvasLayer) -> void:
	var chrome: Control = host.get_node_or_null("stall_chrome") as Control
	if chrome == null:
		return
	var bank: Label = chrome.get_node_or_null("stall_bank") as Label
	if bank:
		bank.text = App.tr("shop.bank_g_ore_potions_and") % [App.bank_gold, App.bank_ore]

static func _place(chrome: Control) -> void:
	chrome.position = FRAME_POS
	chrome.size = FRAME_SIZE
	var span: Vector2 = FRAME_SIZE
	_at(chrome, "stall_mouth", Vector2(POST_W, BEAM_H), Vector2(span.x - POST_W * 2.0, span.y - BEAM_H - COUNTER_H + 24.0))
	_at(chrome, "stall_post_l", Vector2.ZERO, Vector2(POST_W, span.y))
	_at(chrome, "stall_post_r", Vector2(span.x - POST_W, 0), Vector2(POST_W, span.y))
	_at(chrome, "stall_beam", Vector2.ZERO, Vector2(span.x, BEAM_H))
	_at(chrome, "stall_awning", Vector2(POST_W - 18.0, BEAM_H - 8.0), Vector2(span.x - POST_W * 2.0 + 36.0, AWNING_H))
	var counter_y: float = span.y - COUNTER_H
	_at(chrome, "stall_counter", Vector2(POST_W - 6.0, counter_y), Vector2(span.x - POST_W * 2.0 + 12.0, COUNTER_H))
	_at(chrome, "stall_crate", Vector2(POST_W + 14.0, counter_y + 36.0), Vector2(96, 96))
	_at(chrome, "stall_pot", Vector2(span.x - POST_W - 112.0, counter_y + 16.0), Vector2(88, 116))
	var hang_y: float = BEAM_H + NAME_H + 18.0
	var hang_span: float = span.x - POST_W * 2.0 - 160.0
	for i: int in 7:
		var hx: float = POST_W + 80.0 + hang_span * (float(i) + 0.5) / 7.0 - 22.0
		_at(chrome, "stall_hang_%d" % i, Vector2(hx, hang_y), Vector2(44, 100))
	var board_x: float = (span.x - NAME_W) * 0.5
	_at(chrome, "stall_board", Vector2(board_x, BEAM_H + 6.0), Vector2(NAME_W, NAME_H))
	var title: Label = chrome.get_node("stall_title") as Label
	title.position = Vector2(board_x + 16.0, BEAM_H + 12.0)
	title.size = Vector2(NAME_W - 32.0, 42.0)
	var bank: Label = chrome.get_node("stall_bank") as Label
	bank.position = Vector2(board_x + 16.0, BEAM_H + 52.0)
	bank.size = Vector2(NAME_W - 32.0, 32.0)
	var note: Label = chrome.get_node("stall_status") as Label
	note.position = Vector2(POST_W + 24.0, BEAM_H + AWNING_H - 8.0)
	note.size = Vector2(span.x - POST_W * 2.0 - 48.0, 36.0)

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

static func _plank_box(lift: float, foot: int) -> StyleBoxTexture:
	var box: StyleBoxTexture = StyleBoxTexture.new()
	box.texture = _grain_tex(96, 28, lift, foot)
	box.draw_center = true
	box.texture_margin_left = 8
	box.texture_margin_right = 8
	box.texture_margin_top = 6
	box.texture_margin_bottom = maxi(foot, 1)
	box.axis_stretch_horizontal = StyleBoxTexture.AXIS_STRETCH_MODE_TILE_FIT
	box.axis_stretch_vertical = StyleBoxTexture.AXIS_STRETCH_MODE_STRETCH
	box.content_margin_left = 16
	box.content_margin_right = 16
	box.content_margin_top = 8
	box.content_margin_bottom = 8
	return box

static func _grain_tex(w: int, h: int, lift: float, foot: int) -> Texture2D:
	var key: String = "g-%d-%d-%d-%d" % [w, h, int(round(lift * 100.0)), foot]
	if _images.has(key):
		return _images[key]
	var img: Image = Image.create(w, h + foot, false, Image.FORMAT_RGBA8)
	var face: Color = WOOD.lerp(PAPER, lift)
	var seam: Color = face.lerp(ThemeS.INK, 0.42)
	var row_h: int = 8
	for y: int in h:
		var band: int = y % row_h
		var row: Color = face
		if band == 0:
			row = seam
		elif band < 3:
			row = face.lerp(Color(1, 1, 1, 1), 0.12)
		for x: int in w:
			var n: int = (x * 17 + y * 5) % 9 - 4
			var px: Color = row
			px.r = clampf(px.r + float(n) * 0.012, 0.0, 1.0)
			px.g = clampf(px.g + float(n) * 0.008, 0.0, 1.0)
			if x < 2 or x >= w - 2 or y < 2:
				px = px.lerp(ThemeS.INK, 0.45)
			img.set_pixel(x, y, px)
	for y: int in foot:
		for x: int in w:
			img.set_pixel(x, h + y, ThemeS.INK)
	return _keep(key, img)

static func _post_tex(flip: bool) -> Texture2D:
	var key: String = "post-r" if flip else "post-l"
	if _images.has(key):
		return _images[key]
	var w: int = 28
	var h: int = 160
	var img: Image = Image.create(w, h, false, Image.FORMAT_RGBA8)
	var face: Color = WOOD.lerp(PAPER, 0.18)
	for y: int in h:
		for x: int in w:
			var px: Color = face
			var n: int = (x * 3 + y) % 7 - 3
			px.r = clampf(px.r + float(n) * 0.01, 0.0, 1.0)
			if x < 2 or x >= w - 2:
				px = px.lerp(ThemeS.INK, 0.55)
			if y % 18 == 0:
				px = px.lerp(ThemeS.INK, 0.28)
			img.set_pixel(x, y, px)
	for band_y: int in [18, 124]:
		for y: int in 8:
			for x: int in w:
				var iron: Color = Color(0.45, 0.48, 0.50, 1)
				if y == 0 or y == 7 or x < 1 or x >= w - 1:
					iron = iron.lerp(ThemeS.INK, 0.6)
				img.set_pixel(x, band_y + y, iron)
	return _keep(key, img)

static func _awning_tex(w: int, h: int) -> Texture2D:
	var key: String = "awning-%d-%d" % [w, h]
	if _images.has(key):
		return _images[key]
	var img: Image = Image.create(w, h, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	var hem_base: int = h - 28
	var amp: int = 16
	for y: int in h:
		for x: int in w:
			var wave: float = sin(float(x) / float(w) * 7.0 * TAU)
			var hem: int = hem_base + int((wave * 0.5 + 0.5) * float(amp))
			if y > hem:
				continue
			var px: Color = OLIVE
			if ((x / 4) + (y / 4)) % 2 == 0:
				px = px.lerp(Color(0, 0, 0, 1), 0.08)
			if y < 10:
				px = px.lerp(ThemeS.INK, 0.35)
			if hem - y < 5:
				px = px.lerp(ThemeS.INK, 0.28)
			if hem - y == 7 and (x % 5) < 2:
				px = ThemeS.INK
			img.set_pixel(x, y, px)
	_ring(img, 18, 16, 11)
	_ring(img, w - 19, 16, 11)
	return _keep(key, img)

static func _ring(img: Image, cx: int, cy: int, radius: int) -> void:
	var iron: Color = Color(0.62, 0.64, 0.66, 1)
	for y: int in range(cy - radius, cy + radius + 1):
		for x: int in range(cx - radius, cx + radius + 1):
			if x < 0 or y < 0 or x >= img.get_width() or y >= img.get_height():
				continue
			var dx: int = x - cx
			var dy: int = y - cy
			var d2: int = dx * dx + dy * dy
			if d2 > radius * radius:
				continue
			if d2 < 16:
				img.set_pixel(x, y, Color(0, 0, 0, 0))
			elif d2 > (radius - 2) * (radius - 2):
				img.set_pixel(x, y, iron.lerp(ThemeS.INK, 0.45))
			else:
				img.set_pixel(x, y, iron)

static func _bulb_tex() -> Texture2D:
	if _images.has("bulb"):
		return _images["bulb"]
	var img: Image = Image.create(18, 40, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	var cream: Color = Color(0.86, 0.78, 0.62, 1)
	for i: int in 4:
		_dot(img, 9, 8 + i * 8, 5, cream.lerp(ThemeS.INK, float(i) * 0.08))
	for y: int in 6:
		img.set_pixel(9, y, Color(0.35, 0.32, 0.22, 1))
	return _keep("bulb", img)

static func _herb_tex() -> Texture2D:
	if _images.has("herb"):
		return _images["herb"]
	var img: Image = Image.create(18, 40, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	var leaf: Color = Color(0.28, 0.38, 0.18, 1)
	for y: int in range(8, 38):
		var half: int = 3 + ((y / 6) % 3)
		for x: int in range(9 - half, 9 + half):
			img.set_pixel(x, y, leaf if (x + y) % 3 != 0 else leaf.lerp(Color(0.5, 0.55, 0.28, 1), 0.4))
	for y: int in 8:
		img.set_pixel(9, y, Color(0.35, 0.32, 0.22, 1))
	return _keep("herb", img)

static func _tool_tex() -> Texture2D:
	if _images.has("tool"):
		return _images["tool"]
	var img: Image = Image.create(18, 40, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	var haft: Color = WOOD.lerp(PAPER, 0.1)
	var head: Color = Color(0.55, 0.58, 0.60, 1)
	for y: int in range(10, 40):
		img.set_pixel(8, y, haft)
		img.set_pixel(9, y, haft.lerp(ThemeS.INK, 0.2))
	for x: int in range(3, 15):
		img.set_pixel(x, 8, head)
		img.set_pixel(x, 9, head.lerp(ThemeS.INK, 0.25))
	return _keep("tool", img)

static func _dot(img: Image, cx: int, cy: int, radius: int, col: Color) -> void:
	for y: int in range(cy - radius, cy + radius + 1):
		for x: int in range(cx - radius, cx + radius + 1):
			if x < 0 or y < 0 or x >= img.get_width() or y >= img.get_height():
				continue
			var dx: int = x - cx
			var dy: int = y - cy
			if dx * dx + dy * dy <= radius * radius:
				img.set_pixel(x, y, col)

static func _crate_tex() -> Texture2D:
	if _images.has("crate"):
		return _images["crate"]
	var img: Image = Image.create(32, 32, false, Image.FORMAT_RGBA8)
	var face: Color = WOOD.lerp(PAPER, 0.22)
	img.fill(face.lerp(ThemeS.INK, 0.55))
	for y: int in range(3, 29):
		for x: int in range(3, 29):
			var px: Color = face
			if x == 3 or y == 3 or x == 28 or y == 28 or absi(x - y) < 2 or absi(x - (31 - y)) < 2:
				px = px.lerp(ThemeS.INK, 0.45)
			img.set_pixel(x, y, px)
	return _keep("crate", img)

static func _pot_tex() -> Texture2D:
	if _images.has("pot"):
		return _images["pot"]
	var img: Image = Image.create(32, 40, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	for y: int in 40:
		for x: int in 32:
			var nx: float = (float(x) - 15.5) / 12.0
			var ny: float = (float(y) - 22.0) / 16.0
			var neck: bool = y < 10 and absf(float(x) - 15.5) < 6.0
			if nx * nx + ny * ny > 1.0 and not neck:
				continue
			var px: Color = CLAY
			if x < 12:
				px = px.lerp(Color(1, 1, 1, 1), 0.18)
			if y < 8:
				px = px.lerp(ThemeS.INK, 0.25)
			img.set_pixel(x, y, px)
	return _keep("pot", img)

static func _fill_tex(col: Color) -> Texture2D:
	var key: String = "fill-%d-%d-%d" % [int(col.r * 255.0), int(col.g * 255.0), int(col.b * 255.0)]
	if _images.has(key):
		return _images[key]
	var img: Image = Image.create(4, 4, false, Image.FORMAT_RGBA8)
	img.fill(col)
	return _keep(key, img)

static func _keep(key: String, img: Image) -> Texture2D:
	var tex: ImageTexture = ImageTexture.create_from_image(img)
	_images[key] = tex
	return tex
