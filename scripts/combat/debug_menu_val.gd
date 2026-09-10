extends Object

## Values and profile page handlers for DebugMenu.

const Grid := preload("res://scripts/combat/debug_menu_val_grid.gd")


static func page_values(host) -> void:
	host.val_i = 0
	host.val_edit = false
	if host.get("val_mode") == null:
		host.set("val_mode", "cats")
	else:
		host.val_mode = "cats"
	if host.get("val_cat_i") == null:
		host.set("val_cat_i", 0)
	else:
		host.val_cat_i = 0
	host.status.text = "Values. Up/Down a column. Left/Right columns. A opens a category."
	host.fly = Label.new()
	host.fly.add_theme_font_size_override("font_size", 16)
	host.fly.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	host.fly.mouse_filter = Control.MOUSE_FILTER_IGNORE
	host.fly.text = "Highlight a variable for fly-out ideals."
	host.root_box.add_child(host.fly)
	Grid.build(host)


static func add_row(host, parent: Control, name: String, lo: float, hi: float, step: float) -> void:
	var shell := PanelContainer.new()
	shell.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	shell.mouse_filter = Control.MOUSE_FILTER_STOP
	var idx: int = host.val_rows.size()
	shell.gui_input.connect(func(ev: InputEvent):
		if ev is InputEventMouseButton and ev.pressed and ev.button_index == MOUSE_BUTTON_LEFT:
			if host.val_edit and host.val_i != idx:
				val_cancel(host)
			host.val_i = idx
			host.val_mode = "vars"
			val_paint(host)
	)
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 12)
	var lab := Label.new()
	lab.text = name
	lab.custom_minimum_size = Vector2(280, 0)
	lab.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	lab.mouse_filter = Control.MOUSE_FILTER_IGNORE
	h.add_child(lab)
	var sp := SpinBox.new()
	sp.min_value = lo
	sp.max_value = hi
	sp.step = step
	sp.custom_minimum_size = Vector2(200, 36)
	sp.focus_mode = Control.FOCUS_NONE
	sp.mouse_filter = Control.MOUSE_FILTER_STOP
	sp.value = App.bal.getv(name)
	sp.value_changed.connect(func(v):
		if not host.val_edit:
			App.bal.setv(name, v)
	)
	var nm := name
	sp.mouse_entered.connect(func():
		if not host.val_edit:
			fly(host, nm)
	)
	h.add_child(sp)
	shell.add_child(h)
	parent.add_child(shell)
	host.spins[name] = sp
	host.val_rows.append({
		"wrap": shell,
		"lab": lab,
		"sp": sp,
		"name": name,
		"lo": lo,
		"hi": hi,
		"step": step,
	})


static func fly(host, name: String) -> void:
	if host.fly == null or host.play == null:
		return
	var f := 0.0
	var p := 0.0
	if host.play.has_method("ideal_for"):
		f = host.play.ideal_for(name, "fresh")
		p = host.play.ideal_for(name, "progressed")
	var cur := App.bal.getv(name)
	if host.val_edit and host.val_i >= 0 and host.val_i < host.val_rows.size() and str(host.val_rows[host.val_i].name) == name:
		cur = float(host.val_rows[host.val_i].sp.value)
	host.fly.text = "%s  ·  fresh ideal %.2f  ·  progressed ideal %.2f  ·  current %.2f" % [name, f, p, cur]


static func val_sb(_host, sel: bool, edit: bool) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = Color(0.08, 0.07, 0.07, 0.55)
	s.border_color = Color(0.22, 0.18, 0.14, 1)
	s.set_border_width_all(1)
	s.set_content_margin_all(8)
	if sel:
		s.bg_color = Color(0.22, 0.16, 0.08, 0.95)
		s.border_color = Color(0.95, 0.78, 0.35, 1)
		s.set_border_width_all(3)
	if edit:
		s.bg_color = Color(0.32, 0.22, 0.08, 1)
		s.border_color = Color(1, 0.9, 0.45, 1)
	return s


