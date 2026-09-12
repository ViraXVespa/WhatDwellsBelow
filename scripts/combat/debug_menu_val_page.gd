extends Object

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
				load("res://scripts/combat/debug_menu_val.gd").val_cancel(host)
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
			load("res://scripts/combat/debug_menu_val.gd").fly(host, nm)
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
		shell.add_theme_stylebox_override("panel", load("res://scripts/combat/debug_menu_val.gd").val_sb(host, sel, edit))
		sp.add_theme_stylebox_override("normal", load("res://scripts/combat/debug_menu_val.gd").val_spin_sb(host, sel, edit))
		sp.add_theme_stylebox_override("focus", load("res://scripts/combat/debug_menu_val.gd").val_spin_sb(host, sel, edit))
		sp.add_theme_stylebox_override("read_only", load("res://scripts/combat/debug_menu_val.gd").val_spin_sb(host, sel, edit))
		if sel:
			lab.add_theme_color_override("font_color", Color(1, 0.94, 0.7))
		else:
			lab.remove_theme_color_override("font_color")
	if str(host.val_mode) == "cats":
		host.status.text = "Values. Up/Down a column. Left/Right columns. A opens a category. B closes."
		load("res://scripts/combat/debug_menu_val.gd").val_reveal.bind(host).call_deferred()
		return
	var cur: Dictionary = host.val_rows[host.val_i]
	load("res://scripts/combat/debug_menu_val.gd").fly(host, str(cur.name))
	if host.val_edit:
		host.status.text = "Editing %s — Up/Down changes value. B unfocuses." % str(cur.name)
	else:
		host.status.text = "Vars. Up/Down move. A edits. B back to categories."
	load("res://scripts/combat/debug_menu_val.gd").val_reveal.bind(host).call_deferred()



static func val_nudge(host, delta_i: int) -> void:
	if host.val_edit or str(host.val_mode) == "edit":
		if host.val_rows.is_empty():
			return
		var row: Dictionary = host.val_rows[host.val_i]
		var sp: SpinBox = row.sp
		sp.value = clampf(sp.value + float(row.step) * float(delta_i), float(row.lo), float(row.hi))
		load("res://scripts/combat/debug_menu_val.gd").fly(host, str(row.name))
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



static func page_profiles(host) -> void:
	host.status.text = "Unlimited named profiles. Saved under user://wdb_profiles/"
	var le := LineEdit.new()
	le.text = host.profile_name
	le.custom_minimum_size = Vector2(360, 36)
	le.focus_mode = Control.FOCUS_ALL
	le.text_changed.connect(func(t): host.profile_name = t)
	host.root_box.add_child(le)
	host.root_box.add_child(host._btn("Save", func(): load("res://scripts/combat/debug_menu_val.gd").save_profile(host); host.status.text = "Saved " + host.profile_name))
	host.root_box.add_child(host._btn("Load", func(): load("res://scripts/combat/debug_menu_val.gd").load_profile(host); host.status.text = "Loaded " + host.profile_name; host.page = "values"; host._rebuild()))
	host.root_box.add_child(host._btn("Delete", func(): load("res://scripts/combat/debug_menu_val.gd").delete_profile(host); host.status.text = "Deleted " + host.profile_name))
	host.root_box.add_child(host._btn("Rename current to field", func(): load("res://scripts/combat/debug_menu_val.gd").rename_profile(host); host.status.text = "Renamed"))
	host.root_box.add_child(Label.new())
	for n in load("res://scripts/combat/debug_menu_val.gd").list_profiles():
		var nm := n
		host.root_box.add_child(host._btn("Load " + nm, func(): host.profile_name = nm; load("res://scripts/combat/debug_menu_val.gd").load_profile(host); host.status.text = "Loaded " + nm))



