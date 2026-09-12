extends Object

const ThemeS := preload("res://scripts/ui/theme.gd")
const Icons := preload("res://scripts/ui/gear_icons.gd")
const Board := preload("res://scripts/ui/gear_board.gd")
const ForgeP := preload("res://scripts/data/progress_forge.gd")

const HOLD_CAP := 3

static func _fill_pick(ui: CanvasLayer, box: Control, slot: String) -> Control:
	box.add_child(ThemeS.lab("Keep three. Held pieces start selected. Highlight a piece for its stats.", 16, Color(0.82, 0.76, 0.66)))
	box.add_child(ThemeS.lab("Picked %d / %d" % [_picked_n(ui), HOLD_CAP], 18, Color(0.95, 0.8, 0.45)))
	var grid := HBoxContainer.new()
	grid.add_theme_constant_override("separation", 8)
	box.add_child(grid)
	var first: Control = null
	var want := str(ui.get_meta("forge_focus", ""))
	var hit: Control = null
	for row: Dictionary in _pick_rows(ui, slot):
		var key := str(row.key)
		var it: Dictionary = row.it if row.get("it") is Dictionary else {}
		var on := _picked(ui, key)
		var inv_key := "opt:forge:%s:%s" % [slot, key]
		var b := Button.new()
		b.text = ""
		b.custom_minimum_size = Vector2(72, 72)
		b.focus_mode = Control.FOCUS_ALL
		b.icon = Icons.tex_for_item(it)
		b.expand_icon = true
		b.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
		b.vertical_icon_alignment = VERTICAL_ALIGNMENT_CENTER
		b.set_meta("forge_key", key)
		b.set_meta("inv_key", inv_key)
		b.set_meta("inv_it", it.duplicate(true))
		_paint_opt(b, it, on)
		Board._watch_hover(ui, b, inv_key)
		b.pressed.connect(func(): _toggle_pick(ui, slot, key))
		b.focus_entered.connect(func():
			ui.inv_sel = inv_key
			ui.set_meta("forge_focus", key)
			Board._arm_tip(ui)
			Board.refresh(ui)
		)
		grid.add_child(b)
		if first == null:
			first = b
		if key == want:
			hit = b
	var tag := ThemeS.lab("Hold = already stored. New = this batch.", 14, Color(0.72, 0.68, 0.58))
	box.add_child(tag)
	var go: Button = ThemeS.btn("Keep selected", func(): _commit_picks(ui, slot))
	go.set_meta("forge_key", "keep")
	go.disabled = _picked_n(ui) == 0
	box.add_child(go)
	if want == "keep" and not go.disabled:
		hit = go
	var dump: Button = ThemeS.btn("Keep old holds", func(): load("res://scripts/ui/gear_board_anvil_forge.gd").keep_old(ui))
	dump.set_meta("forge_key", "dump")
	box.add_child(dump)
	if want == "dump":
		hit = dump
	var use: Control = hit if hit else first
	if use and str(use.get_meta("inv_key", "")) != "":
		ui.inv_sel = str(use.get_meta("inv_key"))
		Board._arm_tip(ui)
	return load("res://scripts/ui/gear_board_anvil_forge.gd")._keep(ui, use)

static func _paint_opt(b: Button, it: Dictionary, on: bool) -> void:
	var fill_c: Color = Icons.rarity_fill(it)
	var border: Color = Icons.rarity_border(it)
	if on:
		border = Color(0.95, 0.78, 0.35)
		fill_c = fill_c.lightened(0.08)
	b.add_theme_stylebox_override("normal", ThemeS.sb(fill_c, border))
	b.add_theme_stylebox_override("hover", ThemeS.sb(fill_c.lightened(0.12), border))
	b.add_theme_stylebox_override("pressed", ThemeS.sb(fill_c.darkened(0.1), border))
	b.add_theme_stylebox_override("focus", ThemeS.sb(fill_c.lightened(0.14), border))

static func _pick_rows(ui: CanvasLayer, slot: String) -> Array:
	var out: Array = []
	var type_id := str(ui.forge_type)
	var h: Array = App.prog.holds.get(slot, [])
	for raw: Variant in h:
		if not (raw is Dictionary):
			continue
		if ForgeP.type_of(raw) != type_id:
			continue
		var it: Dictionary = raw
		out.append({
			"key": "old:" + str(int(it.get("uid", 0))),
			"it": it,
			"pre": true,
			"label": "Hold  " + _cmp_line(it),
		})
	var i := 0
	for raw2: Variant in ui.forge_batch:
		if raw2 is Dictionary:
			out.append({
				"key": "new:" + str(i),
				"it": raw2,
				"pre": false,
				"label": "New  " + _cmp_line(raw2),
			})
		i += 1
	return out

static func _picked(ui: CanvasLayer, key: String) -> bool:
	for x: Variant in ui.forge_picks:
		if str(x) == key:
			return true
	return false

static func _picked_n(ui: CanvasLayer) -> int:
	return ui.forge_picks.size()

static func _toggle_pick(ui: CanvasLayer, slot: String, key: String) -> void:
	ui.set_meta("forge_focus", key)
	var next: Array = []
	var had := false
	for x: Variant in ui.forge_picks:
		if str(x) == key:
			had = true
		else:
			next.append(str(x))
	if not had and next.size() < HOLD_CAP:
		next.append(key)
	ui.forge_picks = next
	load("res://scripts/ui/gear_board_anvil_forge.gd")._reload(ui, slot)

static func _commit_picks(ui: CanvasLayer, slot: String) -> void:
	var type_id := str(ui.forge_type)
	var keep: Array = []
	for row: Dictionary in _pick_rows(ui, slot):
		if _picked(ui, str(row.key)) and row.get("it") is Dictionary:
			keep.append((row.it as Dictionary).duplicate(true))
	var msg := ForgeP.set_holds_for_type(App.prog, slot, type_id, keep)
	ui.forge_batch = []
	ui.forge_picks = []
	ui.forge_phase = ""
	ui.set_meta("forge_focus", "rare:" + str(ui.forge_rarity))
	ui._st(msg)
	load("res://scripts/ui/gear_board_anvil_forge.gd")._reload(ui, slot)

static func _cmp_line(it: Dictionary) -> String:
	return "%s  lv %d  finish %.2f  fortune %.2f" % [
		str(it.get("name", "piece")),
		maxi(1, int(it.get("ilvl", 1))),
		float(it.get("quality", 0.5)),
		float(it.get("luck", 0.75)),
	]

