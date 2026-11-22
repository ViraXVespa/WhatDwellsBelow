extends Object

## Touch half of the P1 Report Bug check (bug_report_check.gd): what a phone needs for its keyboard.
## faults() names every check that failed.
## - Web fullscreen goes on the page root, not #canvas: Godot's virtual keyboard is a hidden <input> beside the canvas,
##   and Chromium makes everything outside the fullscreen element inert (the input can't focus, no keyboard).
## - A tap on a Report Bug text field (a touch the engine turns into an emulated left click, as on the web) focuses it
##   and starts editing; LineEdit asks DisplayServer for the keyboard from there (Godot 4.7.2 line_edit.cpp).

const Desk := preload("res://scripts/display_mode/mode_desk.gd")
const Page := preload("res://scripts/ui/pause_settings/report_page.gd")

static func faults(host: Node) -> PackedStringArray:
	var out: PackedStringArray = []
	var js: String = Desk.REQUEST_FS_JS
	var root_at: int = js.find("document.documentElement")
	var canvas_at: int = js.find("getElementById('canvas')")
	if root_at < 0 or (canvas_at >= 0 and canvas_at < root_at):
		out.append("fullscreen: web fullscreen must target the page root before #canvas")
	if host == null or not host.is_inside_tree():
		return out
	var gs := GDScript.new()
	gs.source_code = "extends VBoxContainer\nvar info_box: VBoxContainer\nvar info_btns: Array = []\n"
	gs.reload()
	var h: VBoxContainer = gs.new()
	h.info_box = h
	h.size = Vector2(1200, 900)
	host.add_child(h)
	var keep: Dictionary = Page.form.duplicate()
	Page.build(h)
	var vp: Viewport = host.get_viewport()
	for c: Variant in h.info_btns:
		if not (c is LineEdit or c is TextEdit):
			continue
		var f: Control = c
		f.custom_minimum_size.y = maxf(f.custom_minimum_size.y, 40.0)
		h.notification(Container.NOTIFICATION_SORT_CHILDREN)  # lay out now (the smoke runs in one frame)
		vp.gui_release_focus()
		var at: Vector2 = f.get_global_rect().get_center()
		for down: bool in [true, false]:
			var e := InputEventMouseButton.new()
			e.device = InputEvent.DEVICE_ID_EMULATION
			e.button_index = MOUSE_BUTTON_LEFT
			e.position = at
			e.global_position = at
			e.pressed = down
			vp.push_input(e, true)
		var editing: bool = not (f is LineEdit) or (f as LineEdit).is_editing()
		if not f.has_focus() or not editing:
			out.append("touch: a tap on %s does not focus and edit it" % f.get_class())
	vp.gui_release_focus()
	Page.form = keep
	h.queue_free()
	return out
