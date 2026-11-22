extends RefCounted

## Menu transitions probe (camp-menu-fade flow). Each getter acts or checks and returns "ok" / "" or the first fault.
## .open_pause / .close_pause / .toggle_pause drive App.pause_menu like the pad. .mid_in (one frame after open): drawn,
## open, not yet opaque, focus inside the menu. .rest_in: alpha 1, focus inside. .mid_out (one frame after close): the
## game owns input (ui_open off, tree running), the layer is a disabled ghost, no focus in it, ui_accept on a tab forced
## into focus does not fire. .rest_out: hidden, process mode back, alpha reset. .settled: open == visible, no ghost, ui_open and
## pause follow open (after rapid toggles). .off_instant: with the setting off, open is opaque at once and close hides
## at once. .map_mid / .map_rest: the large map is still fading / opaque. .plant_caught: a ghost left processing (the naive fade) and a ghost that keeps focus must both be caught.

const MenuFade := preload("res://scripts/ui/menu_fade.gd")

var open_pause: String:
	get:
		App.pause_menu.show_menu()
		return "ok"
var close_pause: String:
	get:
		App.pause_menu.close_ui()
		return "ok"
var toggle_pause: String:
	get:
		App.pause_menu.toggle()
		return "ok"
var mid_in: String:
	get:
		var pm: CanvasLayer = App.pause_menu
		if not pm.visible or not bool(pm.get("open")):
			return "mid_in: menu not open and drawn"
		var a: float = _alpha(pm)
		if a >= 0.999:
			return "mid_in: alpha %.3f: opaque at once (no fade)" % a
		return _focus_in(pm, "mid_in")
var rest_in: String:
	get:
		var pm: CanvasLayer = App.pause_menu
		if _alpha(pm) < 0.999 or MenuFade.ghosting(pm):
			return "rest_in: alpha %.3f ghost=%s" % [_alpha(pm), MenuFade.ghosting(pm)]
		return _focus_in(pm, "rest_in")
var mid_out: String:
	get:
		return ghost_faults(App.pause_menu)
var rest_out: String:
	get:
		var pm: CanvasLayer = App.pause_menu
		if pm.visible or MenuFade.ghosting(pm) or pm.process_mode != Node.PROCESS_MODE_ALWAYS or _alpha(pm) < 0.999:
			return "rest_out: visible=%s ghost=%s pm=%d alpha=%.2f" % [pm.visible, MenuFade.ghosting(pm), pm.process_mode, _alpha(pm)]
		return ""
var settled: String:
	get:
		var pm: CanvasLayer = App.pause_menu
		var is_open: bool = bool(pm.get("open"))
		if is_open != pm.visible or MenuFade.ghosting(pm) or App.ui_open != is_open or pm.get_tree().paused != is_open:
			return "settled: open=%s visible=%s ghost=%s ui_open=%s paused=%s" % [is_open, pm.visible, MenuFade.ghosting(pm), App.ui_open, pm.get_tree().paused]
		if pm.process_mode != Node.PROCESS_MODE_ALWAYS:
			return "settled: process mode %d" % pm.process_mode
		return _focus_in(pm, "settled") if is_open else ""
var off_instant: String:
	get:
		var pm: CanvasLayer = App.pause_menu
		MenuFade.enabled = false
		pm.show_menu()
		var a: float = _alpha(pm)
		pm.close_ui()
		var out: String = ""
		if a < 0.999:
			out = "off: open alpha %.2f" % a
		elif pm.visible or MenuFade.ghosting(pm):
			out = "off: close left the layer drawn"
		MenuFade.enabled = true
		return out
var plant_caught: String:
	get:
		var pm: CanvasLayer = App.pause_menu
		pm.show_menu()
		MenuFade._stop(pm)  # as if the fade-in had finished
		(pm.get_node(MenuFade.NODE) as CanvasModulate).color.a = 1.0
		pm.close_ui()
		if not MenuFade.ghosting(pm):
			return "plant: no ghost to plant on"
		pm.process_mode = Node.PROCESS_MODE_ALWAYS  # plant 1: the fade forgot to disable the ghost
		var one: bool = ghost_faults(pm).contains("ui_accept")
		pm.process_mode = Node.PROCESS_MODE_DISABLED
		var b: Control = _tab_button(pm)
		pm.process_mode = Node.PROCESS_MODE_ALWAYS  # plant 2: focus left on the ghost
		if b:
			b.grab_focus()
		pm.process_mode = Node.PROCESS_MODE_DISABLED
		var two: bool = ghost_faults(pm).contains("focus")
		pm.get_viewport().gui_release_focus()
		pm.close_ui()
		return "caught" if one and two else "missed one=%s two=%s" % [one, two]

var map_mid: String:
	get:
		var a: float = _alpha(_map_layer())
		return "" if a < 0.999 else "map: opaque at once (no fade)"
var map_rest: String:
	get:
		var a: float = _alpha(_map_layer())
		return "" if a >= 0.999 else "map: alpha %.2f at rest" % a

static func _map_layer() -> CanvasLayer:
	var tree: SceneTree = Engine.get_main_loop() as SceneTree
	var n: Node = tree.get_first_node_in_group("player")
	while n != null and not ("map_layer" in n):
		n = n.get_parent()
	return null if n == null else n.get("map_layer") as CanvasLayer

## Faults of a layer one frame after close; "" when it is a clean ghost.
static func ghost_faults(pm: CanvasLayer) -> String:
	if bool(pm.get("open")) or App.ui_open or pm.get_tree().paused:
		return "mid_out: still owns the game (open=%s ui_open=%s paused=%s)" % [pm.get("open"), App.ui_open, pm.get_tree().paused]
	if not pm.visible or not MenuFade.ghosting(pm):
		return "mid_out: closed at once (no fade out)"
	var owner_c: Control = pm.get_viewport().gui_get_focus_owner()
	if owner_c != null and pm.is_ancestor_of(owner_c):
		return "mid_out: focus still on the ghost"
	var b: Control = _tab_button(pm)
	if b == null:
		return "mid_out: no tab button to press"
	# Force focus onto a ghost tab and send ui_accept: a disabled ghost must not fire it.
	var hits: Array[int] = [0]
	var cb: Callable = func() -> void: hits[0] += 1
	b.connect("pressed", cb)
	b.grab_focus()
	for down: bool in [true, false]:
		var e: InputEventAction = InputEventAction.new()
		e.action = "ui_accept"
		e.pressed = down
		pm.get_viewport().push_input(e)
	b.disconnect("pressed", cb)
	pm.get_viewport().gui_release_focus()
	return "mid_out: ui_accept reached the ghost" if hits[0] > 0 else ""

static func _tab_button(pm: CanvasLayer) -> Button:
	var tabs: Node = pm.get("tabs")
	if tabs == null:
		return null
	for n: Node in tabs.find_children("*", "Button", true, false):
		var b: Button = n
		if b.is_visible_in_tree() and b.focus_mode != Control.FOCUS_NONE:
			return b
	return null

static func _alpha(layer: CanvasLayer) -> float:
	var m: CanvasModulate = layer.get_node_or_null(MenuFade.NODE) as CanvasModulate
	return 1.0 if m == null else m.color.a

static func _focus_in(layer: CanvasLayer, tag: String) -> String:
	var owner_c: Control = layer.get_viewport().gui_get_focus_owner()
	if owner_c == null or not layer.is_ancestor_of(owner_c):
		return "%s: focus %s is not in the menu" % [tag, "none" if owner_c == null else str(owner_c.get_path())]
	return ""
