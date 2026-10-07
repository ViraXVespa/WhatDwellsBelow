extends Node

const ThemeS := preload("res://scripts/ui/theme.gd")
const View := preload("res://scripts/ui/split_menu/split_menu_view.gd")
const Binds := preload("res://scripts/input/binds.gd")
const Prompts := preload("res://scripts/input/prompts.gd")
const Table := preload("res://scripts/input/binds/table.gd")
const LocS := preload("res://scripts/app/app_loc.gd")
const Confirm := preload("res://scripts/ui/confirm_dlg.gd")
const MenuPad := preload("res://scripts/ui/menu_pad.gd")
const Split := preload("res://scripts/ui/split_menu.gd")

var host: Node
var pool := "kb"
var capture_action := ""
var capture_slot := -1
var _pool_stick_armed := true
var _asking := false

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
	MenuPad.capture_lock = capture_action != "" and not _asking
	host.bind_pool = pool
	View.clear_page(host)
	_sel_row()
	var reset: Button = ThemeS.btn(App.tr("binds_page.reset_controls"), func() -> void:
		var ui: Node = host.get("pause") as Node if host else null
		if ui == null:
			ui = host
		var which: String = App.tr("binds_page.keyboard") if pool == "kb" else App.tr("binds_page.gamepad")
		Confirm.open(ui, App.tr("binds_page.reset_controls"), App.tr("binds_page.restore_default_controls").format({"which": which}), func() -> void:
			Binds.reset_pool(pool)
			App.save_now()
			_end_capture()
			View.apply_col(host)
			View.focus_col(host)
		, Callable(), "danger")
	, true, "danger")
	View.add_page_btn(host, reset)
	for row: Dictionary in Table.rebindable():
		if Table.can_rebind(str(row.id), pool):
			_bind_row(str(row.id), _label(str(row.id)))
	View.wire_vert(host.info_btns)
	if host.has_method("split_hint"):
		host.split_hint()

func _label(id: String) -> String:
	return LocS.tr_or("controls." + id, str(Table.row(id).get("label", id)))

func _sel_row() -> void:
	var lab: String = App.tr("binds_page.keyboard_cycle") if pool == "kb" else App.tr("binds_page.gamepad_cycle")
	var b: Button = ThemeS.btn(lab, func() -> void: _cycle_pool(1))
	b.gui_input.connect(_on_sel_input)
	View.add_page_btn(host, b)

func _on_sel_input(event: InputEvent) -> void:
	if event is InputEventJoypadMotion:
		_sel_stick(event as InputEventJoypadMotion)
		return
	if event.is_echo() or not event.is_pressed():
		return
	if not (event is InputEventKey or event is InputEventJoypadButton):
		return
	if event.is_action_pressed("ui_left") or event.is_action_pressed("ui_right"):
		_cycle_pool(1)
		get_viewport().set_input_as_handled()

func _sel_stick(motion: InputEventJoypadMotion) -> void:
	if motion.axis != JOY_AXIS_LEFT_X:
		return
	if absf(motion.axis_value) < 0.6:
		_pool_stick_armed = true
		return
	if not _pool_stick_armed:
		return
	_pool_stick_armed = false
	_cycle_pool(1)
	get_viewport().set_input_as_handled()

func _cycle_pool(_dir: int) -> void:
	pool = "pad" if pool == "kb" else "kb"
	_end_capture()
	View.apply_col(host)
	View.focus_col(host)

func _bind_row(action: String, label: String) -> void:
	var shell := HBoxContainer.new()
	shell.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	shell.add_theme_constant_override("separation", 8)
	var name_lab: Label = ThemeS.lab(label, 20, ThemeS.INK)
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
		if capture_action == action and capture_slot == slot:
			_end_capture()
			View.apply_col(host)
			View.focus_col(host)
			return
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
	return "—" if ev == null else Prompts.label_for_event(ev)

func _stick_axis(event: InputEvent) -> bool:
	if not (event is InputEventJoypadMotion):
		return false
	var ax: int = (event as InputEventJoypadMotion).axis
	return ax == JOY_AXIS_LEFT_X or ax == JOY_AXIS_LEFT_Y or ax == JOY_AXIS_RIGHT_X or ax == JOY_AXIS_RIGHT_Y

func _end_capture() -> void:
	capture_action = ""
	capture_slot = -1
	MenuPad.capture_lock = false
	rebuild()

func _exit_tree() -> void:
	MenuPad.capture_lock = false
	if is_instance_valid(host):
		host.set("bind_note", "")

func _process(_dt: float) -> void:
	if host == null:
		return
	if str(host.get("bind_note")) != "" and App.toast_t <= 0.0:
		host.set("bind_note", "")
		host.split_hint()
	if capture_action != "" and not _asking and str(Split.current(host).get("id", "")) != "controls":
		_end_capture()

## Toast text (App.toast) that also shows in the Controls footer, since the HUD toast sits under the pause menu.
func _note(msg: String) -> void:
	App.toast(msg)
	host.set("bind_note", msg)

## Capture gets first claim on every key and pad button (Esc, Start, Space, B, [, ], LB, RB bind like any other).
## A key that currently goes Back (ui_cancel or pause) asks first: Confirm binds it, Cancel keeps things as they were.
## Safety nets: that Back input from the other pool cancels capture at once, a second click on the slot cancels, and
## leaving the page ends it. Mouse clicks stay on the GUI path.
func _input(event: InputEvent) -> void:
	if not (event is InputEventMouseButton):
		_capture(event)

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		_capture(event)

func _is_back(event: InputEvent) -> bool:
	return event.is_action("ui_cancel") or event.is_action("pause")

func _capture(event: InputEvent) -> void:
	if capture_action == "" or _asking:
		return
	if event.is_echo() or not event.is_pressed():
		return
	if _stick_axis(event):
		return
	if not Binds.event_in_pool(event, pool):
		if _is_back(event):
			_end_capture()
			get_viewport().set_input_as_handled()
		return
	if event is InputEventJoypadMotion and absf((event as InputEventJoypadMotion).axis_value) < 0.6:
		return
	get_viewport().set_input_as_handled()
	if _is_back(event):
		_ask(event)
	else:
		_apply(event)

func _ask(event: InputEvent) -> void:
	_asking = true
	MenuPad.capture_lock = false
	var ui: Node = host.get("pause") as Node
	if ui == null:
		ui = host
	var args := {"input_name": Prompts.label_for_event(event), "action_name": _label(capture_action)}
	Confirm.open(ui, App.tr("binds_page.back_key_title").format(args), App.tr("binds_page.back_key_body").format(args), func() -> void:
		_asking = false
		_apply(event)
	, func() -> void:
		_asking = false
		_end_capture()
	)

func _apply(event: InputEvent) -> void:
	var args := {"input_name": Prompts.label_for_event(event)}
	var res: int = Binds.bind_slot(capture_action, pool, capture_slot, event)
	var other: String = Binds.last_other()
	if res != Binds.REFUSED:
		App.save_now()
	if res == Binds.SWAPPED:
		_note(App.tr("binds_page.swapped").format(args))
	elif res == Binds.REFUSED and other != "":
		args["action_name"] = _label(other)
		_note(App.tr("binds_page.swap_refused").format(args))
	_end_capture()
