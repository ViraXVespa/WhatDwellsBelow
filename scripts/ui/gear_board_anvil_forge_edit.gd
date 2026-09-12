extends Object

const ThemeS := preload("res://scripts/ui/theme.gd")
const Affix := preload("res://scripts/data/affixes.gd")
const ForgeP := preload("res://scripts/data/progress_forge.gd")
const StepRow := preload("res://scripts/ui/step_row.gd")

const QTY_MAX := 9

static func _fill_edit(ui: CanvasLayer, box: Control, slot: String) -> Control:
	var types: PackedStringArray = ForgeP.types_for(App.prog, slot)
	if types.is_empty():
		box.add_child(ThemeS.lab("Analyze this slot before you can forge it.", 18, Color(0.78, 0.74, 0.66)))
		return null
	_ensure(ui, slot, types)
	var want := str(ui.get_meta("forge_focus", ""))
	var hit: Control = null
	var first: Control = null
	if types.size() > 1:
		box.add_child(ThemeS.lab("Type", 16, Color(0.82, 0.76, 0.66)))
		var trow := HBoxContainer.new()
		trow.add_theme_constant_override("separation", 8)
		for id: String in types:
			var bid := id
			var key := "type:" + bid
			var b: Button = ThemeS.btn(Affix.type_label(slot, id), func(): _set_type(ui, slot, bid, key))
			b.set_meta("forge_key", key)
			if id == str(ui.get("forge_type")):
				_paint_on(b)
				first = b
			trow.add_child(b)
			if key == want:
				hit = b
		box.add_child(trow)
	box.add_child(ThemeS.lab("Rarity", 16, Color(0.82, 0.76, 0.66)))
	var rarow := HBoxContainer.new()
	rarow.add_theme_constant_override("separation", 8)
	for rare: String in ["green", "blue"]:
		var rr := rare
		var key := "rare:" + rr
		var can: bool = ForgeP.can_forge_rarity(App.prog, slot, str(ui.forge_type), rare)
		var rb: Button = ThemeS.btn(rare.capitalize(), func(): _set_rare(ui, slot, rr, key))
		rb.set_meta("forge_key", key)
		rb.disabled = not can
		rb.focus_mode = Control.FOCUS_NONE if not can else Control.FOCUS_ALL
		if rare == str(ui.get("forge_rarity")) and can:
			_paint_on(rb)
			first = rb
		rarow.add_child(rb)
		if can and key == want:
			hit = rb
	box.add_child(rarow)
	var book: Dictionary = ForgeP.unlocks_for(App.prog, slot, str(ui.forge_type), str(ui.forge_rarity))
	var max_lv: int = maxi(1, int(book.get("ilvl", ForgeP.max_ilvl(App.prog, slot, str(ui.forge_type)))))
	ui.forge_ilvl = clampi(int(ui.get("forge_ilvl")), 1, max_lv)
	var lvrow: HBoxContainer = StepRow.make("Item Level:", func(): _nudge_lv(ui, slot, -1, "lv-"), func(): _nudge_lv(ui, slot, 1, "lv+"))
	StepRow.paint(lvrow, str(int(ui.forge_ilvl)), "(Max: %d)" % max_lv, int(ui.forge_ilvl) <= 1, int(ui.forge_ilvl) >= max_lv)
	_tag(lvrow, "lv-", "lv+", want)
	if want == "lv-" or want == "lv+":
		hit = _step_hit(lvrow, want)
	box.add_child(lvrow)
	ui.forge_qty = clampi(int(ui.get("forge_qty")), 1, QTY_MAX)
	var qrow: HBoxContainer = StepRow.make("Quantity:", func(): _nudge_qty(ui, slot, -1, "qty-"), func(): _nudge_qty(ui, slot, 1, "qty+"))
	StepRow.paint(qrow, str(int(ui.forge_qty)), "(Max: %d)" % QTY_MAX, int(ui.forge_qty) <= 1, int(ui.forge_qty) >= QTY_MAX)
	_tag(qrow, "qty-", "qty+", want)
	if want == "qty-" or want == "qty+":
		hit = _step_hit(qrow, want)
	box.add_child(qrow)
	_lock_row(ui, box, slot, book)
	if hit == null and want.begins_with("lock:"):
		hit = _find_key(box, want)
	var qty: int = int(ui.forge_qty)
	var cost: Dictionary = App.prog.forge_cost(slot, str(ui.forge_rarity), int(ui.forge_ilvl), ui.forge_locks.size())
	var wait: float = App.prog.forge_duration(slot, str(ui.forge_rarity), int(ui.forge_ilvl))
	var pay_ok := false
	var bill: Dictionary = {
		"gold": int(cost.get("gold", 0)) * qty,
		"ore": int(cost.get("ore", 0)) * qty,
		"wood": int(cost.get("wood", 0)) * qty,
	}
	if App.prog.has_method("can_pay_forge"):
		pay_ok = App.prog.can_pay_forge(bill)
	else:
		pay_ok = App.prog.can_pay(bill)
	box.add_child(ThemeS.lab(
		"Cost %dg  %d ore  %d wood	Wait %.1fs each" % [int(bill.gold), int(bill.ore), int(bill.wood), wait],
		16,
		Color(0.8, 0.85, 0.7) if pay_ok else Color(0.95, 0.55, 0.4),
	))
	var go: Button = ThemeS.btn("Forge x%d" % qty, func(): load("res://scripts/ui/gear_board_anvil_forge.gd").start(ui))
	go.set_meta("forge_key", "go")
	go.disabled = not pay_ok
	go.focus_mode = Control.FOCUS_NONE if go.disabled else Control.FOCUS_ALL
	box.add_child(go)
	if not go.disabled and want == "go":
		hit = go
	if first == null and not go.disabled:
		first = go
	return load("res://scripts/ui/gear_board_anvil_forge.gd")._keep(ui, hit if hit else first)

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
		var b: Button = ThemeS.btn(Affix.label_of(aid), func(): _toggle_lock(ui, slot, aid, cap, key))
		b.set_meta("forge_key", key)
		if on:
			_paint_on(b)
		row.add_child(b)
	box.add_child(row)

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
