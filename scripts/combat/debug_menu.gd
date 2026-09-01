extends CanvasLayer

## Secret debug. Default engine controls allowed.

const Pad := preload("res://scripts/input/pad.gd")
const PAGES: PackedStringArray = ["values", "profiles", "playtest"]

var open := false
var page := "values"
var root_box: VBoxContainer
var scroll: ScrollContainer
var spins: Dictionary = {}
var play
var status: Label
var anim_btn: Button
var fly: Label
var profile_name := "default"
var loaded_profile := "default"
var stick_cool := 0.0


func _ready() -> void:
	layer = 80
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false
	set_process(false)
	set_process_input(false)
	play = App.playtest
	var dim := ColorRect.new()
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.color = Color(0.02, 0.02, 0.03, 0.72)
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(dim)
	var panel := Panel.new()
	panel.position = Vector2(60, 30)
	panel.size = Vector2(1800, 1020)
	panel.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(panel)
	scroll = ScrollContainer.new()
	scroll.set_anchors_preset(Control.PRESET_FULL_RECT)
	scroll.offset_left = 16
	scroll.offset_top = 16
	scroll.offset_right = -16
	scroll.offset_bottom = -16
	scroll.follow_focus = true
	scroll.mouse_filter = Control.MOUSE_FILTER_STOP
	panel.add_child(scroll)
	root_box = VBoxContainer.new()
	root_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	root_box.add_theme_constant_override("separation", 6)
	scroll.add_child(root_box)


func _rebuild() -> void:
	for c in root_box.get_children():
		c.queue_free()
	spins.clear()
	anim_btn = null
	fly = null
	var title := Label.new()
	title.text = "Secret Debug — Phase 9"
	title.add_theme_font_size_override("font_size", 28)
	title.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root_box.add_child(title)
	var nav := HBoxContainer.new()
	nav.add_theme_constant_override("separation", 10)
	nav.add_child(_btn("Values", func(): page = "values"; _rebuild()))
	nav.add_child(_btn("Profiles", func(): page = "profiles"; _rebuild()))
	nav.add_child(_btn("Playtest", func(): page = "playtest"; _rebuild()))
	anim_btn = _btn("Animation Browser", func(): _open_anim())
	nav.add_child(anim_btn)
	nav.add_child(_btn("Close (B)", func(): hide_menu()))
	root_box.add_child(nav)
	status = Label.new()
	status.add_theme_font_size_override("font_size", 18)
	status.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root_box.add_child(status)
	match page:
		"values":
			_page_values()
		"profiles":
			_page_profiles()
		"playtest":
			_page_playtest()
		"anim":
			_page_anim()
	call_deferred("_focus")


func _focusables() -> Array[Control]:
	var out: Array[Control] = []
	for n: Node in find_children("*", "Control", true, false):
		if n.is_queued_for_deletion():
			continue
		if not (n is Button or n is SpinBox or n is LineEdit):
			continue
		var c := n as Control
		if c.focus_mode == Control.FOCUS_NONE:
			continue
		out.append(c)
	return out


func _wire_focus() -> void:
	var items := _focusables()
	var n := items.size()
	if n == 0:
		return
	for i in n:
		var cur := items[i]
		var prev := items[(i + n - 1) % n]
		var nxt := items[(i + 1) % n]
		cur.focus_neighbor_top = prev.get_path()
		cur.focus_neighbor_bottom = nxt.get_path()
		cur.focus_previous = prev.get_path()
		cur.focus_next = nxt.get_path()


func _focus() -> void:
	if not open:
		return
	if App.anim_browser and bool(App.anim_browser.get("open")):
		return
	_wire_focus()
	var items := _focusables()
	if items.is_empty():
		return
	items[0].grab_focus()


func _page_values() -> void:
	status.text = "All tunable values. Highlight a row for fresh/progressed ideals. LB/RB change pages."
	fly = Label.new()
	fly.add_theme_font_size_override("font_size", 16)
	fly.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	fly.mouse_filter = Control.MOUSE_FILTER_IGNORE
	fly.text = "Highlight a variable for fly-out ideals."
	root_box.add_child(fly)
	for row in App.bal.schema():
		_add_row(str(row[0]), float(row[1]), float(row[2]), float(row[3]))


func _add_row(name: String, lo: float, hi: float, step: float) -> void:
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 12)
	var lab := Label.new()
	lab.text = name
	lab.custom_minimum_size = Vector2(360, 0)
	lab.mouse_filter = Control.MOUSE_FILTER_IGNORE
	h.add_child(lab)
	var sp := SpinBox.new()
	sp.min_value = lo
	sp.max_value = hi
	sp.step = step
	sp.custom_minimum_size = Vector2(200, 0)
	sp.focus_mode = Control.FOCUS_ALL
	sp.mouse_filter = Control.MOUSE_FILTER_STOP
	sp.value = App.bal.getv(name)
	sp.value_changed.connect(func(v): App.bal.setv(name, v))
	var nm := name
	sp.focus_entered.connect(func(): _fly(nm))
	sp.mouse_entered.connect(func(): _fly(nm))
	h.add_child(sp)
	root_box.add_child(h)
	spins[name] = sp


