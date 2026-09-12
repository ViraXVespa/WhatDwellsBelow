extends Object

const ThemeS := preload("res://scripts/ui/theme.gd")
const ForgeP := preload("res://scripts/data/progress_forge.gd")

const QTY_MAX := 9
const HOLD_CAP := 3

static func start(ui: CanvasLayer) -> void:
	ui.set_meta("forge_focus", "go")
	var slot := str(ui.gear_sub_slot)
	var rarity := str(ui.forge_rarity)
	var type_id := str(ui.forge_type)
	var ilvl: int = int(ui.forge_ilvl)
	var qty: int = clampi(int(ui.get("forge_qty")), 1, QTY_MAX)
	ui.forge_qty = qty
	var one: Dictionary = App.prog.forge_cost(slot, rarity, ilvl, ui.forge_locks.size())
	var cost: Dictionary = {
		"gold": int(one.get("gold", 0)) * qty,
		"ore": int(one.get("ore", 0)) * qty,
		"wood": int(one.get("wood", 0)) * qty,
	}
	var paid := false
	if App.prog.has_method("pay_forge"):
		paid = bool(App.prog.pay_forge(cost))
	else:
		paid = ForgeP.pay(App.prog, cost)
	if not paid:
		ui._st("Not enough banked materials.")
		return
	ui.forge_batch = []
	ui.forge_picks = []
	ui.forge_need = qty
	ui.forge_left = qty
	ui.forge_phase = "work"
	_spin_next(ui, slot, type_id, rarity, ilvl)
	ui._st("Forging 1 of %d…" % qty)
	load("res://scripts/ui/gear_board/gear_board_anvil_forge.gd")._reload(ui, slot)

static func finish(ui: CanvasLayer) -> void:
	if str(ui.get("forge_phase")) != "work":
		return
	var it: Dictionary = {}
	if ui.get("forge_it") is Dictionary:
		it = ui.forge_it
	ui.forge_it = {}
	ui.forge_t = 0.0
	if it.is_empty():
		if int(ui.forge_left) <= 0:
			_open_pick(ui)
		return
	ui.forge_batch.append(it)
	ui.forge_left = maxi(0, int(ui.forge_left) - 1)
	_grant_smith()
	if int(ui.forge_left) > 0:
		_spin_next(ui, str(it.get("slot", ui.gear_sub_slot)), str(ui.forge_type), str(ui.forge_rarity), int(ui.forge_ilvl))
		load("res://scripts/ui/gear_board/gear_board_anvil_forge.gd")._reload(ui, str(ui.gear_sub_slot))
		return
	_open_pick(ui)

static func cancel_job(ui: CanvasLayer) -> void:
	ui.forge_t = 0.0
	ui.forge_wait = 0.0
	ui.forge_it = {}
	ui.forge_left = 0
	var made: int = 0
	if ui.get("forge_batch") is Array:
		made = ui.forge_batch.size()
	if made > 0:
		ui._st("Stopped the queue. Pick from the %d finished piece%s." % [made, "" if made == 1 else "s"])
		_open_pick(ui)
		return
	ui.forge_phase = ""
	ui._st("Forge cancelled. Materials stay spent.")
	load("res://scripts/ui/gear_board/gear_board_anvil_forge.gd")._reload(ui, str(ui.gear_sub_slot))

static func refresh_bar(ui: CanvasLayer) -> void:
	var panel: Node = ui.get_node_or_null("gear_sub_panel")
	if panel == null:
		return
	var bar: Node = panel.find_child("forge_bar", true, false)
	if bar is ProgressBar:
		var wait: float = maxf(0.01, float(ui.get("forge_wait")))
		(bar as ProgressBar).value = 1.0 - clampf(float(ui.forge_t) / wait, 0.0, 1.0)
	var lab: Node = panel.find_child("forge_bar_lab", true, false)
	if lab is Label:
		var done: int = maxi(0, int(ui.forge_need) - int(ui.forge_left)) + 1
		(lab as Label).text = "Forging %d of %d" % [mini(done, maxi(1, int(ui.forge_need))), maxi(1, int(ui.forge_need))]

static func _fill_work(ui: CanvasLayer, box: Control) -> Control:
	var need: int = maxi(1, int(ui.get("forge_need")))
	var left: int = maxi(0, int(ui.get("forge_left")))
	var done: int = clampi(need - left + 1, 1, need)
	var lab := ThemeS.lab("Forging %d of %d" % [done, need], 20, Color(0.95, 0.82, 0.5))
	lab.name = "forge_bar_lab"
	box.add_child(lab)
	var wait: float = maxf(0.01, float(ui.get("forge_wait")))
	var bar := ProgressBar.new()
	bar.name = "forge_bar"
	bar.min_value = 0.0
	bar.max_value = 1.0
	bar.value = 1.0 - clampf(float(ui.forge_t) / wait, 0.0, 1.0)
	bar.custom_minimum_size = Vector2(520, 28)
	bar.show_percentage = false
	box.add_child(bar)
	box.add_child(ThemeS.lab("%.1fs left on this piece. Back stops the queue." % float(ui.forge_t), 16, Color(0.82, 0.76, 0.66)))
	return null

static func _spin_next(ui: CanvasLayer, slot: String, type_id: String, rarity: String, ilvl: int) -> void:
	ui.forge_it = ForgeP.make_forged(App.prog, slot, type_id, rarity, ilvl, ui.forge_locks)
	ui.forge_wait = App.prog.forge_duration(slot, rarity, ilvl)
	ui.forge_t = ui.forge_wait

static func _open_pick(ui: CanvasLayer) -> void:
	ui.forge_phase = "pick"
	ui.forge_t = 0.0
	ui.forge_it = {}
	ui.forge_picks = []
	var slot := str(ui.gear_sub_slot)
	var Pick = load("res://scripts/ui/gear_board/gear_board_anvil_forge_pick.gd")
	for row: Dictionary in Pick._pick_rows(ui, slot):
		if bool(row.get("pre", false)) and Pick._picked_n(ui) < HOLD_CAP:
			ui.forge_picks.append(str(row.key))
	load("res://scripts/ui/gear_board/gear_board_anvil_forge.gd")._reload(ui, slot)

static func _grant_smith() -> void:
	var amt := 12.0
	if App.bal != null and App.bal.get("xp_smith") != null:
		amt = float(App.bal.get("xp_smith"))
	App.prog.add_perm_xp("smith", amt)
	App.prog.forge_count += 1

