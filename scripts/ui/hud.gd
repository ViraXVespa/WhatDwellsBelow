class_name Hud
extends CanvasLayer

var hp_bar: ProgressBar
var mana_bar: ProgressBar
var dash_bar: ProgressBar
var slam_bar: ProgressBar
var channel_bar: ProgressBar
var hp_val: Label
var mana_val: Label
var dash_val: Label
var slam_val: Label
var info: Label
var prompt: Label
var channel_lab: Label
var minimap: Control
var portrait: TextureRect
var boss_wrap: Control
var boss_bar: ProgressBar
var boss_val: Label


func _ready() -> void:
	layer = 20
	var strip := Panel.new()
	strip.position = Vector2(20, 16)
	strip.size = Vector2(560, 228)
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.07, 0.08, 0.11, 0.92)
	sb.border_color = Color(0.45, 0.38, 0.22)
	sb.set_border_width_all(2)
	sb.corner_radius_top_left = 6
	sb.corner_radius_top_right = 6
	sb.corner_radius_bottom_left = 6
	sb.corner_radius_bottom_right = 6
	sb.content_margin_left = 10
	sb.content_margin_top = 10
	strip.add_theme_stylebox_override("panel", sb)
	add_child(strip)

	portrait = TextureRect.new()
	portrait.position = Vector2(14, 14)
	portrait.size = Vector2(88, 88)
	portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	portrait.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	if ResourceLoader.exists("res://assets/sprites/player/down.png"):
		portrait.texture = load("res://assets/sprites/player/down.png")
	strip.add_child(portrait)

	var p_tag := Label.new()
	p_tag.text = "YOU"
	p_tag.position = Vector2(14, 104)
	p_tag.size = Vector2(88, 18)
	p_tag.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	p_tag.add_theme_font_size_override("font_size", 14)
	p_tag.add_theme_color_override("font_color", Color(0.92, 0.82, 0.45))
	strip.add_child(p_tag)

	hp_bar = _bar(Color(0.78, 0.18, 0.18), Vector2(170, 18), Vector2(280, 22))
	strip.add_child(hp_bar)
	strip.add_child(_name_lab("HP", Vector2(112, 16), Color(0.95, 0.45, 0.4)))
	hp_val = _val_lab(Vector2(456, 16))
	strip.add_child(hp_val)

	mana_bar = _bar(Color(0.28, 0.48, 0.92), Vector2(170, 46), Vector2(280, 22))
	strip.add_child(mana_bar)
	strip.add_child(_name_lab("MANA", Vector2(112, 44), Color(0.55, 0.7, 1.0)))
	mana_val = _val_lab(Vector2(456, 44))
	strip.add_child(mana_val)

	dash_bar = _bar(Color(0.25, 0.78, 0.82), Vector2(170, 74), Vector2(160, 22))
	strip.add_child(dash_bar)
	strip.add_child(_name_lab("DASH", Vector2(112, 72), Color(0.5, 0.9, 0.92)))
	dash_val = _val_lab(Vector2(336, 72))
	dash_val.size = Vector2(80, 22)
	strip.add_child(dash_val)

	slam_bar = _bar(Color(0.92, 0.72, 0.18), Vector2(170, 102), Vector2(160, 22))
	strip.add_child(slam_bar)
	strip.add_child(_name_lab("SLAM", Vector2(112, 100), Color(0.95, 0.82, 0.35)))
	slam_val = _val_lab(Vector2(336, 100))
	slam_val.size = Vector2(80, 22)
	strip.add_child(slam_val)

	var binds := Label.new()
	binds.text = "B / Space\nX / Shift"
	binds.position = Vector2(430, 72)
	binds.size = Vector2(120, 52)
	binds.add_theme_font_size_override("font_size", 13)
	binds.add_theme_color_override("font_color", Color(0.7, 0.7, 0.72))
	strip.add_child(binds)

	info = Label.new()
	info.position = Vector2(14, 128)
	info.size = Vector2(532, 52)
	info.add_theme_font_size_override("font_size", 16)
	info.add_theme_color_override("font_color", Color(0.9, 0.88, 0.8))
	strip.add_child(info)

	var hint := Label.new()
	hint.text = "RT / LMB hold-attack    A / E interact    Y / Tab bag    Start / Esc pause"
	hint.position = Vector2(14, 184)
	hint.size = Vector2(532, 36)
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	hint.add_theme_font_size_override("font_size", 13)
	hint.add_theme_color_override("font_color", Color(0.62, 0.6, 0.55))
	strip.add_child(hint)

	prompt = Label.new()
	prompt.position = Vector2(560, 980)
	prompt.size = Vector2(800, 44)
	prompt.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	prompt.add_theme_font_size_override("font_size", 24)
	prompt.add_theme_color_override("font_color", Color(0.95, 0.92, 0.7))
	prompt.add_theme_color_override("font_outline_color", Color(0.05, 0.05, 0.08))
	prompt.add_theme_constant_override("outline_size", 6)
	add_child(prompt)

	var ch_wrap := Control.new()
	ch_wrap.position = Vector2(660, 900)
	ch_wrap.size = Vector2(600, 52)
	add_child(ch_wrap)
	channel_lab = Label.new()
	channel_lab.text = "MINING"
	channel_lab.position = Vector2(0, 0)
	channel_lab.size = Vector2(100, 22)
	channel_lab.add_theme_font_size_override("font_size", 16)
	channel_lab.add_theme_color_override("font_color", Color(0.95, 0.85, 0.4))
	ch_wrap.add_child(channel_lab)
	channel_bar = _bar(Color(0.9, 0.75, 0.25), Vector2(100, 2), Vector2(400, 22))
	ch_wrap.add_child(channel_bar)
	ch_wrap.visible = false
	ch_wrap.name = "ChannelWrap"
	channel_bar.set_meta("wrap", ch_wrap)

	boss_wrap = Control.new()
	boss_wrap.position = Vector2(660, 16)
	boss_wrap.size = Vector2(600, 56)
	boss_wrap.visible = false
	add_child(boss_wrap)
	var bl := Label.new()
	bl.text = "FLOOR GUARDIAN"
	bl.position = Vector2(0, 0)
	bl.size = Vector2(600, 20)
	bl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	bl.add_theme_font_size_override("font_size", 16)
	bl.add_theme_color_override("font_color", Color(0.95, 0.78, 0.28))
	boss_wrap.add_child(bl)
	boss_bar = _bar(Color(0.75, 0.18, 0.22), Vector2(80, 26), Vector2(440, 22))
	boss_wrap.add_child(boss_bar)
	boss_val = _val_lab(Vector2(528, 26))
	boss_wrap.add_child(boss_val)

	minimap = Minimap.new()
	minimap.position = Vector2(1680, 16)
	add_child(minimap)
	var map_tag := Label.new()
	map_tag.text = "MAP"
	map_tag.position = Vector2(1680, 180)
	map_tag.size = Vector2(220, 20)
	map_tag.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	map_tag.add_theme_font_size_override("font_size", 14)
	map_tag.add_theme_color_override("font_color", Color(0.75, 0.72, 0.65))
	add_child(map_tag)


