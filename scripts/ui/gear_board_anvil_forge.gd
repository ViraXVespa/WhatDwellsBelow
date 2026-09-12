extends Object

const ThemeS := preload("res://scripts/ui/theme.gd")
const Affix := preload("res://scripts/data/affixes.gd")
const ForgeP := preload("res://scripts/data/progress_forge.gd")
const StepRow := preload("res://scripts/ui/step_row.gd")
const Icons := preload("res://scripts/ui/gear_icons.gd")
const Board := preload("res://scripts/ui/gear_board.gd")

const QTY_MAX := 9
const HOLD_CAP := 3


static func reset(ui: CanvasLayer) -> void:
	ui.forge_type = ""
	ui.forge_rarity = "green"
	ui.forge_ilvl = 1
	ui.forge_qty = 1
	ui.forge_locks = PackedStringArray()
	reset_job(ui)
	ui.set_meta("forge_focus", "")


static func reset_job(ui: CanvasLayer) -> void:
	ui.forge_t = 0.0
	ui.forge_wait = 0.0
	ui.forge_it = {}
	ui.forge_new = {}
	ui.forge_batch = []
	ui.forge_picks = []
	ui.forge_left = 0
	ui.forge_need = 0
	ui.forge_phase = ""


static func fill(ui: CanvasLayer, box: Control, slot: String) -> Control:
	var phase := str(ui.get("forge_phase"))
	if phase == "work":
		return _fill_work(ui, box)
	if phase == "pick":
		return _fill_pick(ui, box, slot)
	return _fill_edit(ui, box, slot)


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
	_reload(ui, slot)


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
		_reload(ui, str(ui.gear_sub_slot))
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
	_reload(ui, str(ui.gear_sub_slot))


static func keep_old(ui: CanvasLayer) -> void:
	ui.forge_batch = []
	ui.forge_picks = []
	ui.forge_phase = ""
	ui._st("Kept the old holds. New rolls are gone.")
	_reload(ui, str(ui.gear_sub_slot))


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


static func hint_parts(ui: CanvasLayer) -> Array:
	var phase := str(ui.get("forge_phase"))
	if phase == "work":
		return [{"action": "ui_cancel", "verb": "stop queue", "gap": true}]
	if phase == "pick":
		return [
			{"action": "ui_accept", "verb": "toggle", "gap": true},
			{"action": "gear_tip", "verb": "stats", "gap": true},
			{"action": "ui_cancel", "verb": "keep old holds", "gap": true},
		]
	return [
		{"action": "ui_accept", "verb": "set / forge", "gap": true},
		{"action": "ui_cancel", "verb": "close", "gap": true},
	]


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
	var go: Button = ThemeS.btn("Forge x%d" % qty, func(): start(ui))
	go.set_meta("forge_key", "go")
	go.disabled = not pay_ok
	go.focus_mode = Control.FOCUS_NONE if go.disabled else Control.FOCUS_ALL
	box.add_child(go)
	if not go.disabled and want == "go":
		hit = go
	if first == null and not go.disabled:
		first = go
	return _keep(ui, hit if hit else first)


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
	var dump: Button = ThemeS.btn("Keep old holds", func(): keep_old(ui))
	dump.set_meta("forge_key", "dump")
	box.add_child(dump)
	if want == "dump":
		hit = dump
	var use: Control = hit if hit else first
	if use and str(use.get_meta("inv_key", "")) != "":
		ui.inv_sel = str(use.get_meta("inv_key"))
		Board._arm_tip(ui)
	return _keep(ui, use)


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
	for row: Dictionary in _pick_rows(ui, slot):
		if bool(row.get("pre", false)) and _picked_n(ui) < HOLD_CAP:
			ui.forge_picks.append(str(row.key))
	_reload(ui, slot)


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
	_reload(ui, slot)


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
	_reload(ui, slot)


static func _grant_smith() -> void:
	var amt := 12.0
	if App.bal != null and App.bal.get("xp_smith") != null:
		amt = float(App.bal.get("xp_smith"))
	App.prog.add_perm_xp("smith", amt)
	App.prog.forge_count += 1


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
	_reload(ui, slot)


static func _set_rare(ui: CanvasLayer, slot: String, rarity: String, key: String) -> void:
	ui.set_meta("forge_focus", key)
	ui.forge_rarity = rarity
	ui.forge_locks = PackedStringArray()
	_reload(ui, slot)


static func _nudge_lv(ui: CanvasLayer, slot: String, d: int, key: String) -> void:
	ui.set_meta("forge_focus", key)
	var max_lv: int = maxi(1, ForgeP.max_ilvl(App.prog, slot, str(ui.forge_type)))
	ui.forge_ilvl = clampi(int(ui.forge_ilvl) + d, 1, max_lv)
	_reload(ui, slot)


static func _nudge_qty(ui: CanvasLayer, slot: String, d: int, key: String) -> void:
	ui.set_meta("forge_focus", key)
	ui.forge_qty = clampi(int(ui.get("forge_qty")) + d, 1, QTY_MAX)
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
	_reload(ui, slot)


static func _cmp_line(it: Dictionary) -> String:
	return "%s  lv %d  finish %.2f  fortune %.2f" % [
		str(it.get("name", "piece")),
		maxi(1, int(it.get("ilvl", 1))),
		float(it.get("quality", 0.5)),
		float(it.get("luck", 0.75)),
	]


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


static func _keep(ui: CanvasLayer, ctl: Control) -> Control:
	if ctl == null or ctl.focus_mode == Control.FOCUS_NONE:
		return ctl
	var tree := ui.get_tree()
	if tree:
		var keep: Control = ctl
		tree.process_frame.connect(func():
			if is_instance_valid(keep) and keep.is_inside_tree() and keep.focus_mode != Control.FOCUS_NONE:
				keep.grab_focus()
		, CONNECT_ONE_SHOT)
	return ctl


static func _reload(ui: CanvasLayer, slot: String) -> void:
	ui.gear_sub = true
	ui.gear_sub_slot = slot
	var Sub = load("res://scripts/ui/gear_board_sub.gd")
	Sub.open_sub(ui, slot)


static func _paint_on(b: Button) -> void:
	var ink := Color(0.92, 0.84, 0.62)
	b.add_theme_color_override("font_color", ink)
	b.add_theme_stylebox_override("normal", ThemeS.sb(Color(0.3, 0.22, 0.14), Color(0.75, 0.58, 0.28)))
	b.add_theme_stylebox_override("focus", ThemeS.sb(Color(0.3, 0.22, 0.14), Color(0.75, 0.58, 0.28)))
	b.add_theme_stylebox_override("hover", ThemeS.sb(Color(0.38, 0.28, 0.16), Color(0.95, 0.78, 0.35)))
	b.add_theme_stylebox_override("pressed", ThemeS.sb(Color(0.38, 0.28, 0.16), Color(0.95, 0.78, 0.35)))
