extends CanvasLayer

const ThemeS := preload("res://scripts/ui/theme.gd")
const CatalogS := preload("res://scripts/data/catalog.gd")

var open := false
var mode := ""
var shop_spot: Node = null
var extract_role := "gather"
var pending := false
var pending_id := ""
var pending_fn: Callable
var box: VBoxContainer
var status: Label
var focus_btn: Button
var loadout_floor := 1
var loadout_tool := "pickaxe"
var loadout_wpn := "great_axe"
var anvil_item: Dictionary = {}
var forge_t := 0.0
var forge_it: Dictionary = {}


func _ready() -> void:
	layer = 45
	visible = false
	process_mode = Node.PROCESS_MODE_ALWAYS
	var dim := ColorRect.new()
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.color = Color(0.04, 0.03, 0.02, 0.74)
	add_child(dim)
	var panel := ColorRect.new()
	panel.color = Color(0.14, 0.11, 0.09, 0.96)
	panel.position = Vector2(360, 80)
	panel.size = Vector2(1200, 920)
	add_child(panel)
	var edge := ColorRect.new()
	edge.color = Color(0.55, 0.42, 0.22, 1)
	edge.position = Vector2(360, 80)
	edge.size = Vector2(1200, 8)
	add_child(edge)
	var scroll := ScrollContainer.new()
	scroll.position = Vector2(384, 104)
	scroll.size = Vector2(1152, 872)
	add_child(scroll)
	box = VBoxContainer.new()
	box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	box.add_theme_constant_override("separation", 8)
	scroll.add_child(box)


func close_ui() -> void:
	open = false
	visible = false
	pending = false
	pending_id = ""
	forge_t = 0.0
	forge_it = {}
	App.ui_open = false
	get_tree().paused = false


func _show() -> void:
	open = true
	visible = true
	App.ui_open = true
	if App.in_dungeon:
		get_tree().paused = true
	call_deferred("_focus")


func _focus() -> void:
	if focus_btn:
		focus_btn.grab_focus()


func _clear() -> void:
	for c in box.get_children():
		c.queue_free()
	focus_btn = null
	status = null


func _st(msg: String) -> void:
	if status:
		status.text = msg
	App.sfx("ui")


func open_inventory() -> void:
	mode = "inv"
	_rebuild_inv()
	_show()


func open_extract(role: String) -> void:
	mode = "extract"
	extract_role = role
	pending = false
	_rebuild_extract()
	_show()


func open_shop(spot: Node) -> void:
	mode = "shop"
	shop_spot = spot
	_rebuild_shop()
	_show()


func open_anvil() -> void:
	mode = "anvil"
	pending = false
	anvil_item = {}
	_rebuild_anvil()
	_show()


func open_loadout() -> void:
	mode = "loadout"
	pending = false
	loadout_floor = App.prog.start_floor
	loadout_tool = App.prog.tool_type
	loadout_wpn = str(App.prog.slots.weapon.get("weapon", "great_axe")) if not App.prog.slots.weapon.is_empty() else "great_axe"
	_rebuild_loadout()
	_show()


func open_vendor() -> void:
	mode = "vendor"
	_rebuild_vendor()
	_show()


func open_controls() -> void:
	mode = "controls"
	_rebuild_controls()
	_show()


func open_flavor(title: String, body: String) -> void:
	mode = "flavor"
	_clear()
	box.add_child(ThemeS.lab(title, 28, Color(0.95, 0.82, 0.5)))
	box.add_child(ThemeS.lab(body, 22, Color(0.88, 0.82, 0.7)))
	focus_btn = ThemeS.btn("Leave  (B)", func(): close_ui())
	box.add_child(focus_btn)
	_show()


func open_quest() -> void:
	mode = "quest"
	if App.prog.quests_offered.is_empty():
		App.prog.roll_quests(true)
	_rebuild_quest()
	_show()