func _fly(name: String) -> void:
	if fly == null or play == null:
		return
	var f := 0.0
	var p := 0.0
	if play.has_method("ideal_for"):
		f = play.ideal_for(name, "fresh")
		p = play.ideal_for(name, "progressed")
	fly.text = "%s  ·  fresh ideal %.2f  ·  progressed ideal %.2f  ·  current %.2f" % [name, f, p, App.bal.getv(name)]


func _page_profiles() -> void:
	status.text = "Unlimited named profiles. Saved under user://wdb_profiles/"
	var le := LineEdit.new()
	le.text = profile_name
	le.custom_minimum_size = Vector2(360, 36)
	le.focus_mode = Control.FOCUS_ALL
	le.text_changed.connect(func(t): profile_name = t)
	root_box.add_child(le)
	root_box.add_child(_btn("Save", func(): _save_profile(); status.text = "Saved " + profile_name))
	root_box.add_child(_btn("Load", func(): _load_profile(); status.text = "Loaded " + profile_name; page = "values"; _rebuild()))
	root_box.add_child(_btn("Delete", func(): _delete_profile(); status.text = "Deleted " + profile_name))
	root_box.add_child(_btn("Rename current to field", func(): _rename_profile(); status.text = "Renamed"))
	root_box.add_child(Label.new())
	for n in _list_profiles():
		var nm := n
		root_box.add_child(_btn("Load " + nm, func(): profile_name = nm; _load_profile(); status.text = "Loaded " + nm))


func _dir() -> String:
	return "user://wdb_profiles"


func _list_profiles() -> PackedStringArray:
	var d := DirAccess.open("user://")
	if d and not d.dir_exists("wdb_profiles"):
		d.make_dir("wdb_profiles")
	var out: PackedStringArray = PackedStringArray()
	var pd := DirAccess.open(_dir())
	if pd == null:
		return out
	pd.list_dir_begin()
	var f := pd.get_next()
	while f != "":
		if f.ends_with(".json"):
			out.append(f.get_basename())
		f = pd.get_next()
	return out


func _save_profile() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(_dir()))
	var data := {}
	for row in App.bal.schema():
		data[str(row[0])] = App.bal.getv(str(row[0]))
	var f := FileAccess.open("%s/%s.json" % [_dir(), profile_name], FileAccess.WRITE)
	if f:
		f.store_string(JSON.stringify(data))
		loaded_profile = profile_name


func _load_profile() -> void:
	var f := FileAccess.open("%s/%s.json" % [_dir(), profile_name], FileAccess.READ)
	if f == null:
		status.text = "Missing profile."
		return
	var parsed: Variant = JSON.parse_string(f.get_as_text())
	if parsed is Dictionary:
		var d: Dictionary = parsed
		for k in d.keys():
			App.bal.setv(str(k), float(d[k]))
		loaded_profile = profile_name


func _delete_profile() -> void:
	DirAccess.remove_absolute(ProjectSettings.globalize_path("%s/%s.json" % [_dir(), profile_name]))


func _rename_profile() -> void:
	var prev := loaded_profile
	_save_profile()
	if prev != "" and prev != profile_name:
		DirAccess.remove_absolute(ProjectSettings.globalize_path("%s/%s.json" % [_dir(), prev]))
	loaded_profile = profile_name


