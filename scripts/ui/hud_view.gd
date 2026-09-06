extends Object

## HUD chrome. Host is the CanvasLayer at scripts/ui/hud.gd.


static func build(host: CanvasLayer) -> void:
	host.strip = Control.new()
	host.add_child(host.strip)
	var bg := ColorRect.new()
	bg.color = Color(0.08, 0.06, 0.05, 0.88)
	bg.size = Vector2(host.STRIP_W, host.STRIP_H)
	host.strip.add_child(bg)
	var edge := ColorRect.new()
	edge.color = Color(0.55, 0.42, 0.22, 1)
	edge.size = Vector2(host.STRIP_W, 5)
	host.strip.add_child(edge)
	host.portrait = TextureRect.new()
	host.portrait.position = Vector2(10, 14)
	host.portrait.size = Vector2(90, 90)
	host.portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	host.portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	host.portrait.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	host.strip.add_child(host.portrait)
	host.hp_fill = meter(host.strip, Vector2(112, 18), Vector2(280, 22), Color(0.72, 0.18, 0.16))
	host.hp_lab = lab(host.strip, Vector2(112, 16), Vector2(280, 26), 18)
	host.pot_icon = TextureRect.new()
	host.pot_icon.position = Vector2(112, 44)
	host.pot_icon.size = Vector2(22, 22)
	host.pot_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	host.pot_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	host.pot_icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	if ResourceLoader.exists("res://assets/ui/icon_potion.png"):
		host.pot_icon.texture = load("res://assets/ui/icon_potion.png")
	host.strip.add_child(host.pot_icon)
	host.pot_fill = meter(host.strip, Vector2(136, 48), Vector2(120, 16), Color(0.45, 0.2, 0.7))
	host.pot_lab = lab(host.strip, Vector2(136, 44), Vector2(160, 22), 14)
	host.dash_fill = meter(host.strip, Vector2(280, 48), Vector2(112, 16), Color(0.3, 0.7, 0.85))
	host.spec_fill = meter(host.strip, Vector2(400, 48), Vector2(112, 16), Color(0.9, 0.55, 0.2))
	lab(host.strip, Vector2(280, 64), Vector2(112, 18), 13).text = "Dash"
	lab(host.strip, Vector2(400, 64), Vector2(112, 18), 13).text = "Special"
	host.lvl = lab(host.strip, Vector2(112, 86), Vector2(280, 28), 22)
	host.floor_lab = lab(host.strip, Vector2(400, 86), Vector2(120, 28), 28)
	host.res = lab(host.strip, Vector2(112, 114), Vector2(410, 24), 18)
	host.shrine_icon = TextureRect.new()
	host.shrine_icon.position = Vector2(10, 140)
	host.shrine_icon.size = Vector2(28, 28)
	host.shrine_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	host.shrine_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	host.shrine_icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	if ResourceLoader.exists("res://assets/sprites/props/shrine.png"):
		host.shrine_icon.texture = load("res://assets/sprites/props/shrine.png")
	host.shrine_icon.visible = false
	host.strip.add_child(host.shrine_icon)
	host.shrine_lab = lab(host.strip, Vector2(42, 142), Vector2(220, 28), 18)
	host.shrine_lab.add_theme_color_override("font_color", Color(1.0, 0.72, 0.35))
	host.food_icon = TextureRect.new()
	host.food_icon.position = Vector2(270, 140)
	host.food_icon.size = Vector2(28, 28)
	host.food_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	host.food_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	host.food_icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	if ResourceLoader.exists("res://assets/sprites/props/hp_orb.png"):
		host.food_icon.texture = load("res://assets/sprites/props/hp_orb.png")
	host.food_icon.visible = false
	host.strip.add_child(host.food_icon)
	host.food_lab = lab(host.strip, Vector2(302, 142), Vector2(220, 28), 18)
	host.food_lab.add_theme_color_override("font_color", Color(0.7, 0.92, 0.5))
	host.prompt_row = HBoxContainer.new()
	host.prompt_row.position = Vector2(10, 168)
	host.prompt_row.size = Vector2(520, 24)
	host.prompt_row.add_theme_constant_override("separation", 8)
	host.prompt_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	host.strip.add_child(host.prompt_row)
	host.toast = lab(host, Vector2(24, 16 + host.STRIP_H + 8), Vector2(540, 28), 20)
	host.toast.add_theme_color_override("font_color", Color(1.0, 0.88, 0.45))
	host.boss_wrap = Control.new()
	host.boss_wrap.size = Vector2(520, 50)
	host.add_child(host.boss_wrap)
	host.boss_fill = meter(host.boss_wrap, Vector2(0, 18), Vector2(360, 18), Color(0.75, 0.15, 0.2))
	host.boss_lab = lab(host.boss_wrap, Vector2(0, 0), Vector2(360, 20), 16)
	host.mini_wrap = Control.new()
	host.add_child(host.mini_wrap)
	host.mini = TextureRect.new()
	host.mini.position = Vector2.ZERO
	host.mini.size = Vector2(host.MINI_W, host.MINI_H)
	host.mini.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	host.mini.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	host.mini.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	host.mini_wrap.add_child(host.mini)
	host.fps_lab = lab(host, Vector2.ZERO, Vector2(140, 28), 16)
	host.look_lab = lab(host, Vector2.ZERO, Vector2(420, 28), 16)
	host.look_lab.add_theme_color_override("font_color", Color(0.95, 0.82, 0.45))
	layout(host)
	load_portrait(host)