func _name_lab(text: String, pos: Vector2, col: Color) -> Label:
	var l := Label.new()
	l.text = text
	l.position = pos
	l.size = Vector2(56, 22)
	l.add_theme_font_size_override("font_size", 15)
	l.add_theme_color_override("font_color", col)
	return l


func _val_lab(pos: Vector2) -> Label:
	var l := Label.new()
	l.position = pos
	l.size = Vector2(96, 22)
	l.add_theme_font_size_override("font_size", 15)
	l.add_theme_color_override("font_color", Color(0.92, 0.92, 0.9))
	return l


func _bar(col: Color, pos: Vector2, size: Vector2) -> ProgressBar:
	var b := ProgressBar.new()
	b.position = pos
	b.size = size
	b.max_value = 1.0
	b.value = 1.0
	b.show_percentage = false
	var bg := StyleBoxFlat.new()
	bg.bg_color = Color(0.12, 0.12, 0.14, 1)
	bg.corner_radius_top_left = 3
	bg.corner_radius_top_right = 3
	bg.corner_radius_bottom_left = 3
	bg.corner_radius_bottom_right = 3
	bg.content_margin_left = 2
	bg.content_margin_right = 2
	bg.content_margin_top = 2
	bg.content_margin_bottom = 2
	var fill := StyleBoxFlat.new()
	fill.bg_color = col
	fill.corner_radius_top_left = 2
	fill.corner_radius_top_right = 2
	fill.corner_radius_bottom_left = 2
	fill.corner_radius_bottom_right = 2
	b.add_theme_stylebox_override("background", bg)
	b.add_theme_stylebox_override("fill", fill)
	return b