func _rebuild_inv() -> void:
	_clear()
	box.add_child(ThemeS.lab("Inventory", 32, Color(0.95, 0.82, 0.5)))
	box.add_child(ThemeS.lab("Bag %d/%d   Gold %d   Ore %d   Wood %d   Root %d" % [App.prog.bag_count(), int(App.bal.bag_cap), App.gold, App.ore, App.wood, App.prog.root], 20, Color(0.88, 0.82, 0.7)))
	box.add_child(ThemeS.lab(_sets_blurb(), 18, Color(0.85, 0.72, 0.45)))
	status = ThemeS.lab("", 20, Color(0.95, 0.8, 0.45))
	box.add_child(status)
	for s in App.prog.SLOTS:
		var eq_it: Dictionary = App.prog.slots.get(s, {})
		var slot := str(s)
		var nm := str(eq_it.get("name", "—"))
		var eq_row := HBoxContainer.new()
		eq_row.add_theme_constant_override("separation", 8)
		var eq_lab := ThemeS.btn("%s: %s" % [slot, nm], func(): _st(nm))
		eq_lab.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		eq_row.add_child(eq_lab)
		if not eq_it.is_empty():
			eq_row.add_child(ThemeS.btn("Unequip", func(): _st(App.prog.unequip_slot(slot)); _rebuild_inv(); _show()))
			eq_row.add_child(ThemeS.btn("Drop", func(): _confirm(func(): _st(App.prog.drop_slot(slot)); _rebuild_inv(); _show(), "drop_slot_" + slot)))
		box.add_child(eq_row)
		if focus_btn == null:
			focus_btn = eq_lab
	if focus_btn == null:
		focus_btn = ThemeS.btn("Use potion  (D-pad Up)", func(): _st(App.prog.use_potion()))
		box.add_child(focus_btn)
	else:
		box.add_child(ThemeS.btn("Use potion  (D-pad Up)", func(): _st(App.prog.use_potion())))
	box.add_child(ThemeS.btn("Use food  (D-pad Left)", func(): _st(App.prog.use_food())))
	for bag_it in App.prog.bag:
		var uid := int(bag_it.uid)
		var line := "%s  ·  %s" % [bag_it.name, bag_it.desc]
		if str(bag_it.kind) == "artifact":
			line += "\n" + App.prog.set_bonus_text(str(bag_it.set))
		var bag_row := HBoxContainer.new()
		bag_row.add_theme_constant_override("separation", 8)
		var use_b := ThemeS.btn(line, func(): _inv_act(uid))
		use_b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		bag_row.add_child(use_b)
		bag_row.add_child(ThemeS.btn("Drop", func(): _confirm(func(): _st(App.prog.drop_uid(uid)); _rebuild_inv(); _show(), "drop_bag_%d" % uid)))
		box.add_child(bag_row)
	if not App.in_dungeon and App.prog.bank_items.size() > 0:
		box.add_child(ThemeS.lab("Mailed stash — safe in Placeholdia. Forge at the anvil.", 18, Color(0.75, 0.85, 0.7)))
		for stash_it in App.prog.bank_items:
			var stash_uid := int(stash_it.uid)
			var stash_row := HBoxContainer.new()
			stash_row.add_theme_constant_override("separation", 8)
			var stash_lab := ThemeS.btn("%s  ·  mailed" % str(stash_it.name), func(): _st("Forge this at the anvil."))
			stash_lab.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			stash_row.add_child(stash_lab)
			stash_row.add_child(ThemeS.btn("Discard", func(): _confirm(func(): _st(App.prog.drop_stash(stash_uid)); _rebuild_inv(); _show(), "stash_%d" % stash_uid)))
			box.add_child(stash_row)
	box.add_child(ThemeS.btn("Close  (B)", func(): close_ui()))


func _inv_act(uid: int) -> void:
	var it := {}
	for b in App.prog.bag:
		if int(b.uid) == uid:
			it = b
			break
	if it.is_empty():
		_st("Gone.")
		return
	if str(it.kind) == "potion" or str(it.kind) == "food":
		_st(App.prog.use_from_bag(uid))
	else:
		_st(App.prog.equip_uid(uid))
	_rebuild_inv()
	_show()


func _sets_blurb() -> String:
	var bits: PackedStringArray = PackedStringArray()
	var c: Dictionary = App.prog.set_counts()
	for s in CatalogS.SETS:
		var n: int = int(c.get(s, 0))
		if n > 0:
			bits.append("%s %d/%d%s" % [s, n, CatalogS.set_size(s), " *" if n >= 2 else ""])
	return "Sets: " + (", ".join(bits) if bits.size() > 0 else "none")