static func val_spin_sb(_host, sel: bool, edit: bool) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = Color(0.1, 0.09, 0.08, 1)
	s.border_color = Color(0.3, 0.24, 0.18, 1)
	s.set_border_width_all(1)
	s.set_content_margin_all(6)
	if sel:
		s.bg_color = Color(0.18, 0.14, 0.08, 1)
		s.border_color = Color(0.95, 0.78, 0.35, 1)
		s.set_border_width_all(2)
	if edit:
		s.bg_color = Color(0.08, 0.08, 0.1, 1)
		s.border_color = Color(1, 0.92, 0.5, 1)
	return s


static func val_paint(host) -> void:
	Grid.paint_cats(host)
	var n: int = host.val_rows.size()
	if n == 0:
		return
	host.val_i = clampi(host.val_i, 0, n - 1)
	for i in n:
		var row: Dictionary = host.val_rows[i]
		var shell: PanelContainer = row.wrap
		var sp: SpinBox = row.sp
		var lab: Label = row.lab
		var sel: bool = i == host.val_i and str(host.val_mode) != "cats"
		var edit: bool = sel and host.val_edit
		shell.add_theme_stylebox_override("panel", val_sb(host, sel, edit))
		sp.add_theme_stylebox_override("normal", val_spin_sb(host, sel, edit))
		sp.add_theme_stylebox_override("focus", val_spin_sb(host, sel, edit))
		sp.add_theme_stylebox_override("read_only", val_spin_sb(host, sel, edit))
		if sel:
			lab.add_theme_color_override("font_color", Color(1, 0.94, 0.7))
		else:
			lab.remove_theme_color_override("font_color")
	if str(host.val_mode) == "cats":
		host.status.text = "Values. Up/Down a column. Left/Right columns. A opens a category. B closes."
		val_reveal.bind(host).call_deferred()
		return
	var cur: Dictionary = host.val_rows[host.val_i]
	fly(host, str(cur.name))
	if host.val_edit:
		host.status.text = "Editing %s — Up/Down changes value. B unfocuses." % str(cur.name)
	else:
		host.status.text = "Vars. Up/Down move. A edits. B back to categories."
	val_reveal.bind(host).call_deferred()


static func val_reveal(host) -> void:
	if host.scroll == null:
		return
	var shell: Control = null
	if str(host.val_mode) == "cats":
		shell = Grid.cat_wrap(host)
	elif host.val_i >= 0 and host.val_i < host.val_rows.size():
		shell = host.val_rows[host.val_i].wrap
	if shell and not shell.is_queued_for_deletion() and host.scroll.has_method("ensure_control_visible"):
		host.scroll.ensure_control_visible(shell)


static func val_nudge(host, delta_i: int) -> void:
	if host.val_edit or str(host.val_mode) == "edit":
		if host.val_rows.is_empty():
			return
		var row: Dictionary = host.val_rows[host.val_i]
		var sp: SpinBox = row.sp
		sp.value = clampf(sp.value + float(row.step) * float(delta_i), float(row.lo), float(row.hi))
		fly(host, str(row.name))
		return
	if str(host.val_mode) == "vars":
		if host.val_rows.is_empty():
			return
		var n: int = host.val_rows.size()
		host.val_i = (host.val_i + delta_i + n) % n
		val_paint(host)
		return
	Grid.nudge_cat(host, delta_i)
	val_paint(host)


static func val_nudge_col(host, delta_i: int) -> void:
	if host.val_edit or str(host.val_mode) == "vars" or str(host.val_mode) == "edit":
		return
	Grid.nudge_col(host, delta_i)
	val_paint(host)


static func val_accept(host) -> void:
	if str(host.val_mode) == "cats":
		Grid.open_cat(host)
		val_paint(host)
		return
	if host.val_rows.is_empty():
		return
	var row: Dictionary = host.val_rows[host.val_i]
	var sp: SpinBox = row.sp
	if host.val_edit:
		App.bal.setv(str(row.name), sp.value)
		host.val_edit = false
		host.val_mode = "vars"
		val_paint(host)
		return
	host.val_backup = sp.value
	host.val_edit = true
	host.val_mode = "edit"
	val_paint(host)