func _process(_delta: float) -> void:
	var p := get_tree().get_first_node_in_group("player") as Player
	if Game.run:
		hp_bar.max_value = Game.run.max_hp
		hp_bar.value = Game.run.hp
		mana_bar.max_value = Game.run.max_mana
		mana_bar.value = Game.run.mana
		hp_val.text = "%d/%d" % [int(Game.run.hp), int(Game.run.max_hp)]
		mana_val.text = "%d/%d" % [int(Game.run.mana), int(Game.run.max_mana)]
		info.text = "Floor %d    Gold %d    Bag %d/28    Axe L%d    Mine L%d    Smith L%d" % [
			Game.run.current_floor,
			Game.run.gold,
			Game.run.bag_count(),
			Game.skill_level("great_axe"),
			Game.skill_level("mining"),
			Game.skill_level("smithing"),
		]
	else:
		hp_bar.max_value = 100
		hp_bar.value = 100
		mana_bar.max_value = 50
		mana_bar.value = 50
		hp_val.text = "100/100"
		mana_val.text = "50/50"
		info.text = "%s    Gold %d    Ore %d    Deepest %d    Axe L%d  Mine L%d  Smith L%d" % [
			Game.DEMO_TOWN,
			Game.save.gold if Game.save else 0,
			Game.save.banked_ore if Game.save else 0,
			Game.save.deepest_floor if Game.save else 1,
			Game.skill_level("great_axe"),
			Game.skill_level("mining"),
			Game.skill_level("smithing"),
		]
	if p:
		dash_bar.max_value = 1.0
		slam_bar.max_value = 1.0
		dash_bar.value = p.dash_ratio()
		slam_bar.value = p.slam_ratio()
		dash_val.text = "READY" if p.dash_cd <= 0.04 else "%.1fs" % p.dash_cd
		slam_val.text = "READY" if p.slam_cd <= 0.04 else "%.1fs" % p.slam_cd
		var wrap: Control = channel_bar.get_meta("wrap") as Control
		var ch := p.channel_ratio()
		if wrap:
			wrap.visible = ch > 0.0
		channel_bar.value = ch
		prompt.text = _prompt_near(p)
	var bosses := get_tree().get_nodes_in_group("boss")
	if boss_wrap:
		boss_wrap.visible = bosses.size() > 0
		if bosses.size() > 0 and bosses[0] is Enemy:
			var b: Enemy = bosses[0]
			boss_bar.max_value = b.max_hp
			boss_bar.value = b.hp
			boss_val.text = "%d/%d" % [int(b.hp), int(b.max_hp)]
	if minimap and minimap.has_method("refresh"):
		minimap.refresh()


func _prompt_near(p: Player) -> String:
	var best := ""
	var best_d := 72.0
	for n in get_tree().get_nodes_in_group("interactable"):
		if n is Interactable:
			var d: float = p.global_position.distance_to(n.global_position)
			if d < best_d:
				best_d = d
				best = (n as Interactable).get_prompt()
	if best != "":
		return "[A / E]  " + best
	return ""
