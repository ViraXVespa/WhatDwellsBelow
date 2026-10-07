extends Object

## Tappable prompt chip: one glyph + verb pair from a PromptView strip. A click or tap presses the
## named action while the pointer is down (so holds like gear_drop still work) and releases it on up.
## focus_mode NONE: a chip never takes tab, highlight or select focus, and never steals it from the menu.

const Tok: GDScript = preload("res://scripts/ui/ui_tokens.gd")

const META := "prompt_action"
const FLASH_SEC := 0.12

static func make(host: Control, action: String) -> HBoxContainer:
	var chip := HBoxContainer.new()
	chip.set_meta(META, action)
	chip.focus_mode = Control.FOCUS_NONE
	chip.mouse_filter = Control.MOUSE_FILTER_STOP
	chip.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	chip.add_theme_constant_override("separation", host.get_theme_constant("separation"))
	chip.gui_input.connect(func(ev: InputEvent): _on_input(chip, ev))
	chip.tree_exiting.connect(func(): _release(chip))
	chip.visibility_changed.connect(func(): _on_shown(chip))
	chip.mouse_entered.connect(func(): _tint(chip, true))
	chip.mouse_exited.connect(func(): _tint(chip, false))
	return chip

static func _on_input(chip: Control, ev: InputEvent) -> void:
	if not (ev is InputEventMouseButton) or (ev as InputEventMouseButton).button_index != MOUSE_BUTTON_LEFT:
		return
	chip.accept_event()
	var down: bool = (ev as InputEventMouseButton).pressed
	if down == bool(chip.get_meta("prompt_down", false)):
		if not down:
			return
		_release(chip)
	chip.set_meta("prompt_down", down)
	if down:
		_flash(chip)
	# Deferred: an action parsed inside this mouse event would be dispatched as already handled.
	fire.call_deferred(str(chip.get_meta(META, "")), down)

static func _tint(chip: Control, over: bool) -> void:
	chip.set_meta("prompt_over", over)
	if not chip.has_meta("prompt_flash"):
		chip.modulate = Tok.CHIP_HOVER if over else Tok.CHIP_REST

## Press flash: dims for a beat even on a quick tap, then back to hover or rest.
static func _flash(chip: Control) -> void:
	chip.set_meta("prompt_flash", true)
	chip.modulate = Tok.CHIP_PRESS
	chip.get_tree().create_timer(FLASH_SEC, true, false, true).timeout.connect(func():
		if not is_instance_valid(chip):
			return
		chip.remove_meta("prompt_flash")
		_tint(chip, bool(chip.get_meta("prompt_over", false))))

## A press that closed the menu never sees its own pointer-up, so hiding the chip lets the action go.
static func _on_shown(chip: Control) -> void:
	if not chip.is_visible_in_tree():
		chip.set_meta("prompt_over", false)
		chip.modulate = Tok.CHIP_REST
		_release(chip)

static func _release(chip: Control) -> void:
	if bool(chip.get_meta("prompt_down", false)):
		chip.set_meta("prompt_down", false)
		fire.call_deferred(str(chip.get_meta(META, "")), false)

## Same path as a key or pad press: every menu's own handler decides what the action does.
static func fire(action: String, down: bool) -> void:
	if action == "" or not InputMap.has_action(action):
		return
	var a := InputEventAction.new()
	a.action = action
	a.pressed = down
	Input.parse_input_event(a)