func _rebuild_extract() -> void:
	_clear()
	var title := "Gather Clerk"
	if extract_role == "misc":
		title = "Misc Clerk"
	elif extract_role == "patty":
		title = "Packmule Patty"
	box.add_child(ThemeS.lab(title, 32, Color(0.95, 0.82, 0.5)))
	box.add_child(ThemeS.lab("Mail goods to the surface. Artifacts stay with you (run-only).", 18, Color(0.82, 0.76, 0.66)))
	status = ThemeS.lab("A to select. Confirm with A again. B leaves.", 20, Color(0.95, 0.8, 0.45))
	box.add_child(status)
	focus_btn = ThemeS.btn("Send All  (confirm)", func(): _confirm(func(): _do_send_all(), "send_all"))
	box.add_child(focus_btn)
	for it in App.prog.extractable(extract_role):
		var cap := str(it.get("name", "?"))
		if it.has("n"):
			cap += "  x%d" % int(it.n)
		var copy: Dictionary = it.duplicate(true)
		box.add_child(ThemeS.btn("Send  " + cap, func(): _confirm(func(): _do_send_one(copy), "send_" + cap)))
	box.add_child(ThemeS.btn("Leave  (B)", func(): close_ui()))


func _do_send_all() -> void:
	_st(App.prog.extract_all(extract_role))
	_rebuild_extract()
	_show()


func _do_send_one(it: Dictionary) -> void:
	_st(App.prog.extract_one(it, extract_role))
	_rebuild_extract()
	_show()


func _rebuild_shop() -> void:
	_clear()
	box.add_child(ThemeS.lab("Ghost Shop", 32, Color(0.75, 0.9, 1.0)))
	box.add_child(ThemeS.lab("Two artifacts a visit. Snacks %dg. Artifacts are run-only." % int(App.bal.snack_cost), 18, Color(0.82, 0.76, 0.66)))
	box.add_child(ThemeS.lab("Gold %d   Bought %d/%d" % [App.gold, int(shop_spot.get("bought") if shop_spot else 0), int(App.bal.shop_buy_max)], 20, Color(0.9, 0.88, 0.78)))
	box.add_child(ThemeS.lab(_sets_blurb(), 18, Color(0.85, 0.72, 0.45)))
	status = ThemeS.lab("", 20, Color(0.95, 0.8, 0.45))
	box.add_child(status)
	focus_btn = ThemeS.btn("Snack  (%dg, +HP)" % int(App.bal.snack_cost), func(): _confirm(func(): _buy_snack(), "snack"))
	box.add_child(focus_btn)
	if shop_spot:
		for a in shop_spot.stock:
			var id := str(a.id)
			var nm := str(a.name)
			var desc := str(a.get("desc", ""))
			var set_id := str(a.get("set", ""))
			var extra := ""
			if set_id != "":
				extra = "\n" + App.prog.set_bonus_text(set_id)
			box.add_child(ThemeS.btn("Buy %s  (%dg)\n%s%s" % [nm, int(App.bal.art_cost), desc, extra], func(): _confirm(func(): _buy_art(id, nm), "buy_" + id)))
		for it in App.prog.bag:
			if str(it.kind) == "artifact" or str(it.kind) == "weapon" or str(it.kind) == "head" or str(it.kind) == "body" or str(it.kind) == "legs":
				var uid := int(it.uid)
				box.add_child(ThemeS.btn("Pawn %s  (%dg)" % [it.name, int(App.bal.pawn_gold)], func(): _confirm(func(): _pawn(uid), "pawn_%d" % uid)))
		for s in ["weapon", "tool", "head", "body", "legs"]:
			var eq: Dictionary = App.prog.slots.get(s, {})
			if eq.is_empty():
				continue
			var slot := str(s)
			box.add_child(ThemeS.btn("Pawn equipped %s  (%dg)" % [eq.name, int(App.bal.pawn_gold)], func(): _confirm(func(): _pawn_slot(slot), "pawn_slot_" + slot)))
	box.add_child(ThemeS.btn("Leave  (B)", func(): close_ui()))


func _buy_snack() -> void:
	if App.gold < int(App.bal.snack_cost):
		_st("Not enough gold.")
		return
	App.gold -= int(App.bal.snack_cost)
	_shop_spend(int(App.bal.snack_cost))
	var p := get_tree().get_first_node_in_group("player")
	if p and p.has_method("heal"):
		p.heal(App.bal.snack_heal)
	_st("The snack is strangely warm.")
	App.toast("Snack.")


