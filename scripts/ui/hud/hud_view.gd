extends Object

const ThemeS := preload("res://scripts/ui/theme.gd")
const UiText := preload("res://scripts/ui/ui_text.gd")
const T := preload("res://scripts/data/tunables.gd")
const Icons := preload("res://scripts/ui/gear_icons.gd")

const CARD_TEX := "res://assets/ui/hud/card.png"
const BAR_TEX := "res://assets/ui/hud/bar.png"
const GEM_TEX := "res://assets/ui/hud/gem.png"
const BIBLE_MALE := preload("res://assets/sprites/player/bible_locked_male.png")
const BIBLE_FEMALE := preload("res://assets/sprites/player/bible_locked_female.png")
const BAR_INSET := 3.0
const STRIP_INK := Color(0.93, 0.88, 0.76)

## HUD chrome. Host is the CanvasLayer at scripts/ui/hud.gd.


static func build(host: CanvasLayer) -> void:
	host.border = Control.new()
	host.border.mouse_filter = Control.MOUSE_FILTER_IGNORE
	host.border.visible = false
	host.add_child(host.border)
	host.border_top = _edge(host, "top")
	host.border_bottom = _edge(host, "bottom")
	host.border_left = _edge(host, "left")
	host.border_right = _edge(host, "right")
	host.strip = Control.new()
	host.add_child(host.strip)
	var card := _patch(CARD_TEX, Vector2.ZERO, Vector2(host.STRIP_W, host.STRIP_H), 12, 12, 12, 12, true)
	host.strip.add_child(card)
	var face := Vector2(host.PORTRAIT_PX, host.PORTRAIT_PX)
	host.portrait = TextureRect.new()
	host.portrait.position = Vector2(16, 18)
	host.portrait.size = face
	host.portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	host.portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	host.portrait.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	host.portrait.mouse_filter = Control.MOUSE_FILTER_IGNORE
	host.strip.add_child(host.portrait)
	host.wound = TextureRect.new()
	host.wound.position = host.portrait.position
	host.wound.size = face
	host.wound.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	host.wound.stretch_mode = TextureRect.STRETCH_SCALE
	host.wound.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	host.wound.mouse_filter = Control.MOUSE_FILTER_IGNORE
	host.wound.visible = false
	host.strip.add_child(host.wound)
	host.hp_fill = meter(host.strip, Vector2(88, 18), Vector2(host.HP_W, 16), Color(0.72, 0.18, 0.16))
	host.hp_lab = lab(host.strip, Vector2(88, 16), Vector2(host.HP_W, 20), 16)
	host.mana_fill = meter(host.strip, Vector2(88, 38), Vector2(host.MANA_W, 14), Color(0.42, 0.68, 0.95))
	host.mana_lab = lab(host.strip, Vector2(88, 36), Vector2(host.MANA_W, 18), 13)
	host.pot_icon = _icon(host.strip, Vector2(16, 92), Icons.tex_for_slot("potion", {}))
	host.pot_timer = _sweep(host.strip, host.pot_icon)
	host.pot_lab = lab(host.strip, Vector2(46, 96), Vector2(48, 20), 14)
	host.food_icon = _icon(host.strip, Vector2(100, 92), Icons.tex_for_slot("food", {}))
	host.food_timer = _sweep(host.strip, host.food_icon)
	host.food_lab = lab(host.strip, Vector2(130, 96), Vector2(48, 20), 14)
	host.dash_fill = meter(host.strip, Vector2(184, 106), Vector2(host.DASH_W, 14), Color(0.3, 0.7, 0.85))
	host.spec_fill = meter(host.strip, Vector2(308, 106), Vector2(host.SPEC_W, 14), Color(0.9, 0.55, 0.2))
	lab(host.strip, Vector2(184, 88), Vector2(host.DASH_W, 16), 13).text = App.tr("hud_view.dash")
	lab(host.strip, Vector2(308, 88), Vector2(host.SPEC_W, 16), 13).text = App.tr("hud_view.special")
	host.lvl = lab(host.strip, Vector2(88, 56), Vector2(200, 24), 20)
	host.floor_lab = lab(host.strip, Vector2(292, 54), Vector2(76, 26), 22)
	host.res = lab(host.strip, Vector2(16, 128), Vector2(250, 20), 16)
	host.shrine_icon = TextureRect.new()
	host.shrine_icon.position = Vector2(276, 126)
	host.shrine_icon.size = Vector2(22, 22)
	host.shrine_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	host.shrine_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	host.shrine_icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	if ResourceLoader.exists("res://assets/sprites/props/shrine.png"):
		host.shrine_icon.texture = load("res://assets/sprites/props/shrine.png")
	host.shrine_icon.visible = false
	host.strip.add_child(host.shrine_icon)
	host.shrine_lab = lab(host.strip, Vector2(300, 124), Vector2(136, 22), 14)
	host.shrine_lab.add_theme_color_override("font_color", Color(0.95, 0.72, 0.40))
	host.gem = TextureRect.new()
	host.gem.texture = _tex(GEM_TEX)
	host.gem.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	host.gem.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	host.gem.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	host.gem.position = Vector2(374, 18)
	host.gem.size = Vector2(64, 64)
	host.gem.mouse_filter = Control.MOUSE_FILTER_IGNORE
	host.strip.add_child(host.gem)
	host.prompt_back = ColorRect.new()
	host.prompt_back.color = Color(0.11, 0.11, 0.12, 0.92)
	host.prompt_back.mouse_filter = Control.MOUSE_FILTER_IGNORE
	host.prompt_back.visible = false
	host.strip.add_child(host.prompt_back)
	host.prompt_row = HBoxContainer.new()
	host.prompt_row.position = Vector2(16, host.STRIP_H + 4)
	host.prompt_row.size = Vector2(host.STRIP_W - 32, 24)
	host.prompt_row.add_theme_constant_override("separation", 8)
	host.prompt_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	host.strip.add_child(host.prompt_row)
	host.toast = lab(host, Vector2(24, 16 + host.STRIP_H + 8), Vector2(420, 28), 20, true)
	host.toast.add_theme_color_override("font_color", Color(1.0, 0.88, 0.45))
	host.boss_wrap = Control.new()
	host.boss_wrap.size = Vector2(420, 50)
	host.add_child(host.boss_wrap)
	host.boss_fill = meter(host.boss_wrap, Vector2(0, 18), Vector2(360, 18), Color(0.75, 0.15, 0.2), false)
	host.boss_lab = lab(host.boss_wrap, Vector2(0, 0), Vector2(360, 20), 16, true)
	host.mini_wrap = Control.new()
	host.mini_wrap.mouse_filter = Control.MOUSE_FILTER_IGNORE
	host.add_child(host.mini_wrap)
	host.mini_map = TextureRect.new()
	host.mini_map.position = Vector2.ZERO
	host.mini_map.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	host.mini_map.stretch_mode = TextureRect.STRETCH_SCALE
	host.mini_map.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	host.mini_map.mouse_filter = Control.MOUSE_FILTER_IGNORE
	host.mini_frame = ColorRect.new()
	host.mini_frame.color = ThemeS.RULE
	host.mini_frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	host.mini_wrap.add_child(host.mini_frame)
	host.mini_wrap.add_child(host.mini_map)
	host.fps_lab = lab(host, Vector2.ZERO, Vector2(140, 28), 16, true)
	host.look_lab = lab(host, Vector2.ZERO, Vector2(420, 28), 16, true)
	host.look_lab.add_theme_color_override("font_color", Color(0.95, 0.82, 0.45))
	layout(host)
	load_portrait(host)


