extends CanvasLayer

const ThemeS := preload("res://scripts/ui/theme.gd")
const CatalogS := preload("res://scripts/data/catalog.gd")
const T := preload("res://scripts/data/tunables.gd")

const SKILL_NAMES := {
	"axe": "Great Axe",
	"staff": "Staff",
	"bow": "Longbow",
	"str": "Strength",
	"mag": "Magic",
	"rng": "Ranged",
	"def": "Defense",
	"hp": "Hitpoints",
	"mine": "Mining",
	"wood": "Woodcutting",
	"smith": "Smithing",
}

var open := false
var tab := 0
var box: VBoxContainer
var tabs: HBoxContainer
var scroll: ScrollContainer
var status: Label
var focus_btn: Control
var pending := false
var pending_id := ""
var pending_fn: Callable
var rebind_action := ""
var sys_page := "main"
var tip_host: PanelContainer
var tip_lab: Label
var tip_id := ""
var tip_kind := ""
var tip_from: Control = null


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
	scroll = ScrollContainer.new()
	scroll.position = Vector2(244, 128)
	scroll.size = Vector2(1432, 880)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.focus_mode = Control.FOCUS_NONE
	scroll.follow_focus = true
	add_child(scroll)
	box = VBoxContainer.new()
	box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	box.custom_minimum_size = Vector2(1400, 0)
	box.add_theme_constant_override("separation", 8)
	scroll.add_child(box)
	_make_tip()


func _make_tip() -> void:
	tip_host = PanelContainer.new()
	tip_host.visible = false
	tip_host.mouse_filter = Control.MOUSE_FILTER_IGNORE
	tip_host.z_index = 20
	tip_host.add_theme_stylebox_override("panel", ThemeS.sb(Color(0.09, 0.07, 0.05, 0.97), Color(0.85, 0.68, 0.32)))
	tip_lab = Label.new()
	tip_lab.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	tip_lab.custom_minimum_size = Vector2(380, 0)
	tip_lab.add_theme_font_size_override("font_size", 18)
	tip_lab.add_theme_color_override("font_color", Color(0.93, 0.86, 0.72))
	tip_lab.add_theme_color_override("font_outline_color", Color(0.05, 0.03, 0.02))
	tip_lab.add_theme_constant_override("outline_size", 6)
	tip_host.add_child(tip_lab)
	add_child(tip_host)


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
	pending = false
	pending_id = ""
	rebind_action = ""
	_hide_tip()
	_rebuild()


func close_ui() -> void:
	open = false
	visible = false
	pending = false
	pending_id = ""
	rebind_action = ""
	sys_page = "main"
	_hide_tip()
	App.ui_open = false
	get_tree().paused = false
	App.save_now()
	App.swallow_close_pad()
	App.wake_web_pad()


func _rebuild() -> void:
	_hide_tip()
	for c in tabs.get_children():
		c.queue_free()
	for c in box.get_children():
		c.queue_free()
	focus_btn = null
	status = null
	var names := ["Inventory", "Skills", "System"]
	for i in 3:
		var ii := i
		var b := ThemeS.btn(names[i], func():
			tab = ii
			sys_page = "main"
			_rebuild()
		)
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
		return
	for n in find_children("*", "Button", true, false):
		(n as Button).grab_focus()
		return


func _cap(text: String, size := 18, col := Color(0.9, 0.84, 0.7)) -> Label:
	var l := Label.new()
	l.text = text
	l.autowrap_mode = TextServer.AUTOWRAP_OFF
	l.clip_text = false
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	l.custom_minimum_size = Vector2(520, 26)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", col)
	l.add_theme_color_override("font_outline_color", Color(0.05, 0.03, 0.02))
	l.add_theme_constant_override("outline_size", 6)
	return l


func _inv() -> void:
	box.add_child(_cap("Carried  %dg   %d ore   %d wood   bag %d/%d" % [
		App.gold, App.ore, App.wood, App.prog.bag_count(), int(App.bal.bag_cap)
	], 22, Color(0.95, 0.8, 0.45)))
	box.add_child(_cap("Equipped", 20, Color(0.88, 0.82, 0.7)))
	for s in App.prog.SLOTS:
		var it: Dictionary = App.prog.slots.get(s, {})
		var line := "%s  —  empty" % str(s)
		if not it.is_empty():
			line = "%s  —  %s" % [str(s), str(it.get("name", s))]
			var extra := str(it.get("desc", ""))
			if extra != "":
				line += "   " + extra
		box.add_child(_cap(line, 18, Color(0.86, 0.8, 0.68)))
	box.add_child(_cap("Bag", 20, Color(0.88, 0.82, 0.7)))
	if App.prog.bag.is_empty():
		box.add_child(_cap("Nothing in the bag.", 18, Color(0.7, 0.66, 0.6)))
	else:
		for it in App.prog.bag:
			var nm := str(it.get("name", "item"))
			if bool(it.get("hold", false)):
				nm += "  (hold)"
			box.add_child(_cap(nm, 18, Color(0.86, 0.8, 0.68)))
	status = _cap("", 16, Color(0.78, 0.74, 0.66))
	box.add_child(status)
	box.add_child(ThemeS.btn("Close  (B)", close_ui))