func _buy_art(id: String, nm: String) -> void:
	if shop_spot == null:
		return
	if int(shop_spot.bought) >= int(App.bal.shop_buy_max):
		_st("Two artifacts a visit.")
		return
	if App.gold < int(App.bal.art_cost):
		_st("Not enough gold.")
		return
	if App.prog.bag_full():
		_st("Bag full.")
		return
	App.gold -= int(App.bal.art_cost)
	shop_spot.bought = int(shop_spot.bought) + 1
	App.prog.add_item(App.prog.make_artifact(id))
	_shop_spend(int(App.bal.art_cost))
	var keep: Array = []
	var stripped := false
	for a in shop_spot.stock:
		if not stripped and str(a.get("id", "")) == id:
			stripped = true
			continue
		keep.append(a)
	shop_spot.stock = keep
	_st("Purchased " + nm)
	App.toast("Artifact: " + nm)
	_rebuild_shop()
	_show()


func _shop_spend(n: int) -> void:
	App.shop_buys += 1
	App.shop_spent += n
	if App.tel:
		App.tel.shop_buys += 1
		App.tel.shop_spent += n


func _pawn(uid: int) -> void:
	var it := App.prog.remove_uid(uid)
	if it.is_empty():
		_st("Gone.")
		return
	App.gain_gold(int(App.bal.pawn_gold))
	_st("The ghost takes it for a pittance.")
	_rebuild_shop()
	_show()


func _pawn_slot(slot: String) -> void:
	var it := App.prog.take_slot(slot)
	if it.is_empty():
		_st("Gone.")
		return
	App.gain_gold(int(App.bal.pawn_gold))
	_st("The ghost takes it for a pittance.")
	_rebuild_shop()
	_show()


func _rebuild_anvil() -> void:
	_clear()
	box.add_child(ThemeS.lab("Anvil", 32, Color(0.95, 0.82, 0.5)))
	var smith := App.prog.skill_lv("smith")
	box.add_child(ThemeS.lab("Analyze → first forge (gold + ore + root) → cheaper re-forges. Smithing %d shortens the wait." % smith, 18, Color(0.82, 0.76, 0.66)))
	box.add_child(ThemeS.lab("Bank %dg  %d ore  %d root   Carried %dg %d ore %d root" % [App.bank_gold, App.bank_ore, App.bank_root, App.gold, App.ore, App.prog.root], 18, Color(0.8, 0.85, 0.7)))
	status = ThemeS.lab("", 20, Color(0.95, 0.8, 0.45))
	box.add_child(status)
	if anvil_item.is_empty():
		_anvil_pick()
	else:
		_anvil_analyze()
	for s in App.prog.SLOTS:
		var h: Array = App.prog.holds[s]
		if h.size() > 0:
			var names := []
			for x in h:
				names.append(str(x.name))
			box.add_child(ThemeS.lab("Holds %s: %s" % [s, ", ".join(names)], 18, Color(0.75, 0.85, 0.7)))
	box.add_child(ThemeS.btn("Close  (B)", func(): close_ui()))


func _anvil_pick() -> void:
	status.text = "Analyze a piece first."
	var sources: Array = App.prog.bag.duplicate()
	for it in App.prog.bank_items:
		sources.append(it)
	for s in App.prog.SLOTS:
		var it: Dictionary = App.prog.slots.get(s, {})
		if not it.is_empty():
			sources.append(it)
		for hold_it in App.prog.holds[s]:
			sources.append(hold_it)
	var any := false
	for it in sources:
		if str(it.get("slot", "")) in ["weapon", "tool", "head", "body", "legs"]:
			any = true
			var copy: Dictionary = it.duplicate(true)
			var h: Array = App.prog.holds[str(copy.slot)]
			var b := ThemeS.btn("Analyze %s  (%s, holds %d/3)" % [copy.name, copy.rarity, h.size()], func(): anvil_item = copy; pending = false; _rebuild_anvil(); _show())
			if focus_btn == null:
				focus_btn = b
			box.add_child(b)
	if not any:
		box.add_child(ThemeS.lab("Bring a weapon, tool, or armor.", 20, Color(0.8, 0.7, 0.6)))


