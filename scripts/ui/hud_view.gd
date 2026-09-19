extends Object

const ThemeS := preload("res://scripts/ui/theme.gd")

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
	host.strip.add_child(host.pot_icon)
	host.pot_lab = lab(host.strip, Vector2(140, 42), Vector2(80, 26), 16)
	host.stam_fill = meter(host.strip, Vector2(230, 48), Vector2(160, 14), Color(0.2, 0.55, 0.85))
	host.xp_fill = meter(host.strip, Vector2(112, 72), Vector2(280, 10), Color(0.55, 0.75, 0.25))
	host.floor_lab = lab(host.strip, Vector2(410, 16), Vector2(200, 26), 18)
	host.gold_lab = lab(host.strip, Vector2(410, 42), Vector2(200, 26), 16)
	host.buff_lab = lab(host.strip, Vector2(112, 88), Vector2(500, 24), 14)


static func meter(owner: Node, pos: Vector2, sz: Vector2, col: Color) -> ColorRect:
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
	l.add_theme_color_override("font_outline_color", ThemeS.PROMPT_OUTLINE)
	l.add_theme_constant_override("outline_size", ThemeS.PROMPT_OUTLINE_SIZE)
	owner.add_child(l)
	return l
