extends Object

const ThemeS := preload("res://scripts/ui/theme.gd")
const Affix := preload("res://scripts/data/affixes.gd")
const ForgeP := preload("res://scripts/data/progress_forge.gd")


static func reset(ui: CanvasLayer) -> void:
	ui.forge_type = ""
	ui.forge_rarity = "green"
	ui.forge_ilvl = 1
	ui.forge_locks = PackedStringArray()
	ui.forge_new = {}
	ui.forge_it = {}


static func fill(ui: CanvasLayer, box: Control, slot: String) -> Control:
	var types: PackedStringArray = ForgeP.types_for(App.prog, slot)
	if types.is_empty():
		box.add_child(ThemeS.lab("Analyze this slot before you can forge it.", 18, Color(0.78, 0.74, 0.66)))
		return null
	_ensure(ui, slot, types)
	var first: Control = null
	if types.size() > 1:
		box.add_child(ThemeS.lab("Type", 16, Color(0.82, 0.76, 0.66)))
		var trow := HBoxContainer.new()
		trow.add_theme_constant_override("separation", 8)
		for id: String in types:
			var bid := id
			var b: Button = ThemeS.btn(Affix.type_label(slot, id), func(): _set_type(ui, slot, bid))
			if id == str(ui.get("forge_type")):
				_paint_on(b)
			trow.add_child(b)
			if first == null:
				first = b
		box.add_child(trow)
	var rarow := HBoxContainer.new()
	rarow.add_theme_constant_override("separation", 8)
	box.add_child(ThemeS.lab("Rarity", 16, Color(0.82, 0.76, 0.66)))
	for rare: String in ["green", "blue"]:
		var rr := rare
		var rb: Button = ThemeS.btn(rare.capitalize(), func(): _set_rare(ui, slot, rr))
		rb.disabled = not ForgeP.can_forge_rarity(App.prog, slot, str(ui.forge_type), rare)
		if rare == str(ui.get("forge_rarity")) and not rb.disabled:
			_paint_on(rb)
		rarow.add_child(rb)
		if first == null and not rb.disabled:
			first = rb
	box.add_child(rarow)
	var book: Dictionary = ForgeP.unlocks_for(App.prog, slot, str(ui.forge_type), str(ui.forge_rarity))
	var max_lv: int = maxi(1, int(book.get("ilvl", ForgeP.max_ilvl(App.prog, slot, str(ui.forge_type)))))
	ui.forge_ilvl = clampi(int(ui.get("forge_ilvl")), 1, max_lv)
	var lvrow := HBoxContainer.new()
	lvrow.add_theme_constant_override("separation", 8)
	var down: Button = ThemeS.btn("-", func(): _nudge_lv(ui, slot, -1))
	var up: Button = ThemeS.btn("+", func(): _nudge_lv(ui, slot, 1))
	lvrow.add_child(down)
	lvrow.add_child(ThemeS.lab("Item Level %d / %d" % [int(ui.forge_ilvl), max_lv], 18, Color(0.92, 0.86, 0.7)))
	lvrow.add_child(up)
	box.add_child(lvrow)
	if first == null:
		first = up
	_lock_row(ui, box, slot, book)
	if ui.get("forge_new") is Dictionary and not ui.forge_new.is_empty():
		_replace_row(ui, box, slot)
		return first
	var cost: Dictionary = App.prog.forge_cost(slot, str(ui.forge_rarity), int(ui.forge_ilvl), ui.forge_locks.size())
	var wait: float = App.prog.forge_duration(slot, str(ui.forge_rarity), int(ui.forge_ilvl))
	var pay_ok := false
	if App.prog.has_method("can_pay_forge"):
		pay_ok = App.prog.can_pay_forge(cost)
	else:
		pay_ok = App.prog.can_pay(cost)
	box.add_child(ThemeS.lab(
		"Cost %dg  %d ore  %d wood	Wait %.1fs" % [int(cost.gold), int(cost.ore), int(cost.wood), wait],
		16,
		Color(0.8, 0.85, 0.7) if pay_ok else Color(0.95, 0.55, 0.4),
	))
	var go: Button = ThemeS.btn("Forge", func(): ui._confirm(func(): start(ui), "forge"))
	go.disabled = not pay_ok or float(ui.get("forge_t")) > 0.0
	box.add_child(go)
	if first == null:
		first = go
	return first


static func start(ui: CanvasLayer) -> void:
	var slot := str(ui.gear_sub_slot)
	var rarity := str(ui.forge_rarity)
	var type_id := str(ui.forge_type)
	var ilvl: int = int(ui.forge_ilvl)
	var cost: Dictionary = App.prog.forge_cost(slot, rarity, ilvl, ui.forge_locks.size())
	var paid := false
	if App.prog.has_method("pay_forge"):
		paid = bool(App.prog.pay_forge(cost))
	else:
		paid = ForgeP.pay(App.prog, cost)
	if not paid:
		ui._st("Not enough banked materials.")
		return
	ui.forge_it = ForgeP.make_forged(App.prog, slot, type_id, rarity, ilvl, ui.forge_locks)
	ui.forge_t = App.prog.forge_duration(slot, rarity, ilvl)
	ui._st("Forging…")
	_reload(ui, slot)


