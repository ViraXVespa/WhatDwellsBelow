class_name Hud
extends CanvasLayer

const SkillMath := preload("res://scripts/data/skills.gd")

var hp_bar: ProgressBar
var pot_bar: ProgressBar
var dash_bar: ProgressBar
var slam_bar: ProgressBar
var channel_bar: ProgressBar
var cl_bar: ProgressBar
var hp_val: Label
var pot_val: Label
var dash_val: Label
var slam_val: Label
var cl_val: Label
var shrine_lab: Label
var channel_lab: Label
var prompt: Label
var minimap: Control
var big_map: Control
var map_open := false
var map_tag: Label
var town_help: Panel
var portrait: TextureRect
var boss_wrap: Control
var boss_bar: ProgressBar
var boss_val: Label
var gold_amt: Label
var ore_amt: Label
var bag_amt: Label
var floor_lab: Label
var ore_wrap: Control


func _ready() -> void:
	layer = 20
	var strip := Panel.new()
	strip.position = Vector2(20, 16)
	strip.size = Vector2(560, 248)
	strip.add_theme_stylebox_override("panel", _panel_sb())
	add_child(strip)

	portrait = TextureRect.new()
	portrait.position = Vector2(14, 14)
	portrait.size = Vector2(88, 88)
	portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	portrait.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	var portrait_path := "res://assets/sprites/player/down.png"
	if Game.using_experiment_art():
		portrait_path = "res://assets/3d/player/down.png"
	elif ResourceLoader.exists("res://assets/live/player/down.png"):
		portrait_path = "res://assets/live/player/down.png"
	if ResourceLoader.exists(portrait_path):
		portrait.texture = load(portrait_path)
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

	pot_bar = _bar(Color(0.82, 0.28, 0.55), Vector2(170, 46), Vector2(280, 22))
	strip.add_child(pot_bar)
	var pot_icon := TextureRect.new()
	pot_icon.position = Vector2(112, 42)
	pot_icon.size = Vector2(48, 28)
	pot_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	pot_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	pot_icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	if ResourceLoader.exists("res://assets/ui/icon_potion.png"):
		pot_icon.texture = load("res://assets/ui/icon_potion.png")
	strip.add_child(pot_icon)
	pot_val = _val_lab(Vector2(456, 44))
	strip.add_child(pot_val)

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

	cl_bar = _bar(Color(0.85, 0.72, 0.28), Vector2(170, 130), Vector2(280, 18))
	strip.add_child(cl_bar)
	strip.add_child(_name_lab("CL", Vector2(112, 128), Color(0.95, 0.82, 0.4)))
	cl_val = _val_lab(Vector2(456, 128))
	strip.add_child(cl_val)

	var widgets := HBoxContainer.new()
	widgets.position = Vector2(14, 168)
	widgets.size = Vector2(532, 36)
	widgets.add_theme_constant_override("separation", 8)
	strip.add_child(widgets)
	floor_lab = Label.new()
	floor_lab.add_theme_font_size_override("font_size", 16)
	floor_lab.add_theme_color_override("font_color", Color(0.9, 0.88, 0.8))
	widgets.add_child(floor_lab)
	widgets.add_child(_stat_box("res://assets/ui/icon_gold.png", gold_amt))
	ore_wrap = _stat_box("res://assets/ui/icon_ore.png", ore_amt)
	widgets.add_child(ore_wrap)
	var bag_wrap := Panel.new()
	bag_wrap.custom_minimum_size = Vector2(92, 32)
	var bb := StyleBoxFlat.new()
	bb.bg_color = Color(0.12, 0.12, 0.14, 0.95)
	bb.border_color = Color(0.45, 0.38, 0.22)
	bb.set_border_width_all(1)
	bag_wrap.add_theme_stylebox_override("panel", bb)
	bag_amt = Label.new()
	bag_amt.position = Vector2(8, 4)
	bag_amt.size = Vector2(80, 24)
	bag_amt.add_theme_font_size_override("font_size", 15)
	bag_wrap.add_child(bag_amt)
	widgets.add_child(bag_wrap)

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
	map_tag = Label.new()
	map_tag.text = "MAP"
	map_tag.position = Vector2(1680, 180)
	map_tag.size = Vector2(220, 20)
	map_tag.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	map_tag.add_theme_font_size_override("font_size", 14)
	map_tag.add_theme_color_override("font_color", Color(0.75, 0.72, 0.65))
	add_child(map_tag)

	town_help = Panel.new()
	town_help.position = Vector2(1680, 16)
	town_help.size = Vector2(220, 168)
	town_help.add_theme_stylebox_override("panel", _panel_sb())
	var th := Label.new()
	th.text = "Placeholdia\n\nTalk to people.\nUse the crystal\nto delve.\nPause for bag\nand skills.\nRead the board."
	th.position = Vector2(12, 10)
	th.size = Vector2(196, 148)
	th.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	th.add_theme_font_size_override("font_size", 15)
	th.add_theme_color_override("font_color", Color(0.88, 0.84, 0.72))
	town_help.add_child(th)
	add_child(town_help)

	shrine_lab = Label.new()
	shrine_lab.position = Vector2(20, 276)
	shrine_lab.size = Vector2(520, 28)
	shrine_lab.add_theme_font_size_override("font_size", 18)
	shrine_lab.add_theme_color_override("font_color", Color(0.95, 0.82, 0.4))
	add_child(shrine_lab)
	var pres := Game.presentation()
	if pres != "live":
		var view_lab := Label.new()
		view_lab.position = Vector2(760, 16)
		view_lab.size = Vector2(400, 22)
		view_lab.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		view_lab.add_theme_font_size_override("font_size", 14)
		view_lab.add_theme_color_override("font_color", Color(0.95, 0.82, 0.45))
		view_lab.add_theme_color_override("font_outline_color", Color(0.05, 0.05, 0.08))
		view_lab.add_theme_constant_override("outline_size", 4)
		if pres == "classic_2d":
			view_lab.text = "ARCHIVE · Classic 2D"
		else:
			view_lab.text = "ARCHIVE · Art experiment"
		add_child(view_lab)
	big_map = Minimap.new()
	big_map.position = Vector2(480, 220)
	big_map.size = Vector2(960, 640)
	big_map.custom_minimum_size = Vector2(960, 640)
	big_map.visible = false
	add_child(big_map)