static func layout(host: CanvasLayer) -> void:
	var sc: float = App.hud_scale * UiText.play_scale()
	var vp: Vector2 = host.get_viewport().get_visible_rect().size
	var side: float = clampf(float(App.mini_px), T.MINI_PX_MIN, T.MINI_PX_MAX)
	var frame_px: float = T.MINI_BORDER
	host.strip.scale = Vector2(sc, sc)
	host.strip.position = Vector2(host.MARGIN, 16)
	host.mini_map.size = Vector2(side, side)
	host.mini_frame.position = Vector2(-frame_px, -frame_px)
	host.mini_frame.size = Vector2(side + frame_px * 2.0, side + frame_px * 2.0)
	host.mini_wrap.modulate.a = clampf(float(App.mini_opacity), 0.0, 1.0)
	host.mini_wrap.scale = Vector2(sc, sc)
	host.mini_wrap.position = Vector2(vp.x - host.MARGIN - (side + frame_px) * sc, 16)
	host.toast.scale = Vector2(sc, sc)
	host.toast.position = Vector2(host.MARGIN, 16 + (host.STRIP_H + 28.0) * sc + 8)
	host.boss_wrap.scale = Vector2(sc, sc)
	host.boss_wrap.position = Vector2(host.MARGIN, host.toast.position.y + 32 * sc)
	var under: float = host.mini_wrap.position.y + (side + frame_px) * sc + 4.0
	host.fps_lab.scale = Vector2(sc, sc)
	host.fps_lab.position = Vector2(host.mini_wrap.position.x, under)
	host.look_lab.scale = Vector2(sc, sc)
	host.look_lab.position = Vector2(host.mini_wrap.position.x, under + 24.0 * sc)


