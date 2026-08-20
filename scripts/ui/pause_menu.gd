class_name PauseMenu
extends CanvasLayer

var panel: Panel
var open := false
var page := "inv"
var body: VBoxContainer
var list: ItemList
var hint: Label
var skills_lab: Label
var tab_btns: Dictionary = {}
const TAB_ORDER := ["inv", "skills", "sys"]


func _ready() -> void:
	layer = 40
	process_mode = Node.PROCESS_MODE_ALWAYS
	panel = Panel.new()
	panel.visible = false
	panel.position = Vector2(420, 60)
	panel.size = Vector2(1080, 920)
	var psb := StyleBoxFlat.new()
	psb.bg_color = Color(0.07, 0.08, 0.12, 0.96)
	psb.border_color = Color(0.55, 0.45, 0.26)
	psb.set_border_width_all(3)
	psb.corner_radius_top_left = 10
	psb.corner_radius_top_right = 10
	psb.corner_radius_bottom_left = 10
	psb.corner_radius_bottom_right = 10
	psb.shadow_color = Color(0, 0, 0, 0.45)
	psb.shadow_size = 12
	panel.add_theme_stylebox_override("panel", psb)
	add_child(panel)
	var v := VBoxContainer.new()
	v.set_anchors_preset(Control.PRESET_FULL_RECT)
	v.offset_left = 28
	v.offset_top = 20
	v.offset_right = -28
	v.offset_bottom = -20
	v.add_theme_constant_override("separation", 8)
	panel.add_child(v)
	var title := Label.new()
	title.text = "Paused"
	title.add_theme_font_size_override("font_size", 30)
	title.add_theme_color_override("font_color", Color(0.95, 0.86, 0.55))
	v.add_child(title)
	var tab_hint := Label.new()
	tab_hint.text = "LB / RB  cycle pages"
	tab_hint.add_theme_font_size_override("font_size", 14)
	tab_hint.add_theme_color_override("font_color", Color(0.65, 0.62, 0.58))
	v.add_child(tab_hint)
	var tabs := HBoxContainer.new()
	tabs.add_theme_constant_override("separation", 8)
	v.add_child(tabs)
	tab_btns["inv"] = _tab_btn("Inventory", "inv")
	tab_btns["skills"] = _tab_btn("Skills", "skills")
	tab_btns["sys"] = _tab_btn("System", "sys")
	for k in TAB_ORDER:
		tabs.add_child(tab_btns[k])
	body = VBoxContainer.new()
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.add_theme_constant_override("separation", 8)
	v.add_child(body)
	v.add_child(_btn("Resume", _close))
	var d := Button.new()
	d.name = "Dispel"
	d.text = "Dispel Avatar (Return to Town)"
	d.custom_minimum_size = Vector2(0, 48)
	d.pressed.connect(_dispel)
	v.add_child(d)
	PadUi.wire(panel)
	_show("inv")


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("pause"):
		if _blocking_modal():
			return
		if open:
			_close()
		else:
			_open()
		get_viewport().set_input_as_handled()
		return
	if open and event.is_action_pressed("ui_cancel"):
		_close()
		get_viewport().set_input_as_handled()
		return
	if open and event.is_action_pressed("tab_right"):
		_cycle_tab(1)
		get_viewport().set_input_as_handled()
	elif open and event.is_action_pressed("tab_left"):
		_cycle_tab(-1)
		get_viewport().set_input_as_handled()


func _blocking_modal() -> bool:
	for g in ["shop_ui", "extract_ui", "anvil_ui", "loadout_ui"]:
		for n in get_tree().get_nodes_in_group(g):
			var p = n.get("panel")
			if p is Control and (p as Control).visible:
				return true
	return not get_tree().get_nodes_in_group("wdb_modal").is_empty()


func _open() -> void:
	open = true
	panel.visible = true
	get_tree().paused = true
	var d: Button = panel.find_child("Dispel", true, false)
	if d:
		d.visible = Game.in_dungeon
	_show(page)
	PadUi.focus_first(panel)


