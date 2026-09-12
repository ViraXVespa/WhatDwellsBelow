extends Object

const ThemeS := preload("res://scripts/ui/theme.gd")
const Affix := preload("res://scripts/data/affixes.gd")
const ForgeP := preload("res://scripts/data/progress_forge.gd")
const StepRow := preload("res://scripts/ui/step_row.gd")

const QTY_MAX := 9
const Fill := preload("res://scripts/ui/gear_board_anvil_forge_edit_fill.gd")
const Lock := preload("res://scripts/ui/gear_board_anvil_forge_edit_lock.gd")

static func _fill_edit(ui: CanvasLayer, box: Control, slot: String) -> Control:
	return Fill._fill_edit(ui, box, slot)

static func _ensure(ui: CanvasLayer, slot: String, types: PackedStringArray) -> void:
	var have_type := false
	var cur := str(ui.get("forge_type"))
	for id: String in types:
		if id == cur:
			have_type = true
			break
	if cur == "" or not have_type:
		ui.forge_type = types[0]
	if not ForgeP.can_forge_rarity(App.prog, slot, str(ui.forge_type), str(ui.get("forge_rarity"))):
		if ForgeP.can_forge_rarity(App.prog, slot, str(ui.forge_type), "green"):
			ui.forge_rarity = "green"
		elif ForgeP.can_forge_rarity(App.prog, slot, str(ui.forge_type), "blue"):
			ui.forge_rarity = "blue"

static func _set_type(ui: CanvasLayer, slot: String, type_id: String, key: String) -> void:
	ui.set_meta("forge_focus", key)
	ui.forge_type = type_id
	ui.forge_locks = PackedStringArray()
	load("res://scripts/ui/gear_board_anvil_forge.gd")._reload(ui, slot)

static func _set_rare(ui: CanvasLayer, slot: String, rarity: String, key: String) -> void:
	ui.set_meta("forge_focus", key)
	ui.forge_rarity = rarity
	ui.forge_locks = PackedStringArray()
	load("res://scripts/ui/gear_board_anvil_forge.gd")._reload(ui, slot)

static func _nudge_lv(ui: CanvasLayer, slot: String, d: int, key: String) -> void:
	ui.set_meta("forge_focus", key)
	var max_lv: int = maxi(1, ForgeP.max_ilvl(App.prog, slot, str(ui.forge_type)))
	ui.forge_ilvl = clampi(int(ui.forge_ilvl) + d, 1, max_lv)
	load("res://scripts/ui/gear_board_anvil_forge.gd")._reload(ui, slot)

static func _nudge_qty(ui: CanvasLayer, slot: String, d: int, key: String) -> void:
	ui.set_meta("forge_focus", key)
	ui.forge_qty = clampi(int(ui.get("forge_qty")) + d, 1, QTY_MAX)
	load("res://scripts/ui/gear_board_anvil_forge.gd")._reload(ui, slot)

static func _lock_row(ui: CanvasLayer, box: Control, slot: String, book: Dictionary) -> void:
	Lock._lock_row(ui, box, slot, book)

static func _toggle_lock(ui: CanvasLayer, slot: String, id: String, cap: int, key: String) -> void:
	ui.set_meta("forge_focus", key)
	var next := PackedStringArray()
	var had := false
	for x: String in ui.forge_locks:
		if x == id:
			had = true
		else:
			next.append(x)
	if not had and next.size() < cap:
		next.append(id)
	ui.forge_locks = next
	load("res://scripts/ui/gear_board_anvil_forge.gd")._reload(ui, slot)

static func _tag(row: HBoxContainer, minus_key: String, plus_key: String, _want: String) -> void:
	var minus: Button = StepRow.minus_of(row)
	var plus: Button = StepRow.plus_of(row)
	if minus:
		minus.set_meta("forge_key", minus_key)
	if plus:
		plus.set_meta("forge_key", plus_key)

static func _step_hit(row: HBoxContainer, key: String) -> Control:
	if key.ends_with("-"):
		var minus: Button = StepRow.minus_of(row)
		if minus and minus.focus_mode != Control.FOCUS_NONE:
			return minus
	var plus: Button = StepRow.plus_of(row)
	if plus and plus.focus_mode != Control.FOCUS_NONE:
		return plus
	return null

static func _find_key(root: Node, key: String) -> Control:
	if key == "":
		return null
	for n: Node in root.find_children("*", "Control", true, false):
		if str(n.get_meta("forge_key", "")) == key:
			var c := n as Control
			if c and c.focus_mode != Control.FOCUS_NONE:
				return c
	return null

static func _paint_on(b: Button) -> void:
	var ink := Color(0.92, 0.84, 0.62)
	b.add_theme_color_override("font_color", ink)
	b.add_theme_stylebox_override("normal", ThemeS.sb(Color(0.3, 0.22, 0.14), Color(0.75, 0.58, 0.28)))
	b.add_theme_stylebox_override("focus", ThemeS.sb(Color(0.3, 0.22, 0.14), Color(0.75, 0.58, 0.28)))
	b.add_theme_stylebox_override("hover", ThemeS.sb(Color(0.38, 0.28, 0.16), Color(0.95, 0.78, 0.35)))
	b.add_theme_stylebox_override("pressed", ThemeS.sb(Color(0.38, 0.28, 0.16), Color(0.95, 0.78, 0.35)))