static func finish(ui: CanvasLayer) -> void:
	var it: Dictionary = {}
	if ui.get("forge_it") is Dictionary:
		it = ui.forge_it
	ui.forge_it = {}
	ui.forge_t = 0.0
	if it.is_empty():
		return
	var slot := str(it.get("slot", ui.gear_sub_slot))
	var type_id := str(ui.forge_type)
	if ForgeP.hold_open(App.prog, slot, type_id) > 0:
		ForgeP.place_hold(App.prog, it)
		App.save_now()
		ui._st("Forged " + str(it.get("name", "hold")) + ".")
		reset(ui)
		_reload(ui, slot)
		return
	ui.forge_new = it
	ui._st("Holds full. Keep the new roll or replace one.")
	_reload(ui, slot)


static func discard_new(ui: CanvasLayer) -> void:
	ui.forge_new = {}
	ui._st("Discarded the new roll. Materials stay spent.")
	_reload(ui, str(ui.gear_sub_slot))


static func replace_at(ui: CanvasLayer, idx: int) -> void:
	var it: Dictionary = ui.forge_new
	if it.is_empty():
		return
	ForgeP.replace_hold(App.prog, it, idx)
	ui.forge_new = {}
	App.save_now()
	ui._st("Replaced hold.")
	reset(ui)
	_reload(ui, str(it.get("slot", ui.gear_sub_slot)))


static func hint_parts(_ui: CanvasLayer) -> Array:
	return [
		{"action": "ui_accept", "verb": "set / forge", "gap": true},
		{"action": "ui_cancel", "verb": "close", "gap": true},
	]


static func _ensure(ui: CanvasLayer, slot: String, types: PackedStringArray) -> void:
	if str(ui.get("forge_type")) == "" or not str(ui.forge_type) in types:
		ui.forge_type = types[0]
	if not ForgeP.can_forge_rarity(App.prog, slot, str(ui.forge_type), str(ui.get("forge_rarity"))):
		if ForgeP.can_forge_rarity(App.prog, slot, str(ui.forge_type), "green"):
			ui.forge_rarity = "green"
		elif ForgeP.can_forge_rarity(App.prog, slot, str(ui.forge_type), "blue"):
			ui.forge_rarity = "blue"


static func _set_type(ui: CanvasLayer, slot: String, type_id: String) -> void:
	ui.forge_type = type_id
	ui.forge_locks = PackedStringArray()
	_reload(ui, slot)


static func _set_rare(ui: CanvasLayer, slot: String, rarity: String) -> void:
	ui.forge_rarity = rarity
	ui.forge_locks = PackedStringArray()
	_reload(ui, slot)


static func _nudge_lv(ui: CanvasLayer, slot: String, d: int) -> void:
	var max_lv: int = maxi(1, ForgeP.max_ilvl(App.prog, slot, str(ui.forge_type)))
	ui.forge_ilvl = clampi(int(ui.forge_ilvl) + d, 1, max_lv)
	_reload(ui, slot)


static func _lock_row(ui: CanvasLayer, box: Control, slot: String, book: Dictionary) -> void:
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
		var on: bool = false
		for x: String in ui.forge_locks:
			if x == aid:
				on = true
				break
		var b: Button = ThemeS.btn(Affix.label_of(aid), func(): _toggle_lock(ui, slot, aid, cap))
		if on:
			_paint_on(b)
		row.add_child(b)
	box.add_child(row)


static func _toggle_lock(ui: CanvasLayer, slot: String, id: String, cap: int) -> void:
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
	_reload(ui, slot)


static func _replace_row(ui: CanvasLayer, box: Control, slot: String) -> void:
	box.add_child(ThemeS.lab("New roll ready. Pick a hold to replace, or discard.", 16, Color(0.95, 0.8, 0.45)))
	var h: Array = App.prog.holds.get(slot, [])
	var i := 0
	for raw: Variant in h:
		if not (raw is Dictionary):
			continue
		if ForgeP.type_of(raw) != str(ui.forge_type):
			i += 1
			continue
		var idx := i
		box.add_child(ThemeS.btn("Replace  " + str(raw.get("name", "hold")), func(): replace_at(ui, idx)))
		i += 1
	box.add_child(ThemeS.btn("Discard new roll", func(): discard_new(ui)))


static func _reload(ui: CanvasLayer, slot: String) -> void:
	var Sub = load("res://scripts/ui/gear_board_sub.gd")
	Sub.open_sub(ui, slot)


static func _paint_on(b: Button) -> void:
	var ink := Color(0.92, 0.84, 0.62)
	b.add_theme_color_override("font_color", ink)
	b.add_theme_stylebox_override("normal", ThemeS.sb(Color(0.3, 0.22, 0.14), Color(0.75, 0.58, 0.28)))
	b.add_theme_stylebox_override("focus", ThemeS.sb(Color(0.3, 0.22, 0.14), Color(0.75, 0.58, 0.28)))
	b.add_theme_stylebox_override("hover", ThemeS.sb(Color(0.38, 0.28, 0.16), Color(0.95, 0.78, 0.35)))
	b.add_theme_stylebox_override("pressed", ThemeS.sb(Color(0.38, 0.28, 0.16), Color(0.95, 0.78, 0.35)))