static func layout(host: CanvasLayer) -> void:
	var text_sc: float = 1.0
	if App.has_method("ui_text_applied"):
		text_sc = App.ui_text_applied()
	var sc: float = App.hud_scale * text_sc
	var vp := host.get_viewport().get_visible_rect().size
	host.strip.scale = Vector2(sc, sc)
	host.strip.position = Vector2(host.MARGIN, 16)
	host.mini_wrap.scale = Vector2(sc, sc)
	host.mini_wrap.position = Vector2(vp.x - host.MARGIN - host.MINI_W * sc, 16)
	host.toast.scale = Vector2(sc, sc)
	host.toast.position = Vector2(host.MARGIN, 16 + host.STRIP_H * sc + 8)
	host.boss_wrap.scale = Vector2(sc, sc)
	host.boss_wrap.position = Vector2(host.MARGIN, host.toast.position.y + 32 * sc)
	host.fps_lab.scale = Vector2(sc, sc)
	host.fps_lab.position = Vector2(host.mini_wrap.position.x, host.mini_wrap.position.y + host.MINI_H * sc + 4)
	host.look_lab.scale = Vector2(sc, sc)
	host.look_lab.position = Vector2(host.mini_wrap.position.x, host.mini_wrap.position.y + host.MINI_H * sc + 28 * sc)


static func load_portrait(host: CanvasLayer) -> void:
	var p := "res://assets/sprites/player/%s/idle_down.png" % App.character_type
	if p == host.portrait_path:
		return
	host.portrait_path = p
	if ResourceLoader.exists(p):
		host.portrait.texture = load(p)


static func meter(owner: Control, pos: Vector2, sz: Vector2, col: Color) -> ColorRect:
	var back := ColorRect.new()
	back.color = Color(0.12, 0.1, 0.09, 1)
	back.position = pos
	back.size = sz
	owner.add_child(back)
	var fill := ColorRect.new()
	fill.color = col
	fill.position = pos
	fill.size = sz
	owner.add_child(fill)
	return fill


static func lab(owner: Node, pos: Vector2, sz: Vector2, fs: int) -> Label:
	var l := Label.new()
	l.position = pos
	l.size = sz
	l.add_theme_font_size_override("font_size", fs)
	l.add_theme_color_override("font_color", Color(0.92, 0.86, 0.72))
	l.add_theme_color_override("font_outline_color", Color(0.05, 0.03, 0.02))
	l.add_theme_constant_override("outline_size", 5)
	owner.add_child(l)
	return l