func _anvil_analyze() -> void:
	var it: Dictionary = anvil_item
	var slot := str(it.get("slot", ""))
	var h: Array = App.prog.holds[slot] if App.prog.holds.has(slot) else []
	var first := h.size() < 3 and not bool(it.get("hold", false))
	var cost: Dictionary = App.prog.forge_cost(first)
	var smith := App.prog.skill_lv("smith")
	box.add_child(ThemeS.lab("Analysis — %s" % str(it.name), 26, Color(0.95, 0.86, 0.55)))
	box.add_child(ThemeS.lab("Slot %s   Rarity %s   +%d dmg   +%d def   +%d HP" % [slot, str(it.get("rarity", "white")), int(it.get("dmg", 0)), int(it.get("def", 0)), int(it.get("hp", 0))], 18, Color(0.88, 0.82, 0.7)))
	var wait := App.prog.forge_duration()
	box.add_child(ThemeS.lab("Smithing %d: cheaper, faster, better. Holds %d/3. Forge time %.1fs." % [smith, h.size(), wait], 18, Color(0.8, 0.85, 0.7)))
	if first:
		status.text = "First forge: %dg  %d ore  %d root. A again to confirm." % [cost.gold, cost.ore, cost.root]
		focus_btn = ThemeS.btn("First Forge  (confirm)", func(): _confirm(func(): _do_forge(it), "forge"))
	else:
		status.text = "Re-forge: %dg  %d ore  %d root. A again to confirm." % [cost.gold, cost.ore, cost.root]
		focus_btn = ThemeS.btn("Re-forge  (confirm)", func(): _confirm(func(): _do_forge(it), "forge"))
	box.add_child(focus_btn)
	box.add_child(ThemeS.btn("Analyze another", func(): anvil_item = {}; pending = false; _rebuild_anvil(); _show()))


func _do_forge(it: Dictionary) -> void:
	if forge_t > 0.0:
		return
	var slot := str(it.get("slot", ""))
	var h: Array = App.prog.holds[slot] if App.prog.holds.has(slot) else []
	var first := h.size() < 3 and not bool(it.get("hold", false))
	var cost: Dictionary = App.prog.forge_cost(first)
	if not App.prog.can_pay(cost):
		_st("Need %dg, %d ore, %d root." % [cost.gold, cost.ore, cost.root])
		App.toast("Not enough gold / ore / root.")
		return
	forge_it = it.duplicate(true)
	forge_t = App.prog.forge_duration()
	_st("Forging… %.1fs. Smithing shortens this. B cancels." % forge_t)


func _rebuild_loadout() -> void:
	_clear()
	box.add_child(ThemeS.lab("Floor Crystal — Loadout", 32, Color(0.6, 0.9, 1.0)))
	box.add_child(ThemeS.lab("Holds, weapon, tool lock, starting floor. Confirm enter twice. Only floors you have reached. Stairs never go back.", 18, Color(0.82, 0.76, 0.66)))
	status = ThemeS.lab("Weapon %s   Tool %s   Floor %d / deepest %d" % [loadout_wpn, loadout_tool, loadout_floor, App.prog.deepest], 22, Color(0.95, 0.8, 0.45))
	box.add_child(status)
	focus_btn = ThemeS.btn("Character: %s  (switch, confirm)" % App.character_type, func(): _confirm(func(): _toggle_char(), "char"))
	box.add_child(focus_btn)
	box.add_child(ThemeS.btn("Weapon: Great Axe", func(): _set_wpn("great_axe")))
	box.add_child(ThemeS.btn("Weapon: Lightning Staff", func(): _set_wpn("staff")))
	box.add_child(ThemeS.btn("Weapon: Longbow", func(): _set_wpn("longbow")))
	box.add_child(ThemeS.btn("Tool: Pickaxe  (mining)", func(): _set_tool("pickaxe")))
	box.add_child(ThemeS.btn("Tool: Hatchet  (woodcutting)", func(): _set_tool("hatchet")))
	box.add_child(ThemeS.btn("Floor +", func(): _floor(1)))
	box.add_child(ThemeS.btn("Floor −", func(): _floor(-1)))
	for s in App.prog.SLOTS:
		var h: Array = App.prog.holds[s]
		if h.size() > 0:
			for i in h.size():
				var nm := str(h[i].name)
				box.add_child(ThemeS.btn("Use hold %s: %s" % [s, nm], func(): _use_hold(s, i)))
	box.add_child(ThemeS.btn("Enter dungeon  (confirm)", func(): _confirm(func(): _enter(), "enter")))
	box.add_child(ThemeS.btn("Back  (B)", func(): close_ui()))


func _toggle_char() -> void:
	App.set_character("female" if App.character_type == "male" else "male")
	App.save_now()
	_rebuild_loadout()
	_show()


