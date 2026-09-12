extends Object

## Gear board X-hold and pad event handling.

const Board := preload("res://scripts/ui/gear_board/gear_board.gd")
const Text := preload("res://scripts/ui/gear_board/gear_board_text.gd")
const Pad := preload("res://scripts/ui/menu_pad.gd")
const ForgeUI := preload("res://scripts/ui/gear_board/gear_board_anvil_forge.gd")
const Sub := preload("res://scripts/ui/gear_board/gear_board_sub.gd")
const Items := preload("res://scripts/ui/gear_board/gear_board_act_items.gd")

const HOLD_DESTROY := 0.55

static var swallow_until := 0


static func swallow_cancel() -> void:
	swallow_until = Time.get_ticks_msec() + 350


static func swallowing() -> bool:
	return Time.get_ticks_msec() < swallow_until


static func tick_x(ui: CanvasLayer, delta: float) -> void:
	if str(ui.get("gear_mode")) == "anvil":
		ui.gear_x_hold = 0.0
		ui.gear_x_fired = false
		return
	if not bool(ui.get("open")):
		ui.gear_x_hold = 0.0
		ui.gear_x_fired = false
		return
	var down := Input.is_action_pressed("gear_drop") or Input.is_physical_key_pressed(KEY_X) or joy_down(JOY_BUTTON_X)
	if down:
		ui.gear_x_hold = float(ui.gear_x_hold) + delta
		if float(ui.gear_x_hold) >= HOLD_DESTROY and not bool(ui.gear_x_fired):
			ui.gear_x_fired = true
			Items.destroy(ui)
	else:
		if float(ui.gear_x_hold) > 0.05 and float(ui.gear_x_hold) < HOLD_DESTROY and not bool(ui.gear_x_fired):
			Items.drop(ui)
		ui.gear_x_hold = 0.0
		ui.gear_x_fired = false

static func joy_down(btn: int) -> bool:
	for id: int in Input.get_connected_joypads():
		if Input.is_joy_button_pressed(id, btn):
			return true
	return false


static func input_tick(ui: CanvasLayer, event: InputEvent) -> bool:
	return handle_event(ui, event)


static func handle_event(ui: CanvasLayer, event: InputEvent) -> bool:
	if event is InputEventMouse:
		return false
	if swallowing() and Pad.is_back(event):
		return true
	if bool(ui.get("gear_sub")):
		if is_tip(event):
			cycle_tip(ui)
			return true
		if Pad.is_back(event):
			back_sub(ui)
			return true
		if Pad.tab_delta(event) != 0:
			return true
		if Pad.page_delta(event) != 0:
			if str(ui.get("forge_phase")) == "pick":
				cycle_stats(ui, Pad.page_delta(event))
			return true
		return false
	if is_tip(event):
		cycle_tip(ui)
		return true
	var pg := Pad.page_delta(event)
	if pg != 0:
		cycle_stats(ui, pg)
		return true
	if event.is_action_pressed("ui_left") and str(ui.inv_sel) == "stats":
		cycle_stats(ui, -1)
		return true
	if event.is_action_pressed("ui_right") and str(ui.inv_sel) == "stats":
		cycle_stats(ui, 1)
		return true
	return false

static func back_sub(ui: CanvasLayer) -> void:
	var phase := str(ui.get("forge_phase"))
	if phase == "work":
		ForgeUI.cancel_job(ui)
		return
	if phase == "pick":
		ForgeUI.keep_old(ui)
		return
	Sub.close_sub(ui)

static func is_tip(event: InputEvent) -> bool:
	if event is InputEventMouse:
		return false
	if event.is_action_pressed("gear_tip") and not event.is_echo():
		return true
	if event is InputEventKey and event.pressed and not event.echo:
		var k := event as InputEventKey
		return k.physical_keycode == KEY_Y or k.keycode == KEY_Y
	if event is InputEventJoypadButton and event.pressed:
		return (event as InputEventJoypadButton).button_index == JOY_BUTTON_Y
	return false


static func cycle_tip(ui: CanvasLayer) -> void:
	ui.gear_tip_mode = (int(ui.gear_tip_mode) + 1) % 3
	Board.refresh(ui)
	App.sfx("ui")


static func cycle_stats(ui: CanvasLayer, d: int) -> void:
	if bool(ui.get("gear_sub")) and str(ui.get("forge_phase")) != "pick":
		return
	var pages := Text.page_ids(ui)
	ui.gear_stat_page = posmod(int(ui.gear_stat_page) + d, pages.size())
	if str(ui.get("forge_phase")) != "pick":
		ui.inv_sel = "stats"
	Board._flag(ui, "gear_tip_ready", false)
	Board._flag(ui, "gear_hover", false)
	Board.hide_tip(ui)
	Board.refresh(ui)
	App.sfx("ui")