static func val_cancel(host) -> bool:
	if host.val_edit:
		if host.val_rows.is_empty():
			host.val_edit = false
			host.val_mode = "vars"
			val_paint(host)
			return true
		var row: Dictionary = host.val_rows[host.val_i]
		var sp: SpinBox = row.sp
		sp.value = host.val_backup
		App.bal.setv(str(row.name), host.val_backup)
		host.val_edit = false
		host.val_mode = "vars"
		val_paint(host)
		return true
	if str(host.val_mode) == "vars" or str(host.val_mode) == "edit":
		Grid.close_cat(host)
		val_paint(host)
		return true
	return false


static func page_profiles(host) -> void:
	host.status.text = "Unlimited named profiles. Saved under user://wdb_profiles/"
	var le := LineEdit.new()
	le.text = host.profile_name
	le.custom_minimum_size = Vector2(360, 36)
	le.focus_mode = Control.FOCUS_ALL
	le.text_changed.connect(func(t): host.profile_name = t)
	host.root_box.add_child(le)
	host.root_box.add_child(host._btn("Save", func(): save_profile(host); host.status.text = "Saved " + host.profile_name))
	host.root_box.add_child(host._btn("Load", func(): load_profile(host); host.status.text = "Loaded " + host.profile_name; host.page = "values"; host._rebuild()))
	host.root_box.add_child(host._btn("Delete", func(): delete_profile(host); host.status.text = "Deleted " + host.profile_name))
	host.root_box.add_child(host._btn("Rename current to field", func(): rename_profile(host); host.status.text = "Renamed"))
	host.root_box.add_child(Label.new())
	for n in list_profiles():
		var nm := n
		host.root_box.add_child(host._btn("Load " + nm, func(): host.profile_name = nm; load_profile(host); host.status.text = "Loaded " + nm))


static func dir() -> String:
	return "user://wdb_profiles"


static func list_profiles() -> PackedStringArray:
	var d := DirAccess.open("user://")
	if d and not d.dir_exists("wdb_profiles"):
		d.make_dir("wdb_profiles")
	var out: PackedStringArray = PackedStringArray()
	var pd := DirAccess.open(dir())
	if pd == null:
		return out
	pd.list_dir_begin()
	var f := pd.get_next()
	while f != "":
		if f.ends_with(".json"):
			out.append(f.get_basename())
		f = pd.get_next()
	return out


static func save_profile(host) -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(dir()))
	var data := {}
	for row in App.bal.schema():
		data[str(row[0])] = App.bal.getv(str(row[0]))
	var f := FileAccess.open("%s/%s.json" % [dir(), host.profile_name], FileAccess.WRITE)
	if f:
		f.store_string(JSON.stringify(data))
		host.loaded_profile = host.profile_name


static func load_profile(host) -> void:
	var f := FileAccess.open("%s/%s.json" % [dir(), host.profile_name], FileAccess.READ)
	if f == null:
		host.status.text = "Missing profile."
		return
	var parsed: Variant = JSON.parse_string(f.get_as_text())
	if parsed is Dictionary:
		var d: Dictionary = parsed
		for k in d.keys():
			App.bal.setv(str(k), float(d[k]))
		host.loaded_profile = host.profile_name


static func delete_profile(host) -> void:
	DirAccess.remove_absolute(ProjectSettings.globalize_path("%s/%s.json" % [dir(), host.profile_name]))


static func rename_profile(host) -> void:
	var prev: String = host.loaded_profile
	save_profile(host)
	if prev != "" and prev != host.profile_name:
		DirAccess.remove_absolute(ProjectSettings.globalize_path("%s/%s.json" % [dir(), prev]))
	host.loaded_profile = host.profile_name
