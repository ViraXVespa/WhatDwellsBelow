extends CanvasLayer

const ThemeS := preload("res://scripts/ui/theme.gd")
const CatalogS := preload("res://scripts/data/catalog.gd")
const T := preload("res://scripts/data/tunables.gd")

var open := false
var tab := 0
var box: VBoxContainer
var tabs: HBoxContainer
var status: Label
var focus_btn: Button
var pending := false
var pending_id := ""
var pending_fn: Callable
var rebind_action := ""
var sys_page := "main"


func _ready() -> void:
	layer = 55
	visible = false
	process_mode = Node.PROCESS_MODE_ALWAYS
	var dim := ColorRect.new()
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.color = Color(0.03, 0.02, 0.02, 0.78)
	add_child(dim)
	var panel := ColorRect.new()
	panel.color = Color(0.13, 0.1, 0.08, 0.96)
	panel.position = Vector2(220, 40)
	panel.size = Vector2(1480, 1000)
	add_child(panel)
	var edge := ColorRect.new()
	edge.color = Color(0.55, 0.42, 0.22, 1)
	edge.position = Vector2(220, 40)
	edge.size = Vector2(1480, 8)
	add_child(edge)
	tabs = HBoxContainer.new()
	tabs.position = Vector2(244, 60)
	tabs.size = Vector2(1432, 56)
	tabs.add_theme_constant_override("separation", 12)
	add_child(tabs)
	var scroll := ScrollContainer.new()
	scroll.position = Vector2(244, 128)
	scroll.size = Vector2(1432, 880)
	add_child(scroll)
	box = VBoxContainer.new()
	box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	box.add_theme_constant_override("separation", 8)
	scroll.add_child(box)


func toggle() -> void:
	if open:
		close_ui()
	else:
		show_menu()


func show_menu() -> void:
	open = true
	visible = true
	App.ui_open = true
	get_tree().paused = true
	tab = 0
	sys_page = "main"
	_rebuild()


func close_ui() -> void:
	open = false
	visible = false
	pending = false
	pending_id = ""
	rebind_action = ""
	sys_page = "main"
	App.ui_open = false
	get_tree().paused = false
	App.save_now()
	App.wake_web_pad()


func _rebuild() -> void:
	for c in tabs.get_children():
		c.queue_free()
	for c in box.get_children():
		c.queue_free()
	focus_btn = null
	status = null
	var names := ["Inventory", "Skills", "System"]
	for i in 3:
		var ii := i
		var b := ThemeS.btn(names[i], func(): tab = ii; _rebuild())
		if i == tab:
			b.add_theme_color_override("font_color", Color(1, 0.92, 0.45))
		tabs.add_child(b)
		if focus_btn == null:
			focus_btn = b
	match tab:
		0:
			_inv()
		1:
			_skills()
		_:
			_system()
	call_deferred("_focus")


func _focus() -> void:
	if focus_btn:
		focus_btn.grab_focus()


func _inv() -> void:
	box.add_child(ThemeS.lab("Bag %d/%d" % [App.prog.bag_count(), int(App.bal.bag_cap)], 22, Color(0.92, 0.84, 0.62)))
	status = ThemeS.lab("", 20, Color(0.95, 0.8, 0.45))
	box.add_child(status)
	box.add_child(ThemeS.lab("Equipment", 20, Color(0.95, 0.82, 0.5)))
	for s in App.prog.SLOTS:
		var eq_it: Dictionary = App.prog.slots.get(s, {})
		var nm := str(eq_it.get("name", "—"))
		var slot := str(s)
		var eq_row := HBoxContainer.new()
		eq_row.add_theme_constant_override("separation", 8)
		var eq_lab := ThemeS.btn("%s: %s" % [slot, nm], func(): _st(nm))
		eq_lab.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		eq_row.add_child(eq_lab)
		if not eq_it.is_empty():
			eq_row.add_child(ThemeS.btn("Unequip", func(): _st(App.prog.unequip_slot(slot)); _rebuild()))
			eq_row.add_child(ThemeS.btn("Drop", func(): _confirm(func(): _st(App.prog.drop_slot(slot)); _rebuild(), "drop_slot_" + slot)))
		box.add_child(eq_row)
	box.add_child(ThemeS.btn("Use potion", func(): _st(App.prog.use_potion())))
	box.add_child(ThemeS.btn("Use food", func(): _st(App.prog.use_food())))
	for bag_it in App.prog.bag:
		var uid := int(bag_it.uid)
		var line := "%s  ·  %s" % [bag_it.name, bag_it.desc]
		if str(bag_it.kind) == "artifact":
			line += "\n" + App.prog.set_bonus_text(str(bag_it.set))
		var bag_row := HBoxContainer.new()
		bag_row.add_theme_constant_override("separation", 8)
		var use_b := ThemeS.btn(line, func(): _inv_act(uid))
		use_b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		bag_row.add_child(use_b)
		bag_row.add_child(ThemeS.btn("Drop", func(): _confirm(func(): _drop(uid), "drop_bag_%d" % uid)))
		box.add_child(bag_row)
	if not App.in_dungeon and App.prog.bank_items.size() > 0:
		box.add_child(ThemeS.lab("Mailed stash — safe in Placeholdia. Forge at the anvil.", 18, Color(0.75, 0.85, 0.7)))
		for stash_it in App.prog.bank_items:
			var stash_uid := int(stash_it.uid)
			var stash_row := HBoxContainer.new()
			stash_row.add_theme_constant_override("separation", 8)
			var stash_lab := ThemeS.btn("%s  ·  mailed" % str(stash_it.name), func(): _st("Forge this at the anvil."))
			stash_lab.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			stash_row.add_child(stash_lab)
			stash_row.add_child(ThemeS.btn("Discard", func(): _confirm(func(): _st(App.prog.drop_stash(stash_uid)); _rebuild(), "stash_%d" % stash_uid)))
			box.add_child(stash_row)
	box.add_child(ThemeS.btn("Close  (B)", func(): close_ui()))


