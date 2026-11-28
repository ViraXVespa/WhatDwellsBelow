extends RefCounted

## Bow mode (Settings > Gameplay, saved as bow_mode, off by default). Off: the longbow fires on Attack (X / LMB)
## toward the facing, like every weapon, and the triggers stay free. On, with the longbow equipped: hold Aim (LT /
## Shift / the touch bow stick) to aim: the right stick, mouse or bow stick steers, walking slows and does not turn
## the aim, a manual aim outranks target lock, and the aim line shows even when it is off in Settings. Fire (RT, or
## the bow stick while held) shoots; Attack still shoots too.

const Touch := preload("res://scripts/input/touch_pad.gd")

static var enabled := false

static func active() -> bool:
	return enabled and str(App.weapon) == "longbow"

static func aiming() -> bool:
	if not active() or App.ui_open:
		return false
	return App.pad_held("aim") or Touch.held("aim")

## Bow mode's own fire input (RT; the touch bow stick reports Fire while a finger is on it).
static func fire_held() -> bool:
	return active() and not App.ui_open and App.pad_held("fire")

## The aim direction while aiming: right stick / touch bow stick, else mouse on keyboard, else unchanged.
static func steer(host: Node, stick: Vector2, mouse_dir: Vector2) -> void:
	if stick.length() >= 0.24:
		host.aim_dir = stick.normalized()
	elif not App.using_pad() and mouse_dir.length_squared() > 0.0001:
		host.aim_dir = mouse_dir