func _close() -> void:
	open = false
	panel.visible = false
	get_tree().paused = false


func _dispel() -> void:
	_close()
	Game.end_run(true)


func _cycle_tab(dir: int) -> void:
	var cur := TAB_ORDER.find(page)
	if cur < 0:
		cur = 0
	_show(TAB_ORDER[(cur + dir + TAB_ORDER.size()) % TAB_ORDER.size()])


func _tab_btn(text: String, id: String) -> Button:
	var b := _btn(text, func(): _show(id), 0, 44)
	b.toggle_mode = true
	return b


func _paint_tabs() -> void:
	for k in tab_btns.keys():
		var b: Button = tab_btns[k]
		b.set_pressed_no_signal(k == page)


func _show(p: String) -> void:
	if p == "wipe":
		page = "wipe"
	elif TAB_ORDER.has(p):
		page = p
	for c in body.get_children():
		body.remove_child(c)
		c.queue_free()
	list = null
	hint = null
	skills_lab = null
	if p == "inv":
		_build_inv()
	elif p == "skills":
		_build_skills()
	elif p == "wipe":
		_build_wipe()
	else:
		_build_sys()
	_paint_tabs()
	PadUi.wire(body)


func _build_inv() -> void:
	hint = Label.new()
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	hint.add_theme_font_size_override("font_size", 16)
	body.add_child(hint)
	list = ItemList.new()
	list.custom_minimum_size = Vector2(0, 420)
	body.add_child(list)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	body.add_child(row)
	if Game.run:
		row.add_child(_btn("Equip", _equip_sel, 140, 44))
		row.add_child(_btn("Unequip to bag", _unequip_sel, 180, 44))
		row.add_child(_btn("Drop", _drop_sel, 120, 44))
	_refresh_inv()


func _refresh_inv() -> void:
	if list == null:
		return
	list.clear()
	if Game.run == null:
		if hint:
			hint.text = "No bag in town. Loadout is on the crystal."
		return
	var r := Game.run
	hint.text = "Equipped:\n  Axe  %s\n  Pick %s\n  Pot  %s\n  Head %s\n  Body %s\n  Legs %s\nDef %.0f   Bag %d/28\nSelect a bag row, then Equip / Drop. Drop equipped from the top lines." % [
		_nm(r.weapon), _nm(r.tool), _nm(r.potion), _nm(r.armor_head), _nm(r.armor_body), _nm(r.armor_legs),
		r.total_defense(), r.bag_count()
	]
	_add_eq("weapon", r.weapon)
	_add_eq("tool", r.tool)
	_add_eq("potion", r.potion)
	_add_eq("head", r.armor_head)
	_add_eq("body", r.armor_body)
	_add_eq("legs", r.armor_legs)
	for i in RunState.BAG_SIZE:
		var it: ItemData = r.bag[i]
		if it:
			list.add_item("%02d  %s  %s" % [i + 1, it.full_name(), it.stat_line()])
			list.set_item_metadata(list.item_count - 1, {"kind": "bag", "i": i})
		else:
			list.add_item("%02d  —" % (i + 1))
			list.set_item_metadata(list.item_count - 1, {"kind": "bag", "i": i})


func _add_eq(slot: String, it: ItemData) -> void:
	var label := slot.capitalize()
	if it:
		list.add_item("[EQ %s]  %s  %s" % [label, it.full_name(), it.stat_line()])
	else:
		list.add_item("[EQ %s]  empty" % label)
	list.set_item_metadata(list.item_count - 1, {"kind": "eq", "slot": slot})


func _nm(it: ItemData) -> String:
	return it.full_name() if it else "—"


func _sel() -> Dictionary:
	if list == null or list.get_selected_items().is_empty():
		return {}
	var m = list.get_item_metadata(list.get_selected_items()[0])
	return m if m is Dictionary else {}