func _inv_act(uid: int) -> void:
	var it := {}
	for b in App.prog.bag:
		if int(b.uid) == uid:
			it = b
			break
	if it.is_empty():
		_st("Gone.")
		return
	if str(it.kind) == "potion" or str(it.kind) == "food":
		_st(App.prog.use_from_bag(uid))
	else:
		_st(App.prog.equip_uid(uid))
	_rebuild()


func _drop(uid: int) -> void:
	_st(App.prog.drop_uid(uid))
	_rebuild()


func _skills() -> void:
	box.add_child(ThemeS.lab("Combat Level %d" % App.prog.combat_lv(), 24, Color(0.95, 0.82, 0.5)))
	var names := {
		"axe": "Great Axe", "staff": "Staff", "bow": "Longbow", "str": "Strength", "mag": "Magic",
		"rng": "Ranged", "def": "Defense", "hp": "Hitpoints", "mine": "Mining", "wood": "Woodcutting", "smith": "Smithing",
	}
	for id in App.prog.SKILLS:
		var runx := float(App.prog.skills_run.get(id, 0.0))
		var perm := float(App.prog.skills_perm.get(id, 0.0))
		var lv := App.prog.skill_lv(id)
		var span := maxf(1.0, App.bal.xp_level)
		var into := fmod(runx + perm, span)
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 12)
		row.add_child(ThemeS.lab("%s  Lv %d" % [names.get(id, id), lv], 18, Color(0.9, 0.84, 0.7)))
		var back := ColorRect.new()
		back.custom_minimum_size = Vector2(360, 16)
		back.color = Color(0.12, 0.1, 0.08)
		var fill := ColorRect.new()
		fill.size = Vector2(360.0 * (into / span), 16)
		fill.color = Color(0.55, 0.42, 0.22)
		back.add_child(fill)
		row.add_child(back)
		row.add_child(ThemeS.lab("run %.0f   perm %.0f" % [runx, perm], 16, Color(0.75, 0.7, 0.6)))
		box.add_child(row)
	box.add_child(ThemeS.btn("Close  (B)", func(): close_ui()))


func _system() -> void:
	if sys_page == "rebind":
		_rebind_page()
		return
	status = ThemeS.lab("", 20, Color(0.95, 0.8, 0.45))
	box.add_child(status)
	box.add_child(_slider("Master volume", App.vol_master, func(v): App.set_volume("master", v)))
	box.add_child(_slider("Music volume", App.vol_music, func(v): App.set_volume("music", v)))
	box.add_child(_slider("SFX volume", App.vol_sfx, func(v): App.set_volume("sfx", v)))
	box.add_child(_slider("Camera zoom", App.cam_zoom, func(v): App.set_zoom(v), 1.0, 1.75, 0.05))
	box.add_child(_slider("HUD scale", App.hud_scale, func(v): App.hud_scale = v, 0.8, 1.4, 0.05))
	box.add_child(ThemeS.btn("Aim-line: %s" % ("ON" if App.bal.aim_line_on else "OFF"), func(): App.bal.aim_line_on = not App.bal.aim_line_on; _rebuild()))
	box.add_child(_slider("Aim-line opacity", App.bal.aim_line_opacity, func(v): App.bal.aim_line_opacity = v, 0.05, 1.0, 0.05))
	box.add_child(ThemeS.btn("Archives / presentation", func(): _open_archives()))
	box.add_child(ThemeS.btn("Rebind controls", func(): sys_page = "rebind"; _rebuild()))
	box.add_child(ThemeS.btn("Character: %s  (switch)" % App.character_type, func(): _confirm(func(): _switch_char(), "char")))
	box.add_child(ThemeS.lab("Bitter — ViraXVespa", 16, Color(0.7, 0.74, 0.78)))
	box.add_child(ThemeS.btn("Patreon — ViraXVespa", func(): OS.shell_open(T.PATREON_URL)))
	box.add_child(ThemeS.btn("Bitter on YouTube", func(): OS.shell_open(T.BITTER_YT)))
	box.add_child(ThemeS.btn("Bitter on Spotify", func(): OS.shell_open(T.BITTER_SPOTIFY)))
	box.add_child(ThemeS.btn("Delete Save Data", func(): _confirm(func(): App.wipe_save(); App.toast("Save cleared."); _st("Cleared."), "wipe")))
	box.add_child(ThemeS.btn("“Dispel” Avatar", func(): _confirm(func(): _dispel(), "dispel")))
	box.add_child(ThemeS.btn("Close  (B)", func(): close_ui()))


