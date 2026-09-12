extends Object

const ThemeS := preload("res://scripts/ui/theme.gd")
const Affix := preload("res://scripts/data/affixes.gd")
const ForgeP := preload("res://scripts/data/progress_forge.gd")
const StepRow := preload("res://scripts/ui/step_row.gd")
const QTY_MAX := 9
const Lock := preload("res://scripts/ui/gear_board_anvil_forge_edit_lock.gd")

static func _fill_edit(ui: CanvasLayer, box: Control, slot: String) -> Control:
	var _fac = load("res://scripts/ui/gear_board_anvil_forge_edit.gd")
	var types: PackedStringArray = ForgeP.types_for(App.prog, slot)
	if types.is_empty():
		box.add_child(ThemeS.lab("Analyze this slot before you can forge it.", 18, Color(0.78, 0.74, 0.66)))
		return null
	_fac._ensure(ui, slot, types)
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
			var b: Button = ThemeS.btn(Affix.type_label(slot, id), func(): _fac._set_type(ui, slot, bid, key))
			b.set_meta("forge_key", key)
			if id == str(ui.get("forge_type")):
				_fac._paint_on(b)
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
		var rb: Button = ThemeS.btn(rare.capitalize(), func(): _fac._set_rare(ui, slot, rr, key))
		rb.set_meta("forge_key", key)
		rb.disabled = not can
		rb.focus_mode = Control.FOCUS_NONE if not can else Control.FOCUS_ALL
		if rare == str(ui.get("forge_rarity")) and can:
			_fac._paint_on(rb)
			first = rb
		rarow.add_child(rb)
		if can and key == want:
			hit = rb
	box.add_child(rarow)
	var book: Dictionary = ForgeP.unlocks_for(App.prog, slot, str(ui.forge_type), str(ui.forge_rarity))
	var max_lv: int = maxi(1, int(book.get("ilvl", ForgeP.max_ilvl(App.prog, slot, str(ui.forge_type)))))
	ui.forge_ilvl = clampi(int(ui.get("forge_ilvl")), 1, max_lv)
	var lvrow: HBoxContainer = StepRow.make("Item Level:", func(): _fac._nudge_lv(ui, slot, -1, "lv-"), func(): _fac._nudge_lv(ui, slot, 1, "lv+"))
	StepRow.paint(lvrow, str(int(ui.forge_ilvl)), "(Max: %d)" % max_lv, int(ui.forge_ilvl) <= 1, int(ui.forge_ilvl) >= max_lv)
	_fac._tag(lvrow, "lv-", "lv+", want)
	if want == "lv-" or want == "lv+":
		hit = _fac._step_hit(lvrow, want)
	box.add_child(lvrow)
	ui.forge_qty = clampi(int(ui.get("forge_qty")), 1, QTY_MAX)
	var qrow: HBoxContainer = StepRow.make("Quantity:", func(): _fac._nudge_qty(ui, slot, -1, "qty-"), func(): _fac._nudge_qty(ui, slot, 1, "qty+"))
	StepRow.paint(qrow, str(int(ui.forge_qty)), "(Max: %d)" % QTY_MAX, int(ui.forge_qty) <= 1, int(ui.forge_qty) >= QTY_MAX)
	_fac._tag(qrow, "qty-", "qty+", want)
	if want == "qty-" or want == "qty+":
		hit = _fac._step_hit(qrow, want)
	box.add_child(qrow)
	Lock._lock_row(ui, box, slot, book)
	if hit == null and want.begins_with("lock:"):
		hit = _fac._find_key(box, want)
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
		"Cost %dg  %d ore  %d wood\tWait %.1fs each" % [int(bill.gold), int(bill.ore), int(bill.wood), wait],
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
