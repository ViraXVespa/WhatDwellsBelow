extends Node

const ThemeS := preload("res://scripts/ui/theme.gd")
const View := preload("res://scripts/ui/split_menu_view.gd")
const Binds := preload("res://scripts/input/binds.gd")
const Prompts := preload("res://scripts/input/prompts.gd")

const ROWS: Array = [
	{"id": "move_up", "label": "Move up", "kb_only": true},
	{"id": "move_down", "label": "Move down", "kb_only": true},
	{"id": "move_left", "label": "Move left", "kb_only": true},
	{"id": "move_right", "label": "Move right", "kb_only": true},
	{"id": "attack", "label": "Attack"},
	{"id": "special", "label": "Special"},
	{"id": "dash", "label": "Dash"},
	{"id": "target_lock", "label": "Target lock"},
	{"id": "interact", "label": "Interact"},
	{"id": "map_view", "label": "Map"},
	{"id": "inventory", "label": "Inventory"},
	{"id": "potion", "label": "Potion"},
	{"id": "food", "label": "Food"},
	{"id": "look_mode", "label": "Look mode", "pad_only": true},
]

var host: Node
var pool := "kb"
var capture_action := ""
var capture_slot := -1


static func build(settings: Node) -> void:
	var old: Node = settings.get_node_or_null("bind_catcher")
	if old:
		old.queue_free()
	var page: Node = new()
	page.name = "bind_catcher"
	page.host = settings
	page.pool = str(settings.get("bind_pool")) if str(settings.get("bind_pool")) != "" else "kb"
	page.process_mode = Node.PROCESS_MODE_ALWAYS
	settings.add_child(page)
	page.rebuild()


func rebuild() -> void:
	if host == null or host.info_box == null:
		return
	capture_action = ""
	capture_slot = -1
	host.bind_pool = pool
	View.clear_page(host)
	_sel_row()
	var reset: Button = ThemeS.btn("Reset Controls", func() -> void:
		Binds.reset_pool(pool)
		App.save_now()
		rebuild()
		View.apply_col(host)
		View.focus_col(host)
	)
	View.add_page_btn(host, reset)
	for raw: Variant in ROWS:
		var row: Dictionary = raw
		if bool(row.get("pad_only", false)) and pool != "pad":
			continue
		if bool(row.get("kb_only", false)) and pool != "kb":
			continue
		_bind_row(str(row.get("id", "")), str(row.get("label", "")))
	View.wire_vert(host.info_btns)
	if host.has_method("split_hint"):
		host.split_hint()


func _sel_row() -> void:
	var lab: String = "<  Keyboard  >" if pool == "kb" else "<  Gamepad  >"
	var b: Button = ThemeS.btn(lab, func() -> void: _cycle_pool(1))
	b.gui_input.connect(func(event: InputEvent) -> void:
		if event.is_action_pressed("ui_left") or event.is_action_pressed("ui_right"):
			_cycle_pool(1)
			b.get_viewport().set_input_as_handled()
	)
	View.add_page_btn(host, b)


func _cycle_pool(_dir: int) -> void:
	pool = "pad" if pool == "kb" else "kb"
	rebuild()
	View.apply_col(host)
	View.focus_col(host)


func _bind_row(action: String, label: String) -> void:
	var shell := HBoxContainer.new()
	shell.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	shell.add_theme_constant_override("separation", 8)
	var name_lab: Label = ThemeS.lab(label, 20, Color(0.92, 0.86, 0.72))
	name_lab.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_lab.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	shell.add_child(name_lab)
	shell.add_child(_slot_btn(action, 0))
	shell.add_child(_slot_btn(action, 1))
	host.info_box.add_child(shell)


func _slot_btn(action: String, slot: int) -> Button:
	var ev: InputEvent = Binds.slot_event(action, pool, slot)
	var capturing: bool = capture_action == action and capture_slot == slot
	var txt: String = "..." if capturing else _slot_text(ev)
	var b: Button = ThemeS.btn(txt, func() -> void:
		capture_action = action
		capture_slot = slot
		rebuild()
		View.apply_col(host)
		if host.has_method("_focus_col"):
			host.call_deferred("_focus_col")
	)
	b.custom_minimum_size = Vector2(128, 44)
	var tex: Texture2D = Prompts.texture_for_event(ev, pool)
	if tex and not capturing:
		b.icon = tex
		b.expand_icon = true
	host.info_btns.append(b)
	return b


func _slot_text(ev: InputEvent) -> String:
	if ev == null:
		return "—"
	var id: String = Prompts.id_for_event(ev)
	if id == "":
		return "—"
	if id.begins_with("mouse/"):
		return id.replace("mouse/", "").replace("_", " ").to_upper()
	if id.begins_with("dpad_"):
		return id.substr(5).to_upper()
	return id.replace("_", " ").to_upper()


func _stick_axis(event: InputEvent) -> bool:
	if not (event is InputEventJoypadMotion):
		return false
	var ax: int = (event as InputEventJoypadMotion).axis
	return ax == JOY_AXIS_LEFT_X or ax == JOY_AXIS_LEFT_Y or ax == JOY_AXIS_RIGHT_X or ax == JOY_AXIS_RIGHT_Y


func _unhandled_input(event: InputEvent) -> void:
	if capture_action == "":
		return
	if event.is_echo() or not event.is_pressed():
		return
	if event.is_action_pressed("ui_cancel") or event.is_action_pressed("pause"):
		capture_action = ""
		capture_slot = -1
		rebuild()
		get_viewport().set_input_as_handled()
		return
	if _stick_axis(event):
		return
	if not Binds.event_in_pool(event, pool):
		return
	if event is InputEventJoypadMotion and absf((event as InputEventJoypadMotion).axis_value) < 0.6:
		return
	Binds.bind_slot(capture_action, pool, capture_slot, event)
	App.save_now()
	capture_action = ""
	capture_slot = -1
	rebuild()
	get_viewport().set_input_as_handled()