static func load_portrait(host: CanvasLayer) -> void:
	# Center cell of the live bible lock. _src is gdignored, so the runtime path is the asset copy.
	var kind: String = str(App.character_type)
	var tex: Texture2D = _bible(kind)
	if tex == null:
		push_error("HUD portrait bible missing: %s" % kind)
		host.portrait_path = ""
		host.portrait.texture = null
		return
	if kind == host.portrait_path and host.portrait.texture != null:
		return
	host.portrait_path = kind
	host._wound_key = -1
	var raw: Image = tex.get_image()
	if raw == null or raw.is_empty():
		push_error("HUD portrait bible has no pixels: %s" % kind)
		host.portrait.texture = null
		return
	var img: Image = raw.duplicate()
	if img.get_format() != Image.FORMAT_RGBA8:
		img.convert(Image.FORMAT_RGBA8)
	var face: Image = _fit_square(_key_plate(_center_cell(img)), int(host.PORTRAIT_PX))
	host.portrait.texture = ImageTexture.create_from_image(face)


static func _bible(kind: String) -> Texture2D:
	if kind == "female":
		return BIBLE_FEMALE
	if kind == "male":
		return BIBLE_MALE
	return null


static func fit_prompt_back(host: CanvasLayer) -> void:
	var back: ColorRect = host.prompt_back
	var row: HBoxContainer = host.prompt_row
	if back == null or row == null or row.get_child_count() == 0:
		if back != null:
			back.visible = false
		return
	var used: Vector2 = row.get_combined_minimum_size()
	back.visible = true
	back.position = row.position - Vector2(4, 2)
	back.size = Vector2(minf(used.x + 8.0, row.size.x), maxf(used.y, row.size.y) + 4.0)