func _set_wpn(w: String) -> void:
	loadout_wpn = w
	App.weapon = w
	App.prog.pick_weapon = w
	App.prog.hold_pick["weapon"] = _matching_hold("weapon", "weapon", w)
	status.text = "Weapon %s   Tool %s   Floor %d" % [loadout_wpn, loadout_tool, loadout_floor]


func _set_tool(t: String) -> void:
	loadout_tool = t
	App.prog.tool_type = t
	App.prog.hold_pick["tool"] = _matching_hold("tool", "tool", t)
	status.text = "Weapon %s   Tool %s   Floor %d" % [loadout_wpn, loadout_tool, loadout_floor]


func _matching_hold(slot: String, key: String, want: String) -> int:
	var h: Array = App.prog.holds[slot]
	for i in h.size():
		if str(h[i].get(key, "")) == want:
			return i
	return -1


func _floor(d: int) -> void:
	loadout_floor = clampi(loadout_floor + d, 1, App.prog.deepest)
	status.text = "Weapon %s   Tool %s   Floor %d" % [loadout_wpn, loadout_tool, loadout_floor]


func _use_hold(slot: String, i: int) -> void:
	var h: Array = App.prog.holds[slot]
	if i < 0 or i >= h.size():
		return
	App.prog.hold_pick[slot] = i
	App.prog.slots[slot] = h[i].duplicate(true)
	if slot == "weapon":
		loadout_wpn = str(h[i].get("weapon", loadout_wpn))
		App.prog.pick_weapon = loadout_wpn
	if slot == "tool":
		loadout_tool = str(h[i].get("tool", loadout_tool))
		App.prog.tool_type = loadout_tool
	_st("Hold ready: " + str(h[i].name))


func _enter() -> void:
	App.prog.tool_type = loadout_tool
	App.prog.pick_weapon = loadout_wpn
	App.prog.start_floor = loadout_floor
	App.weapon = loadout_wpn
	close_ui()
	App.enter_dungeon()


func _rebuild_quest() -> void:
	_clear()
	box.add_child(ThemeS.lab("Guild Tasks", 32, Color(0.95, 0.82, 0.5)))
	box.add_child(ThemeS.lab("Three choices. One active. Named vanquish locks that named foe.", 18, Color(0.82, 0.76, 0.66)))
	status = ThemeS.lab("", 20, Color(0.95, 0.8, 0.45))
	box.add_child(status)
	if not App.prog.quest_active.is_empty():
		var q: Dictionary = App.prog.quest_active
		box.add_child(ThemeS.lab("Active: %s  (%d/%d)" % [q.title, int(q.get("have", 0)), int(q.get("need", 1))], 22, Color(0.75, 0.95, 0.7)))
		box.add_child(ThemeS.btn("Abandon active task  (confirm)", func(): _confirm(func(): _st(App.prog.abandon_quest()); _rebuild_quest(); _show(), "abandon")))
	var i := 0
	for q in App.prog.quests_offered:
		var idx := i
		if focus_btn == null:
			focus_btn = ThemeS.btn("%s\nReward: %s" % [q.title, q.reward], func(): _st(App.prog.accept_quest(idx)); _rebuild_quest(); _show())
			box.add_child(focus_btn)
		else:
			box.add_child(ThemeS.btn("%s\nReward: %s" % [q.title, q.reward], func(): _st(App.prog.accept_quest(idx)); _rebuild_quest(); _show()))
		i += 1
	if focus_btn == null:
		focus_btn = ThemeS.btn("Close  (B)", func(): close_ui())
	box.add_child(ThemeS.btn("Close  (B)", func(): close_ui()))


func _rebuild_vendor() -> void:
	_clear()
	box.add_child(ThemeS.lab("Vendor Stall", 32, Color(0.95, 0.82, 0.5)))
	box.add_child(ThemeS.lab("Bank %dg  %d ore   ·   potions and rations for the next drop." % [App.bank_gold, App.bank_ore], 18, Color(0.82, 0.76, 0.66)))
	status = ThemeS.lab("", 20, Color(0.95, 0.8, 0.45))
	box.add_child(status)
	focus_btn = ThemeS.btn("Buy potion  (%dg)" % int(App.bal.vendor_potion_cost), func(): _vend_potion())
	box.add_child(focus_btn)
	box.add_child(ThemeS.btn("Buy ration  (%dg, food slot)" % int(App.bal.vendor_food_cost), func(): _vend_food()))
	box.add_child(ThemeS.btn("Sell 1 ore  (%dg)" % int(App.bal.vendor_ore_gold), func(): _vend_sell()))
	box.add_child(ThemeS.btn("Leave  (B)", func(): close_ui()))


