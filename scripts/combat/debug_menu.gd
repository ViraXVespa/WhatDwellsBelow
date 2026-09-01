extends CanvasLayer

## Secret debug. Default engine controls allowed.

const Pad := preload("res://scripts/input/pad.gd")
const DebugMenuVal := preload("res://scripts/combat/debug_menu_val.gd")
const DebugMenuPages := preload("res://scripts/combat/debug_menu_pages.gd")
const PAGES: PackedStringArray = ["values", "profiles", "playtest", "anim"]

var open := false
var page := "values"
var chrome_box: VBoxContainer
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
var val_rows: Array = []
var val_i := 0
var val_edit := false
var val_backup := 0.0


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
	var shell := VBoxContainer.new()
	shell.set_anchors_preset(Control.PRESET_FULL_RECT)
	shell.offset_left = 16
	shell.offset_top = 16
	shell.offset_right = -16
	shell.offset_bottom = -16
	shell.add_theme_constant_override("separation", 8)
	panel.add_child(shell)
	chrome_box = VBoxContainer.new()
	chrome_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	chrome_box.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	chrome_box.add_theme_constant_override("separation", 6)
	shell.add_child(chrome_box)
	scroll = ScrollContainer.new()
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.follow_focus = false
	scroll.focus_mode = Control.FOCUS_NONE
	scroll.mouse_filter = Control.MOUSE_FILTER_STOP
	shell.add_child(scroll)
	root_box = VBoxContainer.new()
	root_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	root_box.add_theme_constant_override("separation", 6)
	scroll.add_child(root_box)


func _rebuild() -> void:
	for c in chrome_box.get_children():
		c.queue_free()
	for c in root_box.get_children():
		c.queue_free()
	spins.clear()
	val_rows.clear()
	val_edit = false
	anim_btn = null
	fly = null
	var title := Label.new()
	title.text = "Secret Debug — Phase 9"
	title.add_theme_font_size_override("font_size", 28)
	title.mouse_filter = Control.MOUSE_FILTER_IGNORE
	chrome_box.add_child(title)
	var nav := HBoxContainer.new()
	nav.add_theme_constant_override("separation", 10)
	nav.add_child(_tab_btn("Values", "values"))
	nav.add_child(_tab_btn("Profiles", "profiles"))
	nav.add_child(_tab_btn("Playtest", "playtest"))
	anim_btn = _tab_btn("Animation Browser", "anim")
	nav.add_child(anim_btn)
	nav.add_child(_chrome_btn("Close (B)", func(): hide_menu()))
	chrome_box.add_child(nav)
	status = Label.new()
	status.add_theme_font_size_override("font_size", 18)
	status.mouse_filter = Control.MOUSE_FILTER_IGNORE
	chrome_box.add_child(status)
	match page:
		"values":
			DebugMenuVal.page_values(self)
		"profiles":
			DebugMenuVal.page_profiles(self)
		"playtest":
			DebugMenuPages.page_playtest(self)
		"anim":
			DebugMenuPages.page_anim(self)
	if scroll:
		scroll.scroll_vertical = 0
	call_deferred("_focus")


func _inside_spin(c: Control) -> bool:
	var p := c.get_parent()
	while p != null and p != root_box:
		if p is SpinBox:
			return true
		p = p.get_parent()
	return false


func _focusables() -> Array[Control]:
	var out: Array[Control] = []
	if root_box == null or page == "values":
		return out
	for n: Node in root_box.find_children("*", "Control", true, false):
		if n.is_queued_for_deletion():
			continue
		if not (n is Button or n is SpinBox or n is LineEdit):
			continue
		var c := n as Control
		if c.focus_mode == Control.FOCUS_NONE:
			continue
		if not c.is_visible_in_tree():
			continue
		if _inside_spin(c):
			continue
		out.append(c)
	return out


func _page_owner(ctrl: Control) -> Control:
	var walk: Node = ctrl
	while walk != null and walk != root_box:
		if walk is SpinBox:
			return walk as Control
		walk = walk.get_parent()
	return ctrl


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
		cur.focus_neighbor_left = NodePath("")
		cur.focus_neighbor_right = NodePath("")


func _focus() -> void:
	if not open:
		return
	if App.anim_browser and bool(App.anim_browser.get("open")):
		return
	if page == "values":
		if val_i >= val_rows.size():
			val_i = 0
		DebugMenuVal.val_paint(self)
		return
	_wire_focus()
	if scroll:
		scroll.scroll_vertical = 0
	var items := _focusables()
	if items.is_empty():
		return
	items[0].grab_focus()