func _xp_span() -> float:
	return maxf(1.0, App.bal.xp_level)


func _xp_lv(total: float) -> int:
	return 1 + int(total / _xp_span())


func _xp_to_next(total: float) -> int:
	var span := _xp_span()
	var into := fmod(total, span)
	if into <= 0.0001:
		return int(round(span))
	return int(round(span - into))


func _xp_ratio(total: float) -> float:
	return clampf(fmod(total, _xp_span()) / _xp_span(), 0.0, 1.0)


func _skill_title(id: String) -> String:
	return str(SKILL_NAMES.get(id, id))


func _perm_line(id: String, perm: float) -> String:
	return "%s Lv %d | Next Level: %dXP | Total XP: %dXP" % [
		_skill_title(id),
		_xp_lv(perm),
		_xp_to_next(perm),
		int(round(perm)),
	]


func _run_line(id: String, perm: float, runx: float) -> String:
	var live := perm + runx
	return "%s Lv %d | This Run: %dXP | Next Level: %dXP" % [
		_skill_title(id),
		_xp_lv(live),
		int(round(runx)),
		_xp_to_next(live),
	]


func _skill_lab(text: String, size := 16, col := Color(0.9, 0.84, 0.7)) -> Label:
	var l := Label.new()
	l.text = text
	l.autowrap_mode = TextServer.AUTOWRAP_OFF
	l.clip_text = false
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	l.custom_minimum_size = Vector2(0, 22)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", col)
	l.add_theme_color_override("font_outline_color", Color(0.05, 0.03, 0.02))
	l.add_theme_constant_override("outline_size", 6)
	return l


func _xp_bar(ratio: float, fill_col: Color) -> ColorRect:
	var track := ColorRect.new()
	track.mouse_filter = Control.MOUSE_FILTER_IGNORE
	track.custom_minimum_size = Vector2(0, 16)
	track.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	track.color = Color(0.18, 0.14, 0.1)
	track.clip_contents = true
	var fill := ColorRect.new()
	fill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	fill.color = fill_col
	fill.set_anchors_preset(Control.PRESET_FULL_RECT)
	fill.anchor_right = clampf(ratio, 0.0, 1.0)
	fill.offset_left = 0.0
	fill.offset_top = 0.0
	fill.offset_right = 0.0
	fill.offset_bottom = 0.0
	track.add_child(fill)
	return track


func _skill_block(id: String, kind: String, text: String, ratio: float, fill_col: Color) -> PanelContainer:
	var wrap := ThemeS.skill_row()
	var inner := VBoxContainer.new()
	inner.mouse_filter = Control.MOUSE_FILTER_IGNORE
	inner.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	inner.add_theme_constant_override("separation", 4)
	inner.add_child(_skill_lab(text))
	inner.add_child(_xp_bar(ratio, fill_col))
	wrap.add_child(inner)
	wrap.set_meta("skill_id", id)
	wrap.set_meta("skill_kind", kind)
	wrap.focus_entered.connect(_on_skill_focus.bind(id, kind, wrap))
	wrap.mouse_entered.connect(_on_skill_focus.bind(id, kind, wrap))
	wrap.focus_exited.connect(_on_skill_blur.bind(wrap))
	wrap.mouse_exited.connect(_on_skill_blur.bind(wrap))
	return wrap


func _on_skill_focus(id: String, kind: String, from: Control) -> void:
	if from is PanelContainer:
		(from as PanelContainer).add_theme_stylebox_override("panel", ThemeS.skill_row_sb(true))
	tip_id = id
	tip_kind = kind
	tip_from = from
	_paint_tip()


func _on_skill_blur(from: Control) -> void:
	if from is PanelContainer and not from.has_focus():
		(from as PanelContainer).add_theme_stylebox_override("panel", ThemeS.skill_row_sb(false))
	call_deferred("_blur_tip")


func _blur_tip() -> void:
	var f := get_viewport().gui_get_focus_owner()
	if f != null and f.has_meta("skill_id"):
		return
	_hide_tip()