func _page_playtest() -> void:
	status.text = "Live AI. Queue closes this menu so the avatar can move. Logs go to user://playtest/runs/"
	root_box.add_child(_btn("Queue full-target batch (6 live runs)", func(): _start_play(play.queue_batch())))
	root_box.add_child(_btn("Queue 1 live — fresh Great Axe", func(): play.enqueue({"save": "fresh", "weapon": "great_axe", "tool": "pickaxe", "gender": "male", "scale": App.bal.playtest_scale, "limit": App.bal.playtest_limit, "cfg": {}}); _start_play("Queued 1.")))
	root_box.add_child(_btn("Queue 1 live — progressed Longbow", func(): play.enqueue({"save": "progressed", "weapon": "longbow", "tool": "hatchet", "gender": "female", "scale": App.bal.playtest_scale, "limit": App.bal.playtest_limit, "cfg": {}}); _start_play("Queued 1.")))
	root_box.add_child(_btn("Interrupt (keep telemetry)", func(): play.interrupt(); status.text = "Interrupt. Rows kept: %d" % play.history.size()))
	root_box.add_child(_btn("Fast seed coefs (Medium bar math)", func(): status.text = play.run_medium()))
	root_box.add_child(Label.new())
	var sum := Label.new()
	sum.text = play.last_summary if play.last_summary != "" else "No run yet. Queue a live batch or run the fast seed."
	sum.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	sum.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root_box.add_child(sum)
	root_box.add_child(_btn("Apply fresh ideal", func(): status.text = play.apply_rec("fresh", 0)))
	root_box.add_child(_btn("Apply fresh alt A", func(): status.text = play.apply_rec("fresh", 1)))
	root_box.add_child(_btn("Apply fresh alt B", func(): status.text = play.apply_rec("fresh", 2)))
	root_box.add_child(_btn("Apply progressed ideal", func(): status.text = play.apply_rec("progressed", 0)))
	root_box.add_child(_btn("Apply progressed alt A", func(): status.text = play.apply_rec("progressed", 1)))
	root_box.add_child(_btn("Apply progressed alt B", func(): status.text = play.apply_rec("progressed", 2)))
	root_box.add_child(_btn("Reset progressed save template", func(): status.text = play.reset_progressed_template()))
	var n := Label.new()
	n.text = "History rows: %d   queue: %d   live: %s" % [play.history.size(), play.queue.size(), str(play.live_running)]
	n.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root_box.add_child(n)


func _start_play(msg: String) -> void:
	status.text = msg
	hide_menu()


func _open_anim() -> void:
	if App.anim_browser and App.anim_browser.has_method("open_browser"):
		App.anim_browser.open_browser()


func _page_anim() -> void:
	status.text = "Full Animation Browser"
	root_box.add_child(_btn("Open Animation Browser", func(): _open_anim()))
	root_box.add_child(_btn("Back to Values", func(): page = "values"; _rebuild()))


func _btn(t: String, cb: Callable) -> Button:
	var b := Button.new()
	b.text = t
	b.custom_minimum_size = Vector2(0, 40)
	b.focus_mode = Control.FOCUS_ALL
	b.mouse_filter = Control.MOUSE_FILTER_STOP
	b.pressed.connect(cb)
	return b


func show_menu() -> void:
	open = true
	visible = true
	App.ui_open = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	set_process(true)
	set_process_input(true)
	page = "values"
	_rebuild()


func hide_menu() -> void:
	open = false
	visible = false
	set_process(false)
	set_process_input(false)
	var keep := false
	if App.anim_browser and bool(App.anim_browser.get("open")):
		keep = true
	elif App.pause_menu and bool(App.pause_menu.get("open")):
		keep = true
	App.ui_open = keep
	if App.playtest and bool(App.playtest.get("live_running")):
		App.ui_open = false
	if not keep:
		App.save_now()


func toggle() -> void:
	if open:
		hide_menu()
	else:
		show_menu()


func _busy_anim() -> bool:
	return App.anim_browser != null and bool(App.anim_browser.get("open"))


func _process(delta: float) -> void:
	if not open or _busy_anim():
		return
	stick_cool = maxf(0.0, stick_cool - delta)
	if stick_cool > 0.0:
		return
	var owner: Control = get_viewport().gui_get_focus_owner() if get_viewport() else null
	if owner == null or not is_ancestor_of(owner):
		var items := _focusables()
		if not items.is_empty():
			items[0].grab_focus()
		return
	var s: Vector2 = Pad.stick(JOY_AXIS_LEFT_X, JOY_AXIS_LEFT_Y)
	var side := -1
	if s.y <= -0.55:
		side = SIDE_TOP
	elif s.y >= 0.55:
		side = SIDE_BOTTOM
	elif s.x <= -0.55:
		side = SIDE_LEFT
	elif s.x >= 0.55:
		side = SIDE_RIGHT
	if side < 0:
		return
	var nxt: Control = owner.find_valid_focus_neighbor(side)
	if nxt:
		nxt.grab_focus()
		stick_cool = 0.18


func _shift_page(delta_i: int) -> void:
	var i := PAGES.find(page)
	if i < 0:
		i = 0
	page = PAGES[(i + delta_i + PAGES.size()) % PAGES.size()]
	_rebuild()


func _input(event: InputEvent) -> void:
	if not open or _busy_anim():
		return
	if event.is_action_pressed("tab_right"):
		_shift_page(1)
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("tab_left"):
		_shift_page(-1)
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("ui_cancel") or event.is_action_pressed("pause") or event.is_action_pressed("dash"):
		if page != "values":
			page = "values"
			_rebuild()
		else:
			hide_menu()
		if App.has_method("swallow_close_pad"):
			App.swallow_close_pad()
		get_viewport().set_input_as_handled()
