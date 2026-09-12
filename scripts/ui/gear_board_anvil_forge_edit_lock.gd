extends Object

const ThemeS := preload("res://scripts/ui/theme.gd")
const Affix := preload("res://scripts/data/affixes.gd")
const ForgeP := preload("res://scripts/data/progress_forge.gd")
const StepRow := preload("res://scripts/ui/step_row.gd")
const QTY_MAX := 9

static func _lock_row(ui: CanvasLayer, box: Control, slot: String, book: Dictionary) -> void:
	var _fac = load("res://scripts/ui/gear_board_anvil_forge_edit.gd")
	var cap: int = 2 if str(ui.forge_rarity) == "blue" else 1
	var known := PackedStringArray()
	var raw: Variant = book.get("traits", book.get("ids", []))
	if raw is PackedStringArray:
		known = raw
	elif raw is Array:
		for x: Variant in raw:
			known.append(str(x))
	if known.is_empty():
		return
	box.add_child(ThemeS.lab("Lock traits  (%d/%d)" % [ui.forge_locks.size(), cap], 16, Color(0.82, 0.76, 0.66)))
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 6)
	for id: String in known:
		var aid := id
		var key := "lock:" + aid
		var on := false
		for x: String in ui.forge_locks:
			if x == aid:
				on = true
				break
		var b: Button = ThemeS.btn(Affix.label_of(aid), func(): _fac._toggle_lock(ui, slot, aid, cap, key))
		b.set_meta("forge_key", key)
		if on:
			_fac._paint_on(b)
		row.add_child(b)
	box.add_child(row)