func _equip_sel() -> void:
	if Game.run == null:
		return
	var m := _sel()
	if m.get("kind") != "bag":
		return
	var it: ItemData = Game.run.bag[int(m.i)]
	if it == null:
		return
	var slot := ""
	match it.kind:
		ItemData.Kind.WEAPON:
			slot = "weapon"
		ItemData.Kind.TOOL:
			slot = "tool"
		ItemData.Kind.POTION:
			slot = "potion"
		ItemData.Kind.ARMOR:
			slot = it.armor_slot
	if slot == "":
		return
	var old_cd := Game.run.potion_cd
	Game.run.equip_from_bag(int(m.i), slot)
	if slot == "potion" and Game.run.potion:
		var remain := old_cd
		if remain > 0.0 and Game.run.potion.potion_cdr > 0.0:
			Game.run.potion_cd = remain * (1.0 - Game.run.potion.potion_cdr)
		else:
			Game.run.potion_cd = remain
	Game.bag_changed.emit()
	_refresh_inv()


func _unequip_sel() -> void:
	if Game.run == null:
		return
	var m := _sel()
	if m.get("kind") != "eq":
		return
	var it := Game.run.drop_equipped(str(m.slot))
	if it == null:
		return
	if not Game.run.add_item(it):
		Game.give_or_drop(it, _player_pos())
	Game.bag_changed.emit()
	_refresh_inv()


func _drop_sel() -> void:
	if Game.run == null:
		return
	var m := _sel()
	var it: ItemData = null
	if m.get("kind") == "eq":
		it = Game.run.drop_equipped(str(m.slot))
	elif m.get("kind") == "bag":
		it = Game.run.remove_item_at(int(m.i), -1)
	if it == null:
		return
	var scene := get_tree().current_scene
	if scene:
		var drop = (load("res://scripts/entities/ground_drop.gd") as GDScript).new()
		drop.position = _player_pos() + Vector2(randf_range(-18, 18), randf_range(-12, 12))
		scene.add_child(drop)
		drop.setup(it)
	Game.bag_changed.emit()
	_refresh_inv()


func _player_pos() -> Vector2:
	var p := get_tree().get_first_node_in_group("player")
	return p.global_position if p is Node2D else Vector2.ZERO


func _build_skills() -> void:
	skills_lab = Label.new()
	skills_lab.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	skills_lab.add_theme_font_size_override("font_size", 20)
	body.add_child(skills_lab)
	var lines: PackedStringArray = []
	lines.append("Combat level %d   (Great Axe + Strength + Defense + Hitpoints)" % Game.combat_level())
	lines.append("")
	for sk in ["great_axe", "strength", "defense", "hitpoints", "mining", "smithing"]:
		var xp := Game.skill_xp(sk)
		var lv := Skills.level_from_xp(xp)
		var into := xp - Skills.xp_for_level(lv)
		var need := Skills.xp_to_next(lv)
		lines.append("%s  Lv %d    %.0f / %.0f to next" % [Skills.label(sk), lv, into, need])
	lines.append("\n2% of this-run XP is kept on wake. Dungeon is the real grind.")
	if Game.run:
		lines.append("This dream:  axe %.0f  str %.0f  def %.0f  hp %.0f  mine %.0f  smith %.0f" % [
			Game.run.great_axe_xp_run, Game.run.strength_xp_run, Game.run.defense_xp_run,
			Game.run.hitpoints_xp_run, Game.run.mining_xp_run, Game.run.smithing_xp_run
		])
		if not Game.run.artifact_ids.is_empty():
			lines.append("Artifacts this run:")
			for id in Game.run.artifact_ids:
				var art_s = load("res://scripts/data/artifacts.gd")
				var row: Dictionary = art_s.by_id(str(id))
				lines.append("  · %s" % str(row.get("name", id)))
	skills_lab.text = "\n".join(lines)