func _hide_tip() -> void:
	tip_id = ""
	tip_kind = ""
	tip_from = null
	if tip_host:
		tip_host.visible = false


func _tip_lv(id: String, kind: String) -> int:
	var perm := float(App.prog.skills_perm.get(id, 0.0))
	var runx := float(App.prog.skills_run.get(id, 0.0))
	if kind == "run":
		return _xp_lv(perm + runx)
	return _xp_lv(perm)


func _paint_tip() -> void:
	if tip_id == "" or tip_from == null or not is_instance_valid(tip_from):
		if tip_host:
			tip_host.visible = false
		return
	tip_lab.text = ThemeS.skill_tip(tip_id, _tip_lv(tip_id, tip_kind))
	var w := 404.0
	tip_lab.custom_minimum_size = Vector2(w - 24.0, 0.0)
	var h := maxf(80.0, tip_lab.get_minimum_size().y + 20.0)
	tip_host.size = Vector2(w, h)
	var r := tip_from.get_global_rect()
	var pos := Vector2(r.position.x, r.position.y + r.size.y + 8.0)
	if pos.y + h > 1060.0:
		pos.y = r.position.y - h - 8.0
	if pos.x + w > 1900.0:
		pos.x = 1900.0 - w
	if pos.x < 20.0:
		pos.x = 20.0
	tip_host.position = pos
	tip_host.visible = true


func _skills() -> void:
	box.add_child(_cap("Combat Level %d" % App.prog.combat_lv(), 24, Color(0.95, 0.8, 0.45)))
	box.add_child(_cap("Highlight a skill for its bonuses.", 16, Color(0.78, 0.74, 0.66)))
	var perm_col := Color(0.72, 0.56, 0.28)
	var run_col := Color(0.86, 0.74, 0.32)
	var first: PanelContainer = null
	if App.in_dungeon:
		var heads := HBoxContainer.new()
		heads.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		heads.add_theme_constant_override("separation", 24)
		heads.add_child(_skill_lab("Permanent", 18, Color(0.95, 0.8, 0.45)))
		heads.add_child(_skill_lab("Dungeon XP", 18, Color(0.95, 0.8, 0.45)))
		box.add_child(heads)
		for id in App.prog.SKILLS:
			var perm := float(App.prog.skills_perm.get(id, 0.0))
			var runx := float(App.prog.skills_run.get(id, 0.0))
			var row := HBoxContainer.new()
			row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			row.add_theme_constant_override("separation", 24)
			var left := _skill_block(id, "perm", _perm_line(id, perm), _xp_ratio(perm), perm_col)
			var right := _skill_block(id, "run", _run_line(id, perm, runx), _xp_ratio(perm + runx), run_col)
			row.add_child(left)
			row.add_child(right)
			box.add_child(row)
			if first == null:
				first = left
	else:
		for id in App.prog.SKILLS:
			var perm := float(App.prog.skills_perm.get(id, 0.0))
			var row := _skill_block(id, "perm", _perm_line(id, perm), _xp_ratio(perm), perm_col)
			box.add_child(row)
			if first == null:
				first = row
	if first:
		focus_btn = first
	box.add_child(ThemeS.btn("Close  (B)", close_ui))


