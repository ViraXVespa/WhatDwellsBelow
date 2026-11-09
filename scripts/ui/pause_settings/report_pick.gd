extends Object

## Report Bug Door and Job comboboxes (OptionButton, opened and walked with the pad) and the description line under
## them. Names and one-line descriptions come from scripts/data/bug_doors.json (tools/relay/gen-doors.mjs, from
## design/routes.yaml doors and their docs). Door first: Job lists that door's jobs and stays disabled until a door
## is picked; a new door resets the job. Both optional: no door is triage, a door with no job files under the door.

const ThemeS := preload("res://scripts/ui/theme.gd")
const UiText := preload("res://scripts/ui/ui_text.gd")
const View := preload("res://scripts/ui/split_menu/split_menu_view.gd")
const PATH := "res://scripts/data/bug_doors.json"

static var _doors: Array = []

static func doors() -> Array:
	if _doors.is_empty():
		var d: Variant = JSON.parse_string(FileAccess.get_file_as_string(PATH))
		if d is Dictionary and (d as Dictionary).get("doors") is Array:
			_doors = (d as Dictionary).doors
	return _doors

static func door(key: String) -> Dictionary:
	for d: Variant in doors():
		if d is Dictionary and str((d as Dictionary).get("key", "")) == key:
			return d
	return {}

static func jobs(key: String) -> Array:
	return door(key).get("jobs", []) as Array

## Description for item idx (0 = none) of the door list, or of door_key's job list.
static func about(door_key: String, idx: int, is_job: bool) -> String:
	if is_job:
		if door_key == "":
			return App.tr("bug_report.job_pick_door")
		var js: Array = jobs(door_key)
		return App.tr("bug_report.job_none_about") if idx <= 0 or idx > js.size() else str(js[idx - 1].get("about", ""))
	return App.tr("bug_report.door_none_about") if idx <= 0 or idx > doors().size() else str(doors()[idx - 1].get("about", ""))

## Adds the Door row, Job row and description label to the page; field(c) styles and registers a focusable control.
static func build(host: Node, form: Dictionary, field: Callable) -> Array[OptionButton]:
	var desc: Label = ThemeS.lab("", 16, ThemeS.INK_SOFT, HORIZONTAL_ALIGNMENT_LEFT)
	desc.name = "report_about"
	desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	desc.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var dob := OptionButton.new()
	dob.name = "report_door"
	dob.add_item(App.tr("bug_report.door_none"))
	for d: Variant in doors():
		dob.add_item(str((d as Dictionary).get("name", "")))
	dob.select(maxi(0, doors().find(door(str(form.door))) + 1) if str(form.door) != "" else 0)
	var job := OptionButton.new()
	job.name = "report_job"
	_fill_jobs(job, str(form.door), str(form.job))
	var tell := func(ob: OptionButton, idx: int) -> void:
		desc.text = about(str(form.door), idx, ob == job)
	dob.item_selected.connect(func(i: int) -> void:
		form.door = "" if i <= 0 else str(doors()[i - 1].get("key", ""))
		form.job = ""
		_fill_jobs(job, str(form.door), "")
		View.wire_vert(host.info_btns)  # a disabled Job is out of the pad ring until a door enables it
		tell.call(dob, i)
	)
	job.item_selected.connect(func(i: int) -> void:
		var js: Array = jobs(str(form.door))
		form.job = "" if i <= 0 or i > js.size() else str(js[i - 1].get("key", ""))
		tell.call(job, i)
	)
	for ob: OptionButton in [dob, job]:
		ob.get_popup().id_focused.connect(func(id: int) -> void: tell.call(ob, ob.get_item_index(id)))
		ob.focus_entered.connect(func() -> void: tell.call(ob, ob.selected))
		_row(host, App.tr("bug_report.door" if ob == dob else "bug_report.job"), ob, field)
	tell.call(dob, dob.selected)
	host.info_box.add_child(desc)
	return [dob, job]

static func _fill_jobs(job: OptionButton, door_key: String, pick: String) -> void:
	job.clear()
	job.add_item(App.tr("bug_report.job_none") if door_key != "" else App.tr("bug_report.job_pick_door"))
	var at := 0
	for j: Variant in jobs(door_key):
		job.add_item(str((j as Dictionary).get("name", "")))
		if str((j as Dictionary).get("key", "")) == pick:
			at = job.item_count - 1
	job.select(at)
	job.disabled = door_key == ""
	job.focus_mode = Control.FOCUS_NONE if job.disabled else Control.FOCUS_ALL  # set_col_focus parks disabled rows

static func _row(host: Node, title: String, ob: OptionButton, field: Callable) -> void:
	var row := HBoxContainer.new()
	row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var lab: Label = ThemeS.lab(title, 20, ThemeS.INK, HORIZONTAL_ALIGNMENT_LEFT)
	lab.custom_minimum_size = UiText.min_size(90.0, 0.0)
	row.add_child(lab)
	host.info_box.add_child(row)
	field.call(ob)
	ob.reparent(row)
	ob.fit_to_longest_item = false
	ob.custom_minimum_size = UiText.min_size(0.0, 44.0)
	var base: StyleBox = ob.get_theme_stylebox("normal")
	for k: String in ["hover", "pressed", "disabled", "hover_pressed"]:
		ob.add_theme_stylebox_override(k, base)
	ob.add_theme_color_override("font_disabled_color", ThemeS.INK_FAINT)
	for k: String in ["font_hover_color", "font_pressed_color", "font_focus_color"]:
		ob.add_theme_color_override(k, ThemeS.INK)
	var pop: PopupMenu = ob.get_popup()
	pop.add_theme_font_override("font", ThemeS.ink_font())
	pop.add_theme_font_size_override("font_size", 20)
	pop.add_theme_color_override("font_color", ThemeS.INK)
	pop.add_theme_color_override("font_hover_color", ThemeS.INK)
	var sb := StyleBoxFlat.new()
	sb.bg_color = ThemeS.PAPER
	sb.border_color = ThemeS.INK_SOFT
	sb.set_border_width_all(2)
	sb.set_content_margin_all(6)
	pop.add_theme_stylebox_override("panel", sb)
	var hov := StyleBoxFlat.new()
	hov.bg_color = ThemeS.PAPER.darkened(0.15)
	pop.add_theme_stylebox_override("hover", hov)