func _build_sys() -> void:
	body.add_child(_slider_row("Music", "music"))
	body.add_child(_slider_row("SFX", "sfx"))
	body.add_child(_slider_row("Zoom", "zoom"))
	var cred := Label.new()
	cred.text = "Dungeon: 8-Bit — ViraXVespa"
	cred.add_theme_font_size_override("font_size", 15)
	cred.add_theme_color_override("font_color", Color(0.7, 0.72, 0.74))
	body.add_child(cred)
	var pat := LinkButton.new()
	pat.text = "Support on Patreon"
	pat.uri = Game.PATREON_URL
	pat.underline = LinkButton.UNDERLINE_MODE_ON_HOVER
	pat.add_theme_font_size_override("font_size", 20)
	pat.add_theme_color_override("font_color", Color(0.95, 0.55, 0.42))
	body.add_child(pat)
	var wipe_n := Label.new()
	wipe_n.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	wipe_n.text = "This browser keeps your diver in user://. Clearing it deletes XP, gold, recipes, and holds. Cannot undo."
	wipe_n.add_theme_font_size_override("font_size", 16)
	wipe_n.add_theme_color_override("font_color", Color(0.85, 0.72, 0.62))
	body.add_child(wipe_n)
	body.add_child(_btn("Delete save data…", func(): _show("wipe")))


func _build_wipe() -> void:
	var lab := Label.new()
	lab.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	lab.text = "Really delete this diver?\n\nXP, gold, forged holds, and recipes are gone. Next launch is a fresh adventurer. This cannot be undone."
	lab.add_theme_font_size_override("font_size", 20)
	lab.add_theme_color_override("font_color", Color(0.95, 0.55, 0.42))
	body.add_child(lab)
	body.add_child(_btn("Yes — delete save and return to title", func():
		_close()
		Game.wipe_save()
	))
	body.add_child(_btn("No — keep my diver", func(): _show("sys")))


func _slider_row(label: String, kind: String) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	var lab := Label.new()
	lab.text = label
	lab.custom_minimum_size = Vector2(90, 0)
	lab.add_theme_font_size_override("font_size", 18)
	row.add_child(lab)
	var sl := HSlider.new()
	sl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sl.custom_minimum_size = Vector2(280, 28)
	if kind == "zoom":
		sl.min_value = 1.0
		sl.max_value = 1.75
		sl.step = 0.05
		sl.value = Game.save.cam_zoom if Game.save else 1.0
	elif kind == "music":
		sl.min_value = 0.0
		sl.max_value = 1.0
		sl.step = 0.05
		sl.value = Game.save.music_vol if Game.save else 0.7
	else:
		sl.min_value = 0.0
		sl.max_value = 1.0
		sl.step = 0.05
		sl.value = Game.save.sfx_vol if Game.save else 0.85
	sl.value_changed.connect(func(v: float): _slide(kind, v))
	row.add_child(sl)
	return row


func _slide(kind: String, v: float) -> void:
	if Game.save == null:
		return
	if kind == "zoom":
		Game.set_cam_zoom(v)
		return
	if kind == "music":
		Game.save.music_vol = v
	else:
		Game.save.sfx_vol = v
	Game.save.write()
	Sfx.apply_volumes()


func _btn(text: String, cb: Callable, w: int = 0, h: int = 52) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(w, h)
	b.pressed.connect(cb)
	var nsb := StyleBoxFlat.new()
	nsb.bg_color = Color(0.16, 0.15, 0.18, 1)
	nsb.border_color = Color(0.45, 0.38, 0.22)
	nsb.set_border_width_all(1)
	nsb.corner_radius_top_left = 4
	nsb.corner_radius_top_right = 4
	nsb.corner_radius_bottom_left = 4
	nsb.corner_radius_bottom_right = 4
	var hsb := nsb.duplicate() as StyleBoxFlat
	hsb.bg_color = Color(0.28, 0.24, 0.16, 1)
	var psb := nsb.duplicate() as StyleBoxFlat
	psb.bg_color = Color(0.42, 0.34, 0.16, 1)
	b.add_theme_stylebox_override("normal", nsb)
	b.add_theme_stylebox_override("hover", hsb)
	b.add_theme_stylebox_override("pressed", psb)
	b.add_theme_stylebox_override("focus", hsb)
	b.add_theme_color_override("font_color", Color(0.92, 0.88, 0.78))
	return b