func _system() -> void:
	if sys_page == "rebind":
		_rebind()
		return
	box.add_child(_cap("System", 24, Color(0.95, 0.8, 0.45)))
	var char_btn := ThemeS.btn("Character: %s" % App.character_type, func():
		var nxt := "female" if App.character_type == "male" else "male"
		if App.has_method("set_character"):
			App.set_character(nxt)
		else:
			App.character_type = nxt
		App.save_now()
		_rebuild()
	)
	box.add_child(char_btn)
	box.add_child(_slider_row("Master volume", App.vol_master, 0.0, 1.0, 0.01, func(v: float):
		App.set_volume("master", v)
	))
	box.add_child(_slider_row("Music volume", App.vol_music, 0.0, 1.0, 0.01, func(v: float):
		App.set_volume("music", v)
	))
	box.add_child(_slider_row("SFX volume", App.vol_sfx, 0.0, 1.0, 0.01, func(v: float):
		App.set_volume("sfx", v)
	))
	box.add_child(_slider_row("Camera zoom", App.cam_zoom, T.ZOOM_MIN, T.ZOOM_MAX, 0.05, func(v: float):
		App.cam_zoom = v
	))
	box.add_child(_slider_row("HUD scale", App.hud_scale, 0.7, 1.4, 0.05, func(v: float):
		App.hud_scale = v
	))
	box.add_child(ThemeS.btn("Aim line: %s" % ("On" if App.bal.aim_line_on else "Off"), func():
		App.bal.aim_line_on = not App.bal.aim_line_on
		App.save_now()
		_rebuild()
	))
	box.add_child(_slider_row("Aim line opacity", App.bal.aim_line_opacity, 0.05, 1.0, 0.05, func(v: float):
		App.bal.aim_line_opacity = v
	))
	if App.in_dungeon:
		box.add_child(ThemeS.btn("Dispel Avatar", func():
			_confirm(func():
				close_ui()
				App.end_run("dispel")
			, "dispel")
		))
	box.add_child(ThemeS.btn("Archives", func():
		if App.archives_ui and App.archives_ui.has_method("show_browser"):
			App.archives_ui.show_browser()
	))
	box.add_child(ThemeS.btn("Rebind controls", func():
		sys_page = "rebind"
		_rebuild()
	))
	if App.has_method("reset_binds"):
		box.add_child(ThemeS.btn("Reset binds", func():
			App.reset_binds()
			App.save_now()
			_st("Binds reset.")
		))
	box.add_child(ThemeS.btn("Patreon", func():
		OS.shell_open("https://www.patreon.com/cw/ViraXVespa")
	))
	box.add_child(ThemeS.btn("Delete Save Data", func():
		_confirm(func():
			App.wipe_save()
			close_ui()
			App.go_title()
		, "wipe")
	))
	status = _cap("A again to confirm a marked action. B cancels.", 16, Color(0.78, 0.74, 0.66))
	box.add_child(status)
	box.add_child(ThemeS.btn("Close  (B)", close_ui))


func _rebind() -> void:
	box.add_child(_cap("Rebind controls", 24, Color(0.95, 0.8, 0.45)))
	box.add_child(_cap("Highlight an action, press A, then the new key or button.", 18, Color(0.82, 0.76, 0.66)))
	var binds: Array = []
	if App.has_method("collect_binds"):
		binds = App.collect_binds()
	if binds.is_empty():
		box.add_child(_cap("No bind list exposed.", 18, Color(0.7, 0.66, 0.6)))
	else:
		for raw in binds:
			if raw is Dictionary:
				var d: Dictionary = raw
				var act := str(d.get("action", d.get("id", "")))
				var lab := str(d.get("label", act))
				var cur := str(d.get("bind", d.get("key", "")))
				var a2 := act
				box.add_child(ThemeS.btn("%s   [%s]" % [lab, cur], func():
					rebind_action = a2
					_st("Press a key or button for %s." % lab)
				))
	if App.has_method("reset_binds"):
		box.add_child(ThemeS.btn("Reset binds", func():
			App.reset_binds()
			App.save_now()
			_rebuild()
		))
	box.add_child(ThemeS.btn("Back", func():
		sys_page = "main"
		rebind_action = ""
		_rebuild()
	))
	status = _cap("", 16, Color(0.78, 0.74, 0.66))
	box.add_child(status)


func _slider_row(title: String, value: float, lo: float, hi: float, step: float, on_change: Callable) -> VBoxContainer:
	var wrap := VBoxContainer.new()
	wrap.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	wrap.custom_minimum_size = Vector2(720, 0)
	wrap.add_theme_constant_override("separation", 4)
	wrap.add_child(_cap(title, 20, Color(0.9, 0.84, 0.7)))
	var sl := HSlider.new()
	sl.min_value = lo
	sl.max_value = hi
	sl.step = step
	sl.value = value
	sl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sl.custom_minimum_size = Vector2(720, 28)
	sl.focus_mode = Control.FOCUS_ALL
	sl.value_changed.connect(on_change)
	wrap.add_child(sl)
	return wrap


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


func _input(event: InputEvent) -> void:
	if not open or rebind_action == "":
		return
	if event is InputEventKey and event.pressed and not event.echo:
		if App.has_method("rebind"):
			App.rebind(rebind_action, event)
		rebind_action = ""
		App.save_now()
		_rebuild()
		get_viewport().set_input_as_handled()
	elif event is InputEventJoypadButton and event.pressed:
		if App.has_method("rebind"):
			App.rebind(rebind_action, event)
		rebind_action = ""
		App.save_now()
		_rebuild()
		get_viewport().set_input_as_handled()


func _unhandled_input(event: InputEvent) -> void:
	if not open:
		return
	if App.archives_ui and bool(App.archives_ui.get("open")):
		return
	if event.is_action_pressed("tab_right"):
		tab = (tab + 1) % 3
		sys_page = "main"
		_rebuild()
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("tab_left"):
		tab = (tab + 2) % 3
		sys_page = "main"
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