func _nudge_focus(delta_i: int) -> void:
	if page == "values":
		DebugMenuVal.val_nudge(self, delta_i)
		return
	var items := _focusables()
	var n := items.size()
	if n == 0:
		return
	var owner: Control = get_viewport().gui_get_focus_owner() if get_viewport() else null
	var idx := 0
	if owner and is_ancestor_of(owner):
		var page_owner := _page_owner(owner)
		var found := items.find(page_owner)
		if found >= 0:
			idx = found
	items[(idx + delta_i + n) % n].grab_focus()


func _btn(t: String, cb: Callable) -> Button:
	var b := Button.new()
	b.text = t
	b.custom_minimum_size = Vector2(0, 40)
	b.focus_mode = Control.FOCUS_ALL
	b.mouse_filter = Control.MOUSE_FILTER_STOP
	b.pressed.connect(cb)
	return b


func _chrome_btn(t: String, cb: Callable) -> Button:
	var b := _btn(t, cb)
	b.focus_mode = Control.FOCUS_NONE
	b.custom_minimum_size = Vector2(200, 44)
	return b


func _tab_btn(t: String, id: String) -> Button:
	var b := _chrome_btn(t, func(): page = id; _rebuild())
	if page == id:
		b.add_theme_color_override("font_color", Color(1, 0.92, 0.45))
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


func _start_play(msg: String) -> void:
	status.text = msg
	hide_menu()


func _busy_anim() -> bool:
	return App.anim_browser != null and bool(App.anim_browser.get("open"))


func _process(delta: float) -> void:
	if not open or _busy_anim():
		return
	stick_cool = maxf(0.0, stick_cool - delta)
	if stick_cool > 0.0:
		return
	var s: Vector2 = Pad.stick(JOY_AXIS_LEFT_X, JOY_AXIS_LEFT_Y)
	if s.y <= -0.55:
		_nudge_focus(-1)
		stick_cool = 0.18
		return
	if s.y >= 0.55:
		_nudge_focus(1)
		stick_cool = 0.18
		return
	if page == "values":
		return
	var owner: Control = get_viewport().gui_get_focus_owner() if get_viewport() else null
	if owner == null or not is_ancestor_of(owner):
		var items := _focusables()
		if not items.is_empty():
			items[0].grab_focus()


func _shift_page(delta_i: int) -> void:
	if val_edit:
		DebugMenuVal.val_cancel(self)
	var i := PAGES.find(page)
	if i < 0:
		i = 0
	page = PAGES[(i + delta_i + PAGES.size()) % PAGES.size()]
	_rebuild()


func _accept_pressed(event: InputEvent) -> bool:
	if event.is_action_pressed("ui_accept") or event.is_action_pressed("interact"):
		return true
	if event is InputEventJoypadButton and event.pressed and event.button_index == JOY_BUTTON_A:
		return true
	return false


func _input(event: InputEvent) -> void:
	if not open or _busy_anim():
		return
	if event.is_action_pressed("tab_right"):
		_shift_page(1)
		get_viewport().set_input_as_handled()
		return
	if event.is_action_pressed("tab_left"):
		_shift_page(-1)
		get_viewport().set_input_as_handled()
		return
	if page == "values":
		if event.is_action_pressed("ui_down"):
			DebugMenuVal.val_nudge(self, 1)
			get_viewport().set_input_as_handled()
			return
		if event.is_action_pressed("ui_up"):
			DebugMenuVal.val_nudge(self, -1)
			get_viewport().set_input_as_handled()
			return
		if _accept_pressed(event):
			DebugMenuVal.val_accept(self)
			get_viewport().set_input_as_handled()
			return
		if event.is_action_pressed("ui_cancel") or event.is_action_pressed("pause") or event.is_action_pressed("dash"):
			if DebugMenuVal.val_cancel(self):
				get_viewport().set_input_as_handled()
				return
	elif event.is_action_pressed("ui_down"):
		_nudge_focus(1)
		get_viewport().set_input_as_handled()
		return
	elif event.is_action_pressed("ui_up"):
		_nudge_focus(-1)
		get_viewport().set_input_as_handled()
		return
	if event.is_action_pressed("ui_cancel") or event.is_action_pressed("pause") or event.is_action_pressed("dash"):
		if page != "values":
			page = "values"
			_rebuild()
		else:
			hide_menu()
		if App.has_method("swallow_close_pad"):
			App.swallow_close_pad()
		get_viewport().set_input_as_handled()
