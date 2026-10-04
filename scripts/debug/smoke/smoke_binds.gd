extends Object

## Binding flows: one table, Esc bindable, swap / refuse results, Back-key confirm, toasts, hint tokens.

const Binds := preload("res://scripts/input/binds.gd")
const Table := preload("res://scripts/input/binds/table.gd")
const Prompts := preload("res://scripts/input/prompts.gd")
const Pad := preload("res://scripts/input/pad.gd")
const BindsPage := preload("res://scripts/ui/binds_page.gd")
const Confirm := preload("res://scripts/ui/confirm_dlg.gd")
const Split := preload("res://scripts/ui/split_menu.gd")

static func _key(code: int) -> InputEventKey:
	var e := InputEventKey.new()
	e.pressed = true
	e.keycode = code as Key
	e.physical_keycode = code as Key
	return e

static func _pad(btn: int) -> InputEventJoypadButton:
	var e := InputEventJoypadButton.new()
	e.pressed = true
	e.button_index = btn as JoyButton
	return e

static func _name(action: String, pool: String, slot: int) -> String:
	return Prompts.label_for_event(Binds.slot_event(action, pool, slot))

static func _click(ui: Node, idx: int) -> void:
	var dlg: Node = ui.get_node_or_null(Confirm.NODE_NAME)
	var n := 0
	for c: Node in dlg.get_children():
		if c is Button:
			if n == idx:
				(c as Button).pressed.emit()
				return
			n += 1

static func run() -> void:
	Binds.reset_pool("kb")
	Binds.reset_pool("pad")
	# One table: sticks and ui_* stay fixed, everything else is rebindable in its pools.
	var ok_table: bool = Table.can_rebind("pause", "kb") and Table.can_rebind("pause", "pad") and Table.can_rebind("crystal_zoom", "kb")
	ok_table = ok_table and not Table.can_rebind("ui_accept", "kb") and not Table.can_rebind("aim_left", "pad") and not Table.can_rebind("look_mode", "kb")
	assert(ok_table)
	# Results: bound, swapped (partner named), refused (partner named), Esc bindable, ui_cancel fixed.
	assert(Binds.bind_slot("dash", "kb", 0, _key(KEY_F9)) == Binds.BOUND)
	assert(_name("dash", "kb", 0) == "F9")
	assert(Binds.bind_slot("dash", "kb", 0, Binds.slot_event("potion", "kb", 0)) == Binds.SWAPPED)
	assert(Binds.last_other() == "potion" and _name("potion", "kb", 0) == "F9")
	assert(Binds.bind_slot("potion", "pad", 1, Binds.slot_event("look_mode", "pad", 0)) == Binds.REFUSED)
	assert(Binds.last_other() == "look_mode" and Binds.slot_event("look_mode", "pad", 0) != null)
	assert(Binds.bind_slot("interact", "kb", 1, _key(KEY_ESCAPE)) == Binds.SWAPPED)
	assert(_key(KEY_ESCAPE).is_action("ui_cancel"))
	Binds.reset_pool("kb")
	Binds.reset_pool("pad")
	# Hint tokens follow the bind.
	Binds.bind_slot("dash", "kb", 0, _key(KEY_F9))
	Pad.mode = false
	assert(Prompts.fmt("Hit {dash} {sha}") == "Hit F9 {sha}")
	Binds.reset_pool("kb")
	# Controls page: Back key asks, Confirm binds, Cancel keeps; other-pool Back cancels; toasts.
	App.pause_menu.show_menu()
	App.pause_menu.tab = 0
	App.pause_menu._rebuild()
	var sh: Node = App.pause_menu._settings_host()
	assert(sh != null)
	for i: int in Split.rows(sh).size():
		if str(Split.rows(sh)[i].get("id", "")) == "controls":
			sh.selected = i
	sh.split_build_page("controls")
	var page: Node = sh.get_node("bind_catcher")
	var ui: Node = sh.pause
	page.pool = "kb"
	page.capture_action = "dash"
	page.capture_slot = 0
	page._capture(_key(KEY_ESCAPE))
	assert(Confirm.is_open(ui) and page._asking)
	_click(ui, 1)
	assert(not page._asking and page.capture_action == "" and _name("dash", "kb", 0) == "Space")
	page.capture_action = "dash"
	page.capture_slot = 0
	page._capture(_key(KEY_ESCAPE))
	_click(ui, 0)
	assert(_name("dash", "kb", 0) == "Esc" and _name("pause", "kb", 0) == "Space")
	assert(App.toast_msg == "Esc binding swapped!" and sh.bind_note == App.toast_msg)
	page.capture_action = "dash"
	page.capture_slot = 1
	page._capture(_pad(JOY_BUTTON_B))
	assert(page.capture_action == "" and _name("dash", "kb", 1) == "")
	page.pool = "pad"
	page.capture_action = "potion"
	page.capture_slot = 1
	page._capture(_pad(JOY_BUTTON_DPAD_DOWN))
	assert(App.toast_msg.begins_with("Can't swap D-pad Down") and _name("look_mode", "pad", 0) == "D-pad Down")
	Binds.reset_pool("kb")
	Binds.reset_pool("pad")
	App.save_now()
	App.toast_t = 0.0
	App.pause_menu.close_ui()
