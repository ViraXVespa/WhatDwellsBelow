extends Object

## Two-column Values categories. Expand-in-place under the category cell.

const CATS: Array[String] = [
	"Player",
	"Movement",
	"Combat",
	"Great Axe",
	"Enemies",
	"Camera",
	"Dungeon",
	"Economy",
	"UI",
	"Other",
]


static func _val():
	return load("res://scripts/combat/debug_menu_val.gd")


static func cat_of(name: String) -> String:
	var n := name.to_lower()
	if n.begins_with("axe") or n.begins_with("ga_") or n.contains("greataxe") or n.contains("great_axe"):
		return "Great Axe"
	if n.begins_with("enemy") or n.begins_with("mob") or n.begins_with("ai_") or n.begins_with("aggro"):
		return "Enemies"
	if n.begins_with("cam") or n.begins_with("zoom") or n.begins_with("look"):
		return "Camera"
	if n.begins_with("floor") or n.begins_with("room") or n.begins_with("dung") or n.begins_with("door") or n.begins_with("spawn"):
		return "Dungeon"
	if n.begins_with("gold") or n.begins_with("ore") or n.begins_with("root") or n.begins_with("shop") or n.begins_with("price"):
		return "Economy"
	if n.begins_with("ui_") or n.begins_with("hud") or n.begins_with("tip") or n.begins_with("font"):
		return "UI"
	if n.begins_with("atk") or n.begins_with("hit") or n.begins_with("hurt") or n.begins_with("poise") or n.begins_with("iframe") or n.begins_with("special"):
		return "Combat"
	if n.begins_with("walk") or n.begins_with("dash") or n.begins_with("spd") or n.begins_with("move") or n.begins_with("accel"):
		return "Movement"
	if n.begins_with("hp") or n.begins_with("player") or n.begins_with("stam") or n.begins_with("heal"):
		return "Player"
	return "Other"


static func _left_n(n: int) -> int:
	return int(ceili(float(n) / 2.0))


static func _ensure_cats(host) -> void:
	if host.get("val_cats") == null:
		host.set("val_cats", [])
	if host.get("val_cat_i") == null:
		host.set("val_cat_i", 0)
	if host.get("val_mode") == null:
		host.set("val_mode", "cats")


static func cat_wrap(host) -> Control:
	_ensure_cats(host)
	var cats: Array = host.val_cats
	var i: int = clampi(int(host.val_cat_i), 0, maxi(0, cats.size() - 1))
	if i < 0 or i >= cats.size():
		return null
	return cats[i].wrap


static func build(host) -> void:
	_ensure_cats(host)
	host.val_cats = []
	host.val_rows.clear()
	var grid := HBoxContainer.new()
	grid.add_theme_constant_override("separation", 16)
	grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var col0 := VBoxContainer.new()
	col0.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	col0.add_theme_constant_override("separation", 6)
	var col1 := VBoxContainer.new()
	col1.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	col1.add_theme_constant_override("separation", 6)
	grid.add_child(col0)
	grid.add_child(col1)
	host.root_box.add_child(grid)
	var n: int = CATS.size()
	var left_n: int = _left_n(n)
	for i in n:
		var parent: Control = col0 if i < left_n else col1
		_add_cat(host, parent, CATS[i], i)
	host.val_cat_i = 0
	host.val_mode = "cats"
	paint_cats(host)


static func _add_cat(host, parent: Control, title: String, idx: int) -> void:
	var shell := VBoxContainer.new()
	shell.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	shell.add_theme_constant_override("separation", 4)
	var btn := Button.new()
	btn.text = title
	btn.focus_mode = Control.FOCUS_ALL
	btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	btn.custom_minimum_size = Vector2(0, 44)
	btn.pressed.connect(func():
		host.val_cat_i = idx
		if str(host.val_mode) == "vars" or str(host.val_mode) == "edit":
			close_cat(host)
		open_cat(host)
		_val().val_paint(host)
	)
	btn.focus_entered.connect(func():
		if str(host.val_mode) == "cats":
			host.val_cat_i = idx
			paint_cats(host)
	)
	var body := VBoxContainer.new()
	body.visible = false
	body.add_theme_constant_override("separation", 4)
	shell.add_child(btn)
	shell.add_child(body)
	parent.add_child(shell)
	host.val_cats.append({
		"name": title,
		"wrap": shell,
		"btn": btn,
		"body": body,
	})


static func paint_cats(host) -> void:
	_ensure_cats(host)
	var cats: Array = host.val_cats
	if cats.is_empty():
		return
	host.val_cat_i = clampi(int(host.val_cat_i), 0, cats.size() - 1)
	for i in cats.size():
		var btn: Button = cats[i].btn
		var on: bool = i == int(host.val_cat_i)
		if on:
			btn.add_theme_color_override("font_color", Color(1, 0.92, 0.45))
			btn.add_theme_color_override("font_focus_color", Color(1, 0.92, 0.45))
		else:
			btn.add_theme_color_override("font_color", Color(1, 1, 1, 1))
			btn.add_theme_color_override("font_focus_color", Color(1, 1, 1, 1))
		if str(host.val_mode) == "cats" and on:
			btn.grab_focus()


static func _clear_vars(host) -> void:
	host.val_rows.clear()
	var cats: Array = host.val_cats
	for cat in cats:
		var body: Control = cat.body
		for c in body.get_children():
			c.queue_free()
		body.visible = false


static func open_cat(host) -> void:
	_ensure_cats(host)
	var cats: Array = host.val_cats
	if cats.is_empty():
		return
	host.val_cat_i = clampi(int(host.val_cat_i), 0, cats.size() - 1)
	_clear_vars(host)
	var cat: Dictionary = cats[host.val_cat_i]
	var body: Control = cat.body
	var title: String = str(cat.name)
	var Val = _val()
	for row in App.bal.schema():
		var nm := str(row[0])
		if cat_of(nm) != title:
			continue
		Val.add_row(host, body, nm, float(row[1]), float(row[2]), float(row[3]))
	body.visible = true
	host.val_i = 0
	host.val_edit = false
	host.val_mode = "vars"
	if host.val_rows.is_empty():
		var empty := Label.new()
		empty.text = "No tunables in this category."
		empty.add_theme_color_override("font_color", Color(0.8, 0.74, 0.66))
		body.add_child(empty)


static func close_cat(host) -> void:
	host.val_edit = false
	_clear_vars(host)
	host.val_mode = "cats"
	paint_cats(host)


static func nudge_cat(host, delta_i: int) -> void:
	_ensure_cats(host)
	var n: int = host.val_cats.size()
	if n == 0:
		return
	var left_n: int = _left_n(n)
	var i: int = int(host.val_cat_i)
	var col: int = 0 if i < left_n else 1
	var start: int = 0 if col == 0 else left_n
	var count: int = left_n if col == 0 else n - left_n
	if count <= 0:
		return
	var local: int = i - start
	local = (local + delta_i + count) % count
	host.val_cat_i = start + local


static func nudge_col(host, delta_i: int) -> void:
	_ensure_cats(host)
	var n: int = host.val_cats.size()
	if n == 0:
		return
	var left_n: int = _left_n(n)
	var i: int = int(host.val_cat_i)
	if delta_i > 0:
		if i < left_n:
			var dest: int = left_n + i
			if dest >= n:
				dest = n - 1
			host.val_cat_i = dest
	elif delta_i < 0:
		if i >= left_n:
			host.val_cat_i = i - left_n
