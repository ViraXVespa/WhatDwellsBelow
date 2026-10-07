extends Object

## Tappable prompt chip: one glyph + verb pair from a PromptView strip. A click or tap presses the
## named action while the pointer is down (so holds like gear_drop still work) and releases it on up.
## focus_mode NONE: a chip never takes tab, highlight or select focus, and never steals it from the menu.

const META := "prompt_action"

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
	# Deferred: an action parsed inside this mouse event would be dispatched as already handled.
	fire.call_deferred(str(chip.get_meta(META, "")), down)

## A press that closed the menu never sees its own pointer-up, so hiding the chip lets the action go.
static func _on_shown(chip: Control) -> void:
	if not chip.is_visible_in_tree():
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