static func paint_wounds(host: CanvasLayer, frac: float) -> void:
	if host.wound == null:
		return
	var key: int = 0 if frac > 0.88 else int(round(frac * 40.0))
	if key == host._wound_key and host.wound.texture != null:
		return
	host._wound_key = key
	var side: int = int(host.PORTRAIT_PX)
	var img: Image = Image.create(side, side, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	if frac <= 0.88:
		_draw_wounds(img, frac)
	if host.wound.texture is ImageTexture:
		(host.wound.texture as ImageTexture).set_image(img)
	else:
		host.wound.texture = ImageTexture.create_from_image(img)
	host.wound.visible = frac <= 0.88


static func paint_border(host: CanvasLayer, frac: float) -> void:
	if host.border == null:
		return
	var strength: float = 0.0
	if bool(App.red_border_glow) and frac <= 0.5:
		strength = lerpf(0.22, 1.0, clampf((0.5 - frac) / 0.5, 0.0, 1.0))
	host.border.visible = strength > 0.0
	if strength <= 0.0:
		return
	host.border.modulate = Color(1, 1, 1, strength)
	var vp: Vector2 = host.get_viewport().get_visible_rect().size
	var depth: float = lerpf(56.0, 168.0, strength)
	host.border.position = Vector2.ZERO
	host.border.size = vp
	host.border_top.position = Vector2.ZERO
	host.border_top.size = Vector2(vp.x, depth)
	host.border_bottom.position = Vector2(0, vp.y - depth)
	host.border_bottom.size = Vector2(vp.x, depth)
	host.border_left.position = Vector2.ZERO
	host.border_left.size = Vector2(depth, vp.y)
	host.border_right.position = Vector2(vp.x - depth, 0)
	host.border_right.size = Vector2(depth, vp.y)


static func meter(owner: Control, pos: Vector2, sz: Vector2, col: Color, metal := true) -> ColorRect:
	if metal:
		var frame := _patch(BAR_TEX, pos, sz, 10, 4, 10, 4)
		owner.add_child(frame)
	else:
		var back := ColorRect.new()
		back.color = Color(0.55, 0.42, 0.30, 1)
		back.position = pos
		back.size = sz
		owner.add_child(back)
	var fill := ColorRect.new()
	fill.color = col
	var inset: float = BAR_INSET if metal else 0.0
	fill.position = pos + Vector2(inset, inset)
	fill.size = sz - Vector2(inset * 2.0, inset * 2.0)
	fill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	owner.add_child(fill)
	return fill


static func lab(owner: Node, pos: Vector2, sz: Vector2, fs: int, over_world: bool = false) -> Label:
	var l := Label.new()
	l.position = pos
	l.size = sz
	l.add_theme_font_size_override("font_size", fs)
	var col: Color = Color(0.95, 0.90, 0.78) if over_world else STRIP_INK
	l.add_theme_color_override("font_color", col)
	if not over_world:
		l.add_theme_color_override("font_outline_color", Color(0.05, 0.04, 0.03, 0.85))
		l.add_theme_constant_override("outline_size", 2)
	if over_world:
		l.add_theme_color_override("font_outline_color", ThemeS.PROMPT_OUTLINE)
		l.add_theme_constant_override("outline_size", ThemeS.PROMPT_OUTLINE_SIZE)
	owner.add_child(l)
	return l


static func _tex(path: String) -> Texture2D:
	if not ResourceLoader.exists(path):
		push_error("HUD art missing: %s" % path)
		return null
	var tex: Texture2D = load(path) as Texture2D
	if tex == null:
		push_error("HUD art failed to load: %s" % path)
	return tex


static func _patch(path: String, pos: Vector2, sz: Vector2, left: int, top: int, right: int, bottom: int, tile: bool = false) -> NinePatchRect:
	var patch := NinePatchRect.new()
	patch.texture = _tex(path)
	patch.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	patch.patch_margin_left = left
	patch.patch_margin_top = top
	patch.patch_margin_right = right
	patch.patch_margin_bottom = bottom
	if tile:
		patch.axis_stretch_horizontal = NinePatchRect.AXIS_STRETCH_MODE_TILE
		patch.axis_stretch_vertical = NinePatchRect.AXIS_STRETCH_MODE_TILE
	patch.position = pos
	patch.size = sz
	return patch


static func _icon(parent_ctrl: Control, pos: Vector2, tex: Texture2D) -> TextureRect:
	var icon: TextureRect = TextureRect.new()
	icon.position = pos
	icon.size = Vector2(28, 28)
	icon.texture = tex
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent_ctrl.add_child(icon)
	return icon


static func _sweep(parent_ctrl: Control, icon: TextureRect) -> TextureProgressBar:
	var bar: TextureProgressBar = TextureProgressBar.new()
	bar.position = icon.position
	bar.size = icon.size
	bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bar.fill_mode = TextureProgressBar.FILL_CLOCKWISE
	bar.radial_initial_angle = 0.0
	bar.min_value = 0.0
	bar.max_value = 1.0
	bar.step = 0.001
	bar.value = 0.0
	bar.texture_progress = _veil()
	bar.tint_progress = Color(0.02, 0.0, 0.03, 0.78)
	bar.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	bar.visible = false
	parent_ctrl.add_child(bar)
	return bar


static func _veil() -> Texture2D:
	var img: Image = Image.create(32, 32, false, Image.FORMAT_RGBA8)
	img.fill(Color.WHITE)
	return ImageTexture.create_from_image(img)


static func _edge(host: CanvasLayer, edge: String) -> TextureRect:
	var rect: TextureRect = TextureRect.new()
	rect.texture = _vignette(edge)
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	rect.stretch_mode = TextureRect.STRETCH_SCALE
	rect.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	host.border.add_child(rect)
	return rect


static func _vignette(edge: String) -> GradientTexture2D:
	var g: Gradient = Gradient.new()
	g.set_color(0, Color(0.75, 0.0, 0.02, 0.0))
	g.set_color(1, Color(0.9, 0.02, 0.03, 0.95))
	var tex: GradientTexture2D = GradientTexture2D.new()
	tex.gradient = g
	tex.width = 64
	tex.height = 64
	if edge == "top":
		tex.fill_from = Vector2(0, 1)
		tex.fill_to = Vector2(0, 0)
	elif edge == "bottom":
		tex.fill_from = Vector2(0, 0)
		tex.fill_to = Vector2(0, 1)
	elif edge == "left":
		tex.fill_from = Vector2(1, 0)
		tex.fill_to = Vector2(0, 0)
	else:
		tex.fill_from = Vector2(0, 0)
		tex.fill_to = Vector2(1, 0)
	return tex


static func _center_cell(img: Image) -> Image:
	var side: int = mini(img.get_width(), img.get_height())
	var cell: int = int(float(side) / 3.0)
	var ox: int = int(float(img.get_width() - cell * 3) / 2.0) + cell
	var oy: int = int(float(img.get_height() - cell * 3) / 2.0) + cell
	return img.get_region(Rect2i(ox, oy, cell, cell))


static func _key_plate(img: Image) -> Image:
	var w: int = img.get_width()
	var h: int = img.get_height()
	for y in h:
		for x in w:
			var col: Color = img.get_pixel(x, y)
			var mag: float = minf(col.r, col.b) - col.g
			var pink: bool = col.r > 0.4 and col.b > 0.4 and col.g < 0.35
			if (mag > 0.2 and col.g < 0.5) or pink:
				img.set_pixel(x, y, Color(0, 0, 0, 0))
			elif mag > 0.08 and col.g < 0.5 and col.r > 0.25 and col.b > 0.25:
				img.set_pixel(x, y, Color(0, 0, 0, 0))
	return img


static func _opaque_bounds(img: Image) -> Rect2i:
	var w: int = img.get_width()
	var h: int = img.get_height()
	var min_x: int = w
	var min_y: int = h
	var max_x: int = -1
	var max_y: int = -1
	for y in h:
		for x in w:
			if img.get_pixel(x, y).a <= 0.08:
				continue
			if x < min_x:
				min_x = x
			if y < min_y:
				min_y = y
			if x > max_x:
				max_x = x
			if y > max_y:
				max_y = y
	if max_x < min_x:
		return Rect2i(0, 0, w, h)
	var pad: int = 2
	min_x = maxi(0, min_x - pad)
	min_y = maxi(0, min_y - pad)
	max_x = mini(w - 1, max_x + pad)
	max_y = mini(h - 1, max_y + pad)
	return Rect2i(min_x, min_y, max_x - min_x + 1, max_y - min_y + 1)


static func _fit_square(src: Image, side: int) -> Image:
	var bounds: Rect2i = _opaque_bounds(src)
	var crop: Image = src.get_region(bounds)
	var long_side: int = maxi(bounds.size.x, bounds.size.y)
	var square: Image = Image.create(long_side, long_side, false, Image.FORMAT_RGBA8)
	square.fill(Color(0, 0, 0, 0))
	var ox: int = int(float(long_side - bounds.size.x) / 2.0)
	var oy: int = int(float(long_side - bounds.size.y) / 2.0)
	square.blit_rect(crop, Rect2i(0, 0, bounds.size.x, bounds.size.y), Vector2i(ox, oy))
	square.resize(side, side, Image.INTERPOLATE_LANCZOS)
	return square


static func _draw_wounds(img: Image, frac: float) -> void:
	var dmg: float = clampf(1.0 - frac, 0.0, 1.0)
	var bruise: float = clampf((dmg - 0.12) / 0.35, 0.0, 1.0)
	if bruise > 0.0:
		_blob(img, 24, 30, 9, Color(0.42, 0.22, 0.55, 0.45 * bruise))
		_blob(img, 42, 38, 7, Color(0.32, 0.18, 0.48, 0.4 * bruise))
	var cuts: float = clampf((dmg - 0.28) / 0.3, 0.0, 1.0)
	if cuts > 0.0:
		var cut_col: Color = Color(0.55, 0.05, 0.08, 0.15 + 0.75 * cuts)
		_line(img, 16, 26, 34, 36, cut_col)
		if cuts > 0.35:
			_line(img, 34, 18, 50, 30, cut_col)
	var blood: float = clampf((dmg - 0.5) / 0.5, 0.0, 1.0)
	if blood > 0.0:
		var blood_col: Color = Color(0.62, 0.02, 0.05, 0.35 + 0.6 * blood)
		_drip(img, 28, 34, int(6.0 + 16.0 * blood), blood_col)
		_blob(img, 30, 52, int(3.0 + 7.0 * blood), blood_col)
		if blood > 0.45:
			_drip(img, 44, 28, int(8.0 + 12.0 * blood), blood_col)
			_blob(img, 18, 48, int(4.0 + 5.0 * blood), blood_col)


static func _plot(img: Image, x: int, y: int, col: Color) -> void:
	if x < 0 or y < 0 or x >= img.get_width() or y >= img.get_height():
		return
	var under: Color = img.get_pixel(x, y)
	var a: float = col.a + under.a * (1.0 - col.a)
	if a <= 0.001:
		img.set_pixel(x, y, Color(0, 0, 0, 0))
		return
	var rgb: Color = (col * col.a + under * under.a * (1.0 - col.a)) / a
	rgb.a = a
	img.set_pixel(x, y, rgb)


static func _blob(img: Image, cx: int, cy: int, rad: int, col: Color) -> void:
	for y in range(cy - rad, cy + rad + 1):
		for x in range(cx - rad, cx + rad + 1):
			var dx: int = x - cx
			var dy: int = y - cy
			var dist2: int = dx * dx + dy * dy
			if dist2 > rad * rad:
				continue
			var ink: Color = col
			ink.a = col.a * (1.0 - float(dist2) / float(rad * rad + 1))
			_plot(img, x, y, ink)


static func _line(img: Image, x0: int, y0: int, x1: int, y1: int, col: Color) -> void:
	var dx: int = absi(x1 - x0)
	var dy: int = -absi(y1 - y0)
	var sx: int = 1 if x0 < x1 else -1
	var sy: int = 1 if y0 < y1 else -1
	var err: int = dx + dy
	while true:
		_plot(img, x0, y0, col)
		_plot(img, x0 + 1, y0, col)
		if x0 == x1 and y0 == y1:
			return
		var e2: int = 2 * err
		if e2 >= dy:
			err += dy
			x0 += sx
		if e2 <= dx:
			err += dx
			y0 += sy


static func _drip(img: Image, x: int, y0: int, length: int, col: Color) -> void:
	for i in length:
		var ink: Color = col
		ink.a = col.a * (1.0 - float(i) / float(length + 1))
		_plot(img, x, y0 + i, ink)
		if i > 2:
			_plot(img, x + 1, y0 + i, ink)