func _panel_sb() -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.07, 0.08, 0.11, 0.92)
	sb.border_color = Color(0.45, 0.38, 0.22)
	sb.set_border_width_all(2)
	sb.corner_radius_top_left = 6
	sb.corner_radius_top_right = 6
	sb.corner_radius_bottom_left = 6
	sb.corner_radius_bottom_right = 6
	return sb


func _stat_box(icon_path: String, amt_ref: Label) -> Control:
	var wrap := Panel.new()
	wrap.custom_minimum_size = Vector2(108, 32)
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.12, 0.12, 0.14, 0.95)
	sb.border_color = Color(0.45, 0.38, 0.22)
	sb.set_border_width_all(1)
	wrap.add_theme_stylebox_override("panel", sb)
	var ic := TextureRect.new()
	ic.position = Vector2(4, 2)
	ic.size = Vector2(28, 28)
	ic.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	ic.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	ic.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	if ResourceLoader.exists(icon_path):
		ic.texture = load(icon_path)
	wrap.add_child(ic)
	var lab := Label.new()
	lab.position = Vector2(34, 4)
	lab.size = Vector2(70, 24)
	lab.add_theme_font_size_override("font_size", 16)
	lab.add_theme_color_override("font_color", Color(0.95, 0.9, 0.7))
	wrap.add_child(lab)
	if icon_path.ends_with("gold.png"):
		gold_amt = lab
	else:
		ore_amt = lab
	return wrap


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
	var p := get_tree().get_first_node_in_group("player")
	var in_town := not Game.in_dungeon
	if minimap:
		minimap.visible = not in_town
	if map_tag:
		map_tag.visible = not in_town
	if town_help:
		town_help.visible = in_town
	if ore_wrap:
		ore_wrap.visible = in_town
	if Game.run:
		hp_bar.max_value = Game.run.max_hp
		hp_bar.value = Game.run.hp
		hp_val.text = "%d/%d" % [int(Game.run.hp), int(Game.run.max_hp)]
		var pcd := Game.run.potion_cd
		var pmax := 8.0
		if Game.run.potion:
			pmax = maxf(0.5, Game.run.potion.potion_cd)
		pot_bar.max_value = pmax
		pot_bar.value = pmax - pcd
		if Game.run.potion == null:
			pot_val.text = "NONE"
		elif pcd <= 0.04:
			pot_val.text = "READY"
		else:
			pot_val.text = "%.1fs" % pcd
		if shrine_lab:
			if Game.run.shrine_buff_t > 0.0:
				shrine_lab.text = "Shrine +20% dmg   %.0fs" % Game.run.shrine_buff_t
			else:
				shrine_lab.text = ""
		if gold_amt:
			gold_amt.text = str(Game.run.gold)
		if bag_amt:
			bag_amt.text = "%d/28" % Game.run.bag_count()
		if floor_lab:
			floor_lab.text = "F%d" % Game.run.current_floor
	else:
		var mx: float = 100.0 + SkillMath.hitpoints_bonus(Game.skill_level("hitpoints"))
		hp_bar.max_value = mx
		hp_bar.value = mx
		hp_val.text = "%d/%d" % [int(mx), int(mx)]
		if pot_val:
			pot_val.text = "—"
		if shrine_lab:
			shrine_lab.text = ""
		if gold_amt:
			gold_amt.text = str(Game.save.gold if Game.save else 0)
		if ore_amt:
			ore_amt.text = str(Game.save.banked_ore if Game.save else 0)
		if bag_amt:
			bag_amt.text = "town"
		if floor_lab:
			floor_lab.text = Game.DEMO_TOWN
	var cl := Game.combat_level()
	var clf := Game.combat_level_precise()
	cl_bar.max_value = 1.0
	cl_bar.value = clf - float(cl)
	cl_val.text = str(cl)
	if p and p.has_method("dash_ratio") and p.has_method("slam_ratio"):
		dash_bar.max_value = 1.0
		slam_bar.max_value = 1.0
		dash_bar.value = p.dash_ratio()
		slam_bar.value = p.slam_ratio()
		dash_val.text = "READY" if float(p.get("dash_cd")) <= 0.04 else "%.1fs" % float(p.get("dash_cd"))
		slam_val.text = "READY" if float(p.get("slam_cd")) <= 0.04 else "%.1fs" % float(p.get("slam_cd"))
		var wrap: Control = channel_bar.get_meta("wrap") as Control
		var ch := float(p.channel_ratio()) if p.has_method("channel_ratio") else 0.0
		if wrap:
			wrap.visible = ch > 0.0
		channel_bar.value = ch
		prompt.text = _prompt_near(p)
	var bosses := get_tree().get_nodes_in_group("boss")
	if boss_wrap:
		boss_wrap.visible = bosses.size() > 0
		if bosses.size() > 0:
			var b = bosses[0]
			var bhp := float(b.get("hp"))
			var bmax := float(b.get("max_hp"))
			boss_bar.max_value = bmax
			boss_bar.value = bhp
			boss_val.text = "%d/%d" % [int(bhp), int(bmax)]
	if minimap and minimap.visible and minimap.has_method("refresh"):
		minimap.refresh()
	if map_open and big_map and big_map.has_method("refresh"):
		big_map.refresh()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("map_view") and Game.in_dungeon and not get_tree().paused:
		map_open = not map_open
		if big_map:
			big_map.visible = map_open
		get_viewport().set_input_as_handled()


func _prompt_near(p: Node) -> String:
	var best := ""
	var origin := Vector2.ZERO
	var live3 := Game.using_3d()
	if live3:
		if not (p is Node3D):
			return ""
		origin = Vector2((p as Node3D).global_position.x, (p as Node3D).global_position.z)
	elif p is Node2D:
		origin = (p as Node2D).global_position
	else:
		return ""
	var best_d := 1.13 if live3 else 72.0
	for n in get_tree().get_nodes_in_group("interactable"):
		var np := Vector2.INF
		if live3:
			if n is Node3D:
				np = Vector2((n as Node3D).global_position.x, (n as Node3D).global_position.z)
			else:
				continue
		elif n is Node2D:
			np = (n as Node2D).global_position
		else:
			continue
		var d: float = origin.distance_to(np)
		if d < best_d:
			best_d = d
			if n.has_method("get_prompt"):
				best = str(n.get_prompt())
	return best
