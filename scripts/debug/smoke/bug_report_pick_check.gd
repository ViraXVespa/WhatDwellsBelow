extends Object

## Door/Job picker half of the P1 Report Bug check (bug_report_check.gd): pad walk, list cap, two taps.
## faults() names every check that failed ("pad: ..." / "tap: ..."), so a red smoke says which one.

const Pick := preload("res://scripts/ui/pause_settings/report_pick.gd")
const Send := preload("res://scripts/app/bug_report/bug_send.gd")

## Pad: A opens Door, down twice and A picks the 2nd door (Job enables, the description follows the highlight),
## then Job: A, down, A picks that door's first job. Changing the door again resets the job. Lists open under their
## button, below the description, capped (they scroll). Then two taps on a Door row.
static func faults(host: Node) -> PackedStringArray:
	var out: PackedStringArray = []
	if host == null or not host.is_inside_tree():
		return out
	var gs := GDScript.new()
	gs.source_code = "extends VBoxContainer\nvar info_box: VBoxContainer\nvar info_btns: Array = []\n"
	gs.reload()
	var h: VBoxContainer = gs.new()
	h.info_box = h
	host.add_child(h)
	var form := {"door": "", "job": ""}
	var obs: Array = Pick.build(h, form, func(c: Control) -> void:
		h.add_child(c)
		h.info_btns.append(c)
	)
	var dob: OptionButton = obs[0]
	var job: OptionButton = obs[1]
	var desc: Label = h.find_child("report_about", true, false)
	_need(out, job.disabled and h.info_btns.size() == 2, "pad: Job starts disabled, two picker buttons")
	var vp: Viewport = host.get_viewport()
	h.position.y = vp.get_visible_rect().end.y - 300.0  # near the bottom: the Door list must cap
	dob.grab_focus()
	for a: String in ["ui_accept", "ui_down", "ui_down"]:
		_tap(vp, a)
	var d2: Dictionary = Pick.doors()[1]
	var pop: PopupMenu = dob.get_popup()
	var top: float = dob.get_screen_position().y + dob.size.y
	_need(out, pop.visible, "pad: A opens the Door list")
	_need(out, desc.text == str(d2.about), "pad: the description follows the highlight")
	_need(out, desc.get_index() < dob.get_parent().get_index(), "pad: the description sits above the rows")
	_need(out, pop.position.y >= top - 1.0, "pad: the list opens under its button")
	_need(out, pop.position.y + pop.size.y <= vp.get_visible_rect().end.y + 1.0 and pop.size.y < 300, "pad: the list is capped to the room below")
	_tap(vp, "ui_accept")
	_need(out, form.door == str(d2.key) and not job.disabled and not pop.visible, "pad: A picks the door, enables Job and closes")
	var withjobs: Array = Pick.doors().filter(func(d: Dictionary) -> bool: return (d.jobs as Array).size() > 0)
	if out.is_empty() and not (d2.jobs as Array).is_empty():
		job.grab_focus()
		for a: String in ["ui_accept", "ui_down", "ui_accept"]:
			_tap(vp, a)
		_need(out, form.job == str(d2.jobs[0].key), "pad: A, down, A picks the first job")
	elif out.is_empty() and withjobs.size() > 0:
		dob.select(Pick.doors().find(withjobs[0]) + 1)
		dob.item_selected.emit(dob.selected)
		job.grab_focus()
		for a: String in ["ui_accept", "ui_down", "ui_accept"]:
			_tap(vp, a)
		_need(out, form.job == str(withjobs[0].jobs[0].key) and Send.category(form) == str(withjobs[0].key) + "." + form.job, "pad: A, down, A picks the first job")
	dob.select(0)
	dob.item_selected.emit(0)
	_need(out, form.door == "" and form.job == "" and job.disabled, "pad: changing the door resets the job")
	# A touch tap arrives as a click: the 1st picks + describes, the 2nd closes.
	dob.show_popup()
	_click(vp, pop, 3)
	_need(out, pop.visible and form.door == str(Pick.doors()[2].key) and desc.text == str(Pick.doors()[2].about), "tap: the 1st tap picks and describes, list open")
	_click(vp, pop, 3)
	_need(out, not pop.visible and form.door == str(Pick.doors()[2].key), "tap: the 2nd tap closes the list")
	h.queue_free()
	return out

static func _need(out: PackedStringArray, ok: bool, what: String) -> void:
	if not ok:
		out.append(what)

static func _click(vp: Viewport, pop: PopupMenu, i: int) -> void:
	var row_h: float = pop.get_theme_font("font").get_height(pop.get_theme_font_size("font_size")) + pop.get_theme_constant("v_separation")
	var top: float = pop.get_theme_stylebox("panel").get_margin(SIDE_TOP)
	var at: Vector2 = Vector2(pop.position) + Vector2(24.0, top + (i + 0.5) * row_h) * pop.content_scale_factor
	for down: bool in [true, false]:
		var e := InputEventMouseButton.new()
		e.button_index = MOUSE_BUTTON_LEFT
		e.position = at
		e.pressed = down
		vp.push_input(e, true)

static func _tap(vp: Viewport, action: String) -> void:
	for down: bool in [true, false]:
		var e := InputEventAction.new()
		e.action = action
		e.pressed = down
		vp.push_input(e)
