extends Object

## Icon-grid item board: one cell per item = icon button + name/price caption, tip on focus or hover (TipHover),
## press -> the row's on_pick (the caller opens its own confirm). For the vendor consumable board, the ghost shop
## and pawn lists; not wired into a menu yet (the look comes from whichever task lands first).
## Row: {"id": String, "tex": Texture2D, "name": String, "price": String (optional), "on_pick": Callable}.
## A row without a texture is an error (no fallback icon).

const ThemeS := preload("res://scripts/ui/theme.gd")
const Icons := preload("res://scripts/ui/gear_icons.gd")
const TipHover := preload("res://scripts/ui/tip_hover.gd")

## paint: tip painter for TipHover (host needs the tip vars); empty Callable = no tips. Returns the grid.
static func build(parent: Control, host: Node, rows: Array, cols: int, cell: Vector2 = Vector2(72, 72),
		paint: Callable = Callable(), caption_px: int = 16) -> GridContainer:
	var err: String = check(rows)
	if err != "":
		push_error("item board: " + err)
		assert(false, "item board: " + err)
	var grid := GridContainer.new()
	grid.columns = maxi(1, cols)
	for row: Dictionary in rows:
		grid.add_child(_cell(host, row, cell, paint, caption_px))
	parent.add_child(grid)
	return grid

## "" when every row has an id and a texture, else what is wrong.
static func check(rows: Array) -> String:
	for i: int in rows.size():
		var r: Variant = rows[i]
		if not r is Dictionary or str((r as Dictionary).get("id", "")) == "":
			return "row %d has no id" % i
		if not (r as Dictionary).get("tex") is Texture2D:
			return "row %s has no icon texture" % str(r["id"])
	return ""

static func _cell(host: Node, row: Dictionary, cell: Vector2, paint: Callable, caption_px: int) -> VBoxContainer:
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 2)
	var b := Button.new()
	b.text = ""
	b.custom_minimum_size = cell
	b.focus_mode = Control.FOCUS_ALL
	b.set_meta("item_id", str(row["id"]))
	Icons.fit_btn(b, row.get("tex") as Texture2D)
	var pick: Variant = row.get("on_pick")
	if pick is Callable and (pick as Callable).is_valid():
		b.pressed.connect(pick.bind(row))
	if paint.is_valid():
		TipHover.attach(b, host, str(row["id"]), "item", paint)
	box.add_child(b)
	var cap: String = str(row.get("name", ""))
	if str(row.get("price", "")) != "":
		cap += "\n" + str(row["price"])
	if cap != "":
		box.add_child(ThemeS.lab(cap, caption_px, ThemeS.INK, HORIZONTAL_ALIGNMENT_CENTER, false, false))
	return box