func _slider(label: String, val: float, cb: Callable, lo := 0.0, hi := 1.0, step := 0.05) -> HBoxContainer:
	var h := HBoxContainer.new()
	h.add_child(ThemeS.lab(label, 18, Color(0.88, 0.82, 0.7)))
	var sl := HSlider.new()
	sl.min_value = lo
	sl.max_value = hi
	sl.step = step
	sl.value = val
	sl.custom_minimum_size = Vector2(360, 28)
	sl.add_theme_stylebox_override("slider", ThemeS.sb(Color(0.18, 0.14, 0.1), Color(0.5, 0.38, 0.2)))
	sl.add_theme_stylebox_override("grabber_area", ThemeS.sb(Color(0.45, 0.32, 0.16), Color(0.7, 0.55, 0.28)))
	sl.add_theme_stylebox_override("grabber_area_highlight", ThemeS.sb(Color(0.6, 0.45, 0.22), Color(0.9, 0.7, 0.3)))
	sl.value_changed.connect(cb)
	h.add_child(sl)
	return h


func _open_archives() -> void:
	if App.archives_ui and App.archives_ui.has_method("show_browser"):
		App.archives_ui.show_browser()


func _rebind_page() -> void:
	status = ThemeS.lab("Highlight an action, then press a key, mouse button, or pad control. That binding replaces the old one.", 18, Color(0.85, 0.8, 0.7))
	box.add_child(status)
	focus_btn = ThemeS.btn("Back to System", func(): sys_page = "main"; rebind_action = ""; _rebuild())
	box.add_child(focus_btn)
	for a in App.BIND_ACTIONS:
		var act: String = str(a)
		box.add_child(ThemeS.btn("%s  —  %s" % [act, ThemeS.bind_text(act)], func(): rebind_action = act; _st("Press a control for " + act)))


func _switch_char() -> void:
	var n := "female" if App.character_type == "male" else "male"
	App.set_character(n)
	var p := get_tree().get_first_node_in_group("player")
	if p and p.has_method("reload_character"):
		p.reload_character()
	_st("Now " + n)
	_rebuild()


func _dispel() -> void:
	close_ui()
	App.end_run("dispel", "")


func _confirm(fn: Callable, id := "anon") -> void:
	if not pending or pending_id != id:
		pending = true
		pending_id = id
		pending_fn = fn
		_st("A again to confirm. B cancels.")
		return
	pending = false
	pending_id = ""
	fn.call()


func _st(msg: String) -> void:
	if status:
		status.text = msg
	App.sfx("ui")


func _unhandled_input(event: InputEvent) -> void:
	if not open:
		return
	if App.archives_ui and bool(App.archives_ui.get("open")):
		return
	if rebind_action != "" and event.is_action_pressed("ui_cancel"):
		rebind_action = ""
		_st("Cancelled.")
		get_viewport().set_input_as_handled()
		return
	if rebind_action != "" and event.is_pressed() and (event is InputEventKey or event is InputEventJoypadButton or event is InputEventMouseButton or event is InputEventJoypadMotion):
		if event is InputEventMouseButton and (event as InputEventMouseButton).button_index == MOUSE_BUTTON_LEFT:
			return
		if not InputMap.has_action(rebind_action):
			InputMap.add_action(rebind_action)
		InputMap.action_erase_events(rebind_action)
		InputMap.action_add_event(rebind_action, event)
		_st("Bound " + rebind_action + " to " + ThemeS.bind_text(rebind_action))
		rebind_action = ""
		get_viewport().set_input_as_handled()
		return
	if event.is_action_pressed("tab_right"):
		tab = (tab + 1) % 3
		_rebuild()
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("tab_left"):
		tab = (tab + 2) % 3
		_rebuild()
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("ui_cancel") or event.is_action_pressed("pause"):
		if pending:
			pending = false
			pending_id = ""
			App.sfx("ui_cancel")
			_st("Cancelled.")
		elif sys_page == "rebind":
			sys_page = "main"
			rebind_action = ""
			App.sfx("ui_cancel")
			_rebuild()
		else:
			App.sfx("ui_cancel")
			close_ui()
		get_viewport().set_input_as_handled()