func _vend_potion() -> void:
	var cost := int(App.bal.vendor_potion_cost)
	if App.bank_gold < cost:
		_st("Not enough banked gold.")
		return
	App.bank_gold -= cost
	var pot: Dictionary = App.prog.slots.get("potion", {})
	if pot.is_empty():
		App.prog.slots["potion"] = App.prog.make_potion(1)
	else:
		pot.stack = int(pot.get("stack", 0)) + 1
		App.prog.slots["potion"] = pot
	_st("Potion stowed.")
	App.save_now()


func _vend_food() -> void:
	var cost := int(App.bal.vendor_food_cost)
	if App.bank_gold < cost:
		_st("Not enough banked gold.")
		return
	var fd: Dictionary = App.prog.slots.get("food", {})
	var cap := int(App.bal.food_bring_max)
	if not fd.is_empty() and int(fd.get("stack", 0)) >= cap:
		_st("Food slot is full (%d)." % cap)
		return
	App.bank_gold -= cost
	if fd.is_empty():
		App.prog.slots["food"] = App.prog.make_food("ration", 1)
	else:
		fd.stack = mini(int(fd.get("stack", 0)) + 1, cap)
		App.prog.slots["food"] = fd
	_st("Ration packed in the food slot.")
	App.save_now()


func _vend_sell() -> void:
	if App.bank_ore < 1:
		_st("No ore in the bank.")
		return
	App.bank_ore -= 1
	App.bank_gold += int(App.bal.vendor_ore_gold)
	_st("Sold 1 ore.")
	App.save_now()


func _rebuild_controls() -> void:
	_clear()
	box.add_child(ThemeS.lab("Controls Billboard", 32, Color(0.95, 0.82, 0.5)))
	box.add_child(ThemeS.lab("What the guild painted up. Bindings follow your System tab.", 18, Color(0.82, 0.76, 0.66)))
	var acts := [
		["move_left", "Move left"],
		["move_right", "Move right"],
		["move_up", "Move up"],
		["move_down", "Move down"],
		["attack", "Attack (RT / LMB)"],
		["special", "Special (LT)"],
		["dash", "Dash (B)"],
		["interact", "Interact (A)"],
		["pause", "Pause (Start)"],
		["potion", "Potion (D-pad Up)"],
		["food", "Food (D-pad Left)"],
		["map_view", "Map (View)"],
		["target_lock", "Target-lock (R3)"],
	]
	for pair in acts:
		var name: String = str(pair[0])
		var lab: String = str(pair[1])
		box.add_child(ThemeS.lab("%s  —  %s" % [lab, ThemeS.bind_text(name)], 18, Color(0.9, 0.86, 0.74)))
	focus_btn = ThemeS.btn("Leave  (B)", func(): close_ui())
	box.add_child(focus_btn)


func _confirm(fn: Callable, id := "anon") -> void:
	if not pending or pending_id != id:
		pending = true
		pending_id = id
		pending_fn = fn
		_st("A again to confirm. B cancels.")
		return
	pending = false
	pending_id = ""
	fn.call()


func _extract_all() -> void:
	App.prog.extract_all("patty")


func _process(delta: float) -> void:
	if forge_t <= 0.0:
		return
	forge_t = maxf(0.0, forge_t - delta)
	if status:
		status.text = "Forging… %.1fs. B cancels." % forge_t
	if forge_t > 0.0:
		return
	var it: Dictionary = forge_it
	forge_it = {}
	if it.is_empty():
		return
	var msg := App.prog.forge_item(it)
	_st(msg)
	if msg.begins_with("Forged"):
		anvil_item = {}
	if open and mode == "anvil":
		_rebuild_anvil()
		_show()


func _unhandled_input(event: InputEvent) -> void:
	if not open:
		return
	if event.is_action_pressed("ui_cancel") or event.is_action_pressed("pause"):
		if pending:
			pending = false
			pending_id = ""
			App.sfx("ui_cancel")
			_st("Cancelled.")
		else:
			App.sfx("ui_cancel")
			close_ui()
		get_viewport().set_input_as_handled()
