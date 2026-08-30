extends CanvasLayer

const ThemeS := preload("res://scripts/ui/theme.gd")
const CatalogS := preload("res://scripts/data/catalog.gd")
const T := preload("res://scripts/data/tunables.gd")

const SKILL_NAMES := {
	"axe": "Great Axe",
	"staff": "Staff",
	"bow": "Longbow",
	"str": "Strength",
	"mag": "Magic",
	"rng": "Ranged",
	"def": "Defense",
	"hp": "Hitpoints",
	"mine": "Mining",
	"wood": "Woodcutting",
	"smith": "Smithing",
}

const SLOT_NAMES := {
	"weapon": "Weapon",
	"tool": "Tool",
	"potion": "Potion",
	"food": "Food",
	"head": "Head",
	"body": "Body",
	"legs": "Legs",
}

const BAG_COLS := 7

var open := false
var tab := 0
var box: VBoxContainer
var tabs: HBoxContainer
var scroll: ScrollContainer
var status: Label
var focus_btn: Control
var pending := false
var pending_id := ""
var pending_fn: Callable
var rebind_action := ""
var sys_page := "main"
var tip_host: PanelContainer
var tip_lab: Label
var tip_id := ""
var tip_kind := ""
var tip_from: Control = null
var inv_sel := ""
var inv_detail: Label
var inv_btn_use: Button
var inv_btn_equip: Button
var inv_btn_unequip: Button
var inv_btn_drop: Button


func _ready() -> void:
	layer = 55
	visible = false
	process_mode = Node.PROCESS_MODE_ALWAYS
	var dim := ColorRect.new()
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.color = Color(0.03, 0.02, 0.02, 0.78)
	add_child(dim)
	var panel := ColorRect.new()
	panel.color = Color(0.13, 0.1, 0.08, 0.96)
	panel.position = Vector2(220, 40)
	panel.size = Vector2(1480, 1000)
	add_child(panel)
	var edge := ColorRect.new()
	edge.color = Color(0.55, 0.42, 0.22, 1)
	edge.position = Vector2(220, 40)
	edge.size = Vector2(1480, 8)
	add_child(edge)
	tabs = HBoxContainer.new()
	tabs.position = Vector2(244, 60)
	tabs.size = Vector2(1432, 56)
	tabs.add_theme_constant_override("separation", 12)
	add_child(tabs)
	scroll = ScrollContainer.new()
	scroll.position = Vector2(244, 128)
	scroll.size = Vector2(1432, 880)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.focus_mode = Control.FOCUS_NONE
	scroll.follow_focus = true
	add_child(scroll)
	box = VBoxContainer.new()
	box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	box.custom_minimum_size = Vector2(1400, 0)
	box.add_theme_constant_override("separation", 8)
	scroll.add_child(box)
	_make_tip()


func _make_tip() -> void:
	tip_host = PanelContainer.new()
	tip_host.visible = false
	tip_host.mouse_filter = Control.MOUSE_FILTER_IGNORE
	tip_host.z_index = 20
	tip_host.add_theme_stylebox_override("panel", ThemeS.sb(Color(0.09, 0.07, 0.05, 0.97), Color(0.85, 0.68, 0.32)))
	tip_lab = Label.new()
	tip_lab.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	tip_lab.custom_minimum_size = Vector2(380, 0)
	tip_lab.add_theme_font_size_override("font_size", 18)
	tip_lab.add_theme_color_override("font_color", Color(0.93, 0.86, 0.72))
	tip_lab.add_theme_color_override("font_outline_color", Color(0.05, 0.03, 0.02))
	tip_lab.add_theme_constant_override("outline_size", 6)
	tip_host.add_child(tip_lab)
	add_child(tip_host)


func toggle() -> void:
	if open:
		close_ui()
	else:
		show_menu()


func show_menu() -> void:
	open = true
	visible = true
	App.ui_open = true
	get_tree().paused = true
	tab = 0
	sys_page = "main"
	pending = false
	pending_id = ""
	rebind_action = ""
	inv_sel = "slot:weapon"
	_hide_tip()
	_rebuild()


func close_ui() -> void:
	open = false
	visible = false
	pending = false
	pending_id = ""
	rebind_action = ""
	sys_page = "main"
	_hide_tip()
	App.ui_open = false
	get_tree().paused = false
	App.save_now()
	App.swallow_close_pad()
	App.wake_web_pad()


func _rebuild() -> void:
	_hide_tip()
	for c in tabs.get_children():
		c.queue_free()
	for c in box.get_children():
		c.queue_free()
	focus_btn = null
	status = null
	inv_detail = null
	inv_btn_use = null
	inv_btn_equip = null
	inv_btn_unequip = null
	inv_btn_drop = null
	var names := ["Inventory", "Skills", "System"]
	for i in 3:
		var ii := i
		var b := ThemeS.btn(names[i], func():
			tab = ii
			sys_page = "main"
			_rebuild()
		)
		if i == tab:
			b.add_theme_color_override("font_color", Color(1, 0.92, 0.45))
		tabs.add_child(b)
		if focus_btn == null:
			focus_btn = b
	match tab:
		0:
			_inv()
		1:
			_skills()
		_:
			_system()
	call_deferred("_focus")


func _focus() -> void:
	if tab == 0:
		var hit := _inv_find_sel()
		if hit:
			hit.grab_focus()
			return
	if focus_btn:
		focus_btn.grab_focus()
		return
	for n in find_children("*", "Button", true, false):
		(n as Button).grab_focus()
		return


func _cap(text: String, size := 18, col := Color(0.9, 0.84, 0.7)) -> Label:
	var l := Label.new()
	l.text = text
	l.autowrap_mode = TextServer.AUTOWRAP_OFF
	l.clip_text = false
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	l.custom_minimum_size = Vector2(520, 26)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", col)
	l.add_theme_color_override("font_outline_color", Color(0.05, 0.03, 0.02))
	l.add_theme_constant_override("outline_size", 6)
	return l


func _inv() -> void:
	box.add_child(_cap("Carried  %dg   %d ore   %d wood   bag %d/%d" % [
		App.gold, App.ore, App.wood, App.prog.bag_count(), int(App.bal.bag_cap)
	], 22, Color(0.95, 0.8, 0.45)))
	box.add_child(_cap(_inv_status_line(), 16, Color(0.78, 0.74, 0.66)))
	var hint := "A on an item uses or equips it. Buttons below act on the highlighted item."
	if App.in_dungeon:
		hint += " Drop puts it on the floor."
	else:
		hint += " Drop is dungeon-only."
	box.add_child(_cap(hint, 16, Color(0.7, 0.66, 0.6)))
	inv_detail = _cap("Select an item.", 18, Color(0.9, 0.84, 0.7))
	inv_detail.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	inv_detail.custom_minimum_size = Vector2(1360, 72)
	box.add_child(inv_detail)
	var acts := HBoxContainer.new()
	acts.add_theme_constant_override("separation", 10)
	inv_btn_use = ThemeS.btn("Use", _inv_use)
	inv_btn_equip = ThemeS.btn("Equip", _inv_equip)
	inv_btn_unequip = ThemeS.btn("Unequip", _inv_unequip)
	inv_btn_drop = ThemeS.btn("Drop", _inv_drop)
	acts.add_child(inv_btn_use)
	acts.add_child(inv_btn_equip)
	acts.add_child(inv_btn_unequip)
	acts.add_child(inv_btn_drop)
	box.add_child(acts)
	box.add_child(_cap("Equipped", 20, Color(0.88, 0.82, 0.7)))
	var first_row: Control = null
	for s in App.prog.SLOTS:
		var row := _inv_slot_btn(s)
		box.add_child(row)
		if first_row == null:
			first_row = row
	var sets_line := _inv_sets_line()
	if sets_line != "":
		box.add_child(_cap("Artifact sets", 20, Color(0.88, 0.82, 0.7)))
		var sl := _cap(sets_line, 18, Color(0.82, 0.76, 0.62))
		sl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		sl.custom_minimum_size = Vector2(1360, 0)
		box.add_child(sl)
	box.add_child(_cap("Bag", 20, Color(0.88, 0.82, 0.7)))
	var grid := GridContainer.new()
	grid.columns = BAG_COLS
	grid.add_theme_constant_override("h_separation", 8)
	grid.add_theme_constant_override("v_separation", 8)
	var cap := maxi(int(App.bal.bag_cap), App.prog.bag.size())
	for i in cap:
		var it: Dictionary = {}
		if i < App.prog.bag.size() and App.prog.bag[i] is Dictionary:
			it = App.prog.bag[i]
		grid.add_child(_inv_bag_cell(it, i))
	box.add_child(grid)
	if first_row:
		focus_btn = first_row
	status = _cap("", 16, Color(0.78, 0.74, 0.66))
	box.add_child(status)
	box.add_child(ThemeS.btn("Close  (B)", close_ui))
	_inv_refresh_detail()


func _inv_status_line() -> String:
	var bits: PackedStringArray = PackedStringArray()
	var pot: Dictionary = App.prog.slots.get("potion", {})
	if pot.is_empty() or int(pot.get("stack", 0)) <= 0:
		bits.append("Potion slot empty")
	elif App.prog.potion_cd > 0.05:
		bits.append("Potion CD %.1fs" % App.prog.potion_cd)
	else:
		bits.append("Potion x%d ready" % int(pot.stack))
	if App.prog.food_t > 0.05:
		bits.append("Food ticking %.1fs" % App.prog.food_t)
	else:
		var fd: Dictionary = App.prog.slots.get("food", {})
		if fd.is_empty() or int(fd.get("stack", 0)) <= 0:
			bits.append("Food slot empty")
		else:
			bits.append("%s x%d ready" % [str(fd.get("name", "Food")), int(fd.stack)])
	return "  ·  ".join(bits)


func _inv_sets_line() -> String:
	var counts: Dictionary = App.prog.set_counts()
	var parts: PackedStringArray = PackedStringArray()
	for sid in CatalogS.set_ids():
		var n := int(counts.get(sid, 0))
		if n <= 0:
			continue
		var need := CatalogS.set_size(sid)
		var bit := "%s %d/%d" % [str(sid).capitalize(), n, need]
		if n >= 2:
			var bonus := CatalogS.set_bonus_line(sid, n)
			if bonus != "":
				bit += " — " + bonus
		parts.append(bit)
	return "   ".join(parts)


func _inv_slot_btn(slot: String) -> Button:
	var it: Dictionary = App.prog.slots.get(slot, {})
	var title := str(SLOT_NAMES.get(slot, slot))
	var body := "empty"
	if not it.is_empty():
		body = _inv_item_short(it)
	var b := ThemeS.btn("%s	%s" % [title, body], func():
		inv_sel = "slot:" + slot
		_inv_refresh_detail()
		_inv_primary()
	)
	b.alignment = HORIZONTAL_ALIGNMENT_LEFT
	b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	b.add_theme_color_override("font_color", _inv_item_color(it))
	b.set_meta("inv_key", "slot:" + slot)
	b.focus_entered.connect(func():
		inv_sel = "slot:" + slot
		_inv_refresh_detail()
	)
	return b


func _inv_bag_cell(it: Dictionary, index: int) -> Button:
	var b := Button.new()
	b.custom_minimum_size = Vector2(188, 64)
	b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	b.add_theme_font_size_override("font_size", 16)
	b.add_theme_color_override("font_hover_color", Color(1, 0.95, 0.75))
	b.add_theme_color_override("font_focus_color", Color(1, 0.92, 0.55))
	b.add_theme_color_override("font_disabled_color", Color(0.38, 0.35, 0.32))
	b.add_theme_stylebox_override("normal", ThemeS.sb(Color(0.18, 0.14, 0.1), Color(0.4, 0.3, 0.18)))
	b.add_theme_stylebox_override("hover", ThemeS.sb(Color(0.26, 0.2, 0.13), Color(0.75, 0.58, 0.28)))
	b.add_theme_stylebox_override("pressed", ThemeS.sb(Color(0.14, 0.11, 0.08), Color(0.9, 0.7, 0.3)))
	b.add_theme_stylebox_override("focus", ThemeS.sb(Color(0.28, 0.2, 0.12), Color(0.95, 0.78, 0.35)))
	b.add_theme_stylebox_override("disabled", ThemeS.sb(Color(0.11, 0.09, 0.08), Color(0.22, 0.18, 0.14)))
	if it.is_empty():
		b.text = "—"
		b.disabled = true
		b.focus_mode = Control.FOCUS_NONE
		b.add_theme_color_override("font_color", Color(0.4, 0.36, 0.32))
		return b
	var key := "bag:" + str(int(it.uid))
	b.text = _inv_item_cell(it)
	b.add_theme_color_override("font_color", _inv_item_color(it))
	b.set_meta("inv_key", key)
	b.pressed.connect(func():
		inv_sel = key
		_inv_refresh_detail()
		_inv_primary()
	)
	b.focus_entered.connect(func():
		inv_sel = key
		_inv_refresh_detail()
	)
	return b


func _inv_item_short(it: Dictionary) -> String:
	if it.is_empty():
		return "empty"
	var nm := str(it.get("name", "item"))
	var stack := int(it.get("stack", 1))
	if stack > 1:
		nm += "  x%d" % stack
	var rare := str(it.get("rarity", "white"))
	if rare != "" and rare != "white" and str(it.get("kind", "")) != "artifact":
		nm += "  [%s]" % rare
	if bool(it.get("hold", false)):
		nm += "  (hold)"
	return nm


func _inv_item_cell(it: Dictionary) -> String:
	var nm := str(it.get("name", "item"))
	var stack := int(it.get("stack", 1))
	if stack > 1:
		nm += "\nx%d" % stack
	elif bool(it.get("hold", false)):
		nm += "\nhold"
	elif str(it.get("kind", "")) == "artifact":
		nm += "\n" + str(it.get("set", "relic"))
	return nm


func _inv_item_color(it: Dictionary) -> Color:
	if it.is_empty():
		return Color(0.62, 0.58, 0.52)
	match str(it.get("rarity", "white")):
		"green":
			return Color(0.55, 0.86, 0.52)
		"blue":
			return Color(0.52, 0.7, 1.0)
		_:
			if str(it.get("kind", "")) == "artifact":
				return Color(0.92, 0.78, 0.48)
			return Color(0.92, 0.84, 0.62)


func _inv_selected() -> Dictionary:
	if inv_sel.begins_with("slot:"):
		var slot := inv_sel.substr(5)
		var it: Dictionary = App.prog.slots.get(slot, {})
		return it if it is Dictionary else {}
	if inv_sel.begins_with("bag:"):
		var uid := int(inv_sel.substr(4))
		for raw in App.prog.bag:
			if raw is Dictionary and int(raw.uid) == uid:
				return raw
	return {}


func _inv_selected_slot() -> String:
	if inv_sel.begins_with("slot:"):
		return inv_sel.substr(5)
	return ""


func _inv_selected_uid() -> int:
	if inv_sel.begins_with("bag:"):
		return int(inv_sel.substr(4))
	var it := _inv_selected()
	if it.is_empty():
		return 0
	return int(it.get("uid", 0))


func _inv_from_bag() -> bool:
	return inv_sel.begins_with("bag:")


func _inv_find_sel() -> Control:
	if inv_sel == "":
		return null
	for n in box.find_children("*", "Button", true, false):
		if str(n.get_meta("inv_key", "")) == inv_sel:
			return n
	return null


func _inv_refresh_detail() -> void:
	var it := _inv_selected()
	if inv_detail:
		inv_detail.text = _inv_detail_text(it)
	var can_use := _inv_can_use(it)
	var can_equip := _inv_can_equip(it)
	var can_unequip := (not it.is_empty()) and not _inv_from_bag()
	var can_drop := (not it.is_empty()) and App.in_dungeon
	if inv_btn_use:
		inv_btn_use.disabled = not can_use
	if inv_btn_equip:
		inv_btn_equip.disabled = not can_equip
	if inv_btn_unequip:
		inv_btn_unequip.disabled = not can_unequip
	if inv_btn_drop:
		inv_btn_drop.disabled = not can_drop


func _inv_detail_text(it: Dictionary) -> String:
	if it.is_empty():
		if inv_sel.begins_with("slot:"):
			return "%s — empty" % str(SLOT_NAMES.get(_inv_selected_slot(), "Slot"))
		return "Empty bag slot."
	var lines: PackedStringArray = PackedStringArray()
	var head := str(it.get("name", "Item"))
	var kind := str(it.get("kind", ""))
	var rare := str(it.get("rarity", "white"))
	if kind != "artifact" and rare != "":
		head += "   ·   " + rare.capitalize()
	if int(it.get("stack", 1)) > 1:
		head += "   ·   x%d" % int(it.stack)
	if bool(it.get("hold", false)):
		head += "   ·   forged hold"
	if kind == "artifact":
		head += "   ·   run relic"
	lines.append(head)
	var desc := str(it.get("desc", ""))
	if desc != "":
		lines.append(desc)
	var stats := _inv_stat_line(it)
	if stats != "":
		lines.append(stats)
	var sid := str(it.get("set", ""))
	if sid != "":
		lines.append(App.prog.set_bonus_text(sid))
	return "\n".join(lines)


func _inv_stat_line(it: Dictionary) -> String:
	var bits: PackedStringArray = PackedStringArray()
	if int(it.get("dmg", 0)) > 0:
		bits.append("+%d damage" % int(it.dmg))
	if int(it.get("def", 0)) > 0:
		bits.append("+%d defense" % int(it.def))
	if int(it.get("hp", 0)) > 0:
		bits.append("+%d HP" % int(it.hp))
	var slot := str(it.get("slot", ""))
	if slot != "" and str(SLOT_NAMES.get(slot, "")) != "":
		bits.append(str(SLOT_NAMES[slot]) + " slot")
	if str(it.get("tool", "")) != "":
		bits.append("Tool: " + str(it.tool))
		if App.in_dungeon and str(it.tool) != App.prog.tool_type:
			bits.append("locked out this run")
	if kind_extract_note(it) != "":
		bits.append(kind_extract_note(it))
	return "   ·   ".join(bits)


func kind_extract_note(it: Dictionary) -> String:
	if str(it.get("kind", "")) == "artifact":
		return "Cannot mail. Lost on death or Dispel."
	if bool(it.get("hold", false)):
		return "Hold returns to Placeholdia."
	if App.in_dungeon:
		return "Mail through a clerk to keep it."
	return ""


func _inv_can_use(it: Dictionary) -> bool:
	if it.is_empty():
		return false
	var k := str(it.get("kind", ""))
	return k == "potion" or k == "food"


func _inv_can_equip(it: Dictionary) -> bool:
	if it.is_empty() or not _inv_from_bag():
		return false
	var slot := str(it.get("slot", ""))
	if App.prog.SLOTS.find(slot) < 0:
		return false
	if slot == "tool":
		var t := str(it.get("tool", ""))
		if t != "" and t != App.prog.tool_type:
			return false
	return true


func _inv_act(msg: String) -> void:
	_st(msg)
	App.save_now()
	_rebuild()


func _inv_primary() -> void:
	var it := _inv_selected()
	if it.is_empty():
		return
	if _inv_can_use(it):
		_inv_use()
		return
	if _inv_can_equip(it):
		_inv_equip()
		return
	_inv_refresh_detail()


func _inv_use() -> void:
	var it := _inv_selected()
	if not _inv_can_use(it):
		_st("Can't use that.")
		return
	var msg := ""
	if _inv_from_bag():
		msg = App.prog.use_from_bag(int(it.uid))
	elif str(it.kind) == "potion":
		msg = App.prog.use_potion()
	else:
		msg = App.prog.use_food()
	_inv_act(msg)


func _inv_equip() -> void:
	var it := _inv_selected()
	if not _inv_can_equip(it):
		_st("Can't equip that.")
		return
	var slot := str(it.get("slot", ""))
	var msg := App.prog.equip_uid(int(it.uid))
	inv_sel = "slot:" + slot
	_inv_act(msg)


func _inv_unequip() -> void:
	if _inv_from_bag():
		_st("Already in the bag.")
		return
	var slot := _inv_selected_slot()
	if slot == "":
		_st("Nothing to unequip.")
		return
	var msg := App.prog.unequip_slot(slot)
	if msg.begins_with("Unequipped"):
		var it: Dictionary = {}
		if App.prog.bag.size() > 0:
			it = App.prog.bag[App.prog.bag.size() - 1]
		if not it.is_empty():
			inv_sel = "bag:" + str(int(it.uid))
	_inv_act(msg)


func _inv_drop() -> void:
	if not App.in_dungeon:
		_st("Drop on the dungeon floor only.")
		return
	var it := _inv_selected()
	if it.is_empty():
		_st("Nothing to drop.")
		return
	var msg := ""
	if _inv_from_bag():
		msg = App.prog.drop_uid(int(it.uid))
	else:
		msg = App.prog.drop_slot(_inv_selected_slot())
	inv_sel = "slot:weapon"
	_inv_act(msg)


func _xp_lv(total: float) -> int:
	return App.prog.level_from_xp(total)


func _xp_to_next(total: float) -> int:
	return int(round(App.prog.xp_to_next(total)))


func _xp_ratio(total: float) -> float:
	return App.prog.xp_ratio(total)


func _skill_title(id: String) -> String:
	return str(SKILL_NAMES.get(id, id))


func _perm_line(id: String, perm: float) -> String:
	return "%s Lv %d | Next Level: %dXP | Total XP: %dXP" % [
		_skill_title(id),
		_xp_lv(perm),
		_xp_to_next(perm),
		int(round(perm)),
	]


func _run_line(id: String, perm: float, runx: float) -> String:
	var live := perm + runx
	return "%s Lv %d | This Run: %dXP | Next Level: %dXP" % [
		_skill_title(id),
		_xp_lv(live),
		int(round(runx)),
		_xp_to_next(live),
	]


func _skill_lab(text: String, size := 16, col := Color(0.9, 0.84, 0.7)) -> Label:
	var l := Label.new()
	l.text = text
	l.autowrap_mode = TextServer.AUTOWRAP_OFF
	l.clip_text = false
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	l.custom_minimum_size = Vector2(0, 22)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", col)
	l.add_theme_color_override("font_outline_color", Color(0.05, 0.03, 0.02))
	l.add_theme_constant_override("outline_size", 6)
	return l


func _xp_bar(ratio: float, fill_col: Color) -> ColorRect:
	var track := ColorRect.new()
	track.mouse_filter = Control.MOUSE_FILTER_IGNORE
	track.custom_minimum_size = Vector2(0, 16)
	track.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	track.color = Color(0.18, 0.14, 0.1)
	track.clip_contents = true
	var fill := ColorRect.new()
	fill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	fill.color = fill_col
	fill.set_anchors_preset(Control.PRESET_FULL_RECT)
	fill.anchor_right = clampf(ratio, 0.0, 1.0)
	fill.offset_left = 0.0
	fill.offset_top = 0.0
	fill.offset_right = 0.0
	fill.offset_bottom = 0.0
	track.add_child(fill)
	return track


func _skill_block(id: String, kind: String, text: String, ratio: float, fill_col: Color) -> PanelContainer:
	var wrap := ThemeS.skill_row()
	var inner := VBoxContainer.new()
	inner.mouse_filter = Control.MOUSE_FILTER_IGNORE
	inner.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	inner.add_theme_constant_override("separation", 4)
	inner.add_child(_skill_lab(text))
	inner.add_child(_xp_bar(ratio, fill_col))
	wrap.add_child(inner)
	wrap.set_meta("skill_id", id)
	wrap.set_meta("skill_kind", kind)
	wrap.focus_entered.connect(_on_skill_focus.bind(id, kind, wrap))
	wrap.mouse_entered.connect(_on_skill_focus.bind(id, kind, wrap))
	wrap.focus_exited.connect(_on_skill_blur.bind(wrap))
	wrap.mouse_exited.connect(_on_skill_blur.bind(wrap))
	return wrap


func _on_skill_focus(id: String, kind: String, from: Control) -> void:
	if from is PanelContainer:
		(from as PanelContainer).add_theme_stylebox_override("panel", ThemeS.skill_row_sb(true))
	tip_id = id
	tip_kind = kind
	tip_from = from
	_paint_tip()


func _on_skill_blur(from: Control) -> void:
	if from is PanelContainer and not from.has_focus():
		(from as PanelContainer).add_theme_stylebox_override("panel", ThemeS.skill_row_sb(false))
	call_deferred("_blur_tip")


func _blur_tip() -> void:
	var f := get_viewport().gui_get_focus_owner()
	if f != null and f.has_meta("skill_id"):
		return
	_hide_tip()


func _hide_tip() -> void:
	tip_id = ""
	tip_kind = ""
	tip_from = null
	if tip_host:
		tip_host.visible = false


func _tip_lv(id: String, kind: String) -> int:
	var perm := float(App.prog.skills_perm.get(id, 0.0))
	var runx := float(App.prog.skills_run.get(id, 0.0))
	if kind == "run":
		return _xp_lv(perm + runx)
	return _xp_lv(perm)


func _paint_tip() -> void:
	if tip_id == "" or tip_from == null or not is_instance_valid(tip_from):
		if tip_host:
			tip_host.visible = false
		return
	tip_lab.text = ThemeS.skill_tip(tip_id, _tip_lv(tip_id, tip_kind))
	var w := 404.0
	tip_lab.custom_minimum_size = Vector2(w - 24.0, 0.0)
	var h := maxf(80.0, tip_lab.get_minimum_size().y + 20.0)
	tip_host.size = Vector2(w, h)
	var r := tip_from.get_global_rect()
	var pos := Vector2(r.position.x, r.position.y + r.size.y + 8.0)
	if pos.y + h > 1060.0:
		pos.y = r.position.y - h - 8.0
	if pos.x + w > 1900.0:
		pos.x = 1900.0 - w
	if pos.x < 20.0:
		pos.x = 20.0
	tip_host.position = pos
	tip_host.visible = true


func _skills() -> void:
	box.add_child(_cap("Combat Level %d" % App.prog.combat_lv(), 24, Color(0.95, 0.8, 0.45)))
	box.add_child(_cap("Highlight a skill for its bonuses.", 16, Color(0.78, 0.74, 0.66)))
	var perm_col := Color(0.72, 0.56, 0.28)
	var run_col := Color(0.86, 0.74, 0.32)
	var first: PanelContainer = null
	if App.in_dungeon:
		var heads := HBoxContainer.new()
		heads.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		heads.add_theme_constant_override("separation", 24)
		heads.add_child(_skill_lab("Permanent", 18, Color(0.95, 0.8, 0.45)))
		heads.add_child(_skill_lab("Dungeon XP", 18, Color(0.95, 0.8, 0.45)))
		box.add_child(heads)
		for id in App.prog.SKILLS:
			var perm := float(App.prog.skills_perm.get(id, 0.0))
			var runx := float(App.prog.skills_run.get(id, 0.0))
			var row := HBoxContainer.new()
			row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			row.add_theme_constant_override("separation", 24)
			var left := _skill_block(id, "perm", _perm_line(id, perm), _xp_ratio(perm), perm_col)
			var right := _skill_block(id, "run", _run_line(id, perm, runx), _xp_ratio(perm + runx), run_col)
			row.add_child(left)
			row.add_child(right)
			box.add_child(row)
			if first == null:
				first = left
	else:
		for id in App.prog.SKILLS:
			var perm := float(App.prog.skills_perm.get(id, 0.0))
			var row := _skill_block(id, "perm", _perm_line(id, perm), _xp_ratio(perm), perm_col)
			box.add_child(row)
			if first == null:
				first = row
	if first:
		focus_btn = first
	box.add_child(ThemeS.btn("Close  (B)", close_ui))


func _system() -> void:
	if sys_page == "rebind":
		_rebind()
		return
	box.add_child(_cap("System", 24, Color(0.95, 0.8, 0.45)))
	var char_btn := ThemeS.btn("Character: %s" % App.character_type, func():
		var nxt := "female" if App.character_type == "male" else "male"
		if App.has_method("set_character"):
			App.set_character(nxt)
		else:
			App.character_type = nxt
		App.save_now()
		_rebuild()
	)
	box.add_child(char_btn)
	box.add_child(_slider_row("Master volume", App.vol_master, 0.0, 1.0, 0.01, func(v: float):
		App.set_volume("master", v)
	))
	box.add_child(_slider_row("Music volume", App.vol_music, 0.0, 1.0, 0.01, func(v: float):
		App.set_volume("music", v)
	))
	box.add_child(_slider_row("SFX volume", App.vol_sfx, 0.0, 1.0, 0.01, func(v: float):
		App.set_volume("sfx", v)
	))
	box.add_child(_slider_row("Camera zoom", App.cam_zoom, T.ZOOM_MIN, T.ZOOM_MAX, 0.05, func(v: float):
		App.cam_zoom = v
	))
	box.add_child(_slider_row("HUD scale", App.hud_scale, 0.7, 1.4, 0.05, func(v: float):
		App.hud_scale = v
	))
	box.add_child(ThemeS.btn("Aim line: %s" % ("On" if App.bal.aim_line_on else "Off"), func():
		App.bal.aim_line_on = not App.bal.aim_line_on
		App.save_now()
		_rebuild()
	))
	box.add_child(_slider_row("Aim line opacity", App.bal.aim_line_opacity, 0.05, 1.0, 0.05, func(v: float):
		App.bal.aim_line_opacity = v
	))
	if App.in_dungeon:
		box.add_child(ThemeS.btn("Dispel Avatar", func():
			_confirm(func():
				close_ui()
				App.end_run("dispel")
			, "dispel")
		))
	box.add_child(ThemeS.btn("Archives", func():
		if App.archives_ui and App.archives_ui.has_method("show_browser"):
			App.archives_ui.show_browser()
	))
	box.add_child(ThemeS.btn("Rebind controls", func():
		sys_page = "rebind"
		_rebuild()
	))
	if App.has_method("reset_binds"):
		box.add_child(ThemeS.btn("Reset binds", func():
			App.reset_binds()
			App.save_now()
			_st("Binds reset.")
		))
	box.add_child(ThemeS.btn("Patreon", func():
		OS.shell_open("https://www.patreon.com/cw/ViraXVespa")
	))
	box.add_child(ThemeS.btn("Delete Save Data", func():
		_confirm(func():
			App.wipe_save()
			close_ui()
			App.go_title()
		, "wipe")
	))
	status = _cap("A again to confirm a marked action. B cancels.", 16, Color(0.78, 0.74, 0.66))
	box.add_child(status)
	box.add_child(ThemeS.btn("Close  (B)", close_ui))


func _rebind() -> void:
	box.add_child(_cap("Rebind controls", 24, Color(0.95, 0.8, 0.45)))
	box.add_child(_cap("Highlight an action, press A, then the new key or button.", 18, Color(0.82, 0.76, 0.66)))
	var binds: Array = []
	if App.has_method("collect_binds"):
		binds = App.collect_binds()
	if binds.is_empty():
		box.add_child(_cap("No bind list exposed.", 18, Color(0.7, 0.66, 0.6)))
	else:
		for raw in binds:
			if raw is Dictionary:
				var d: Dictionary = raw
				var act := str(d.get("action", d.get("id", "")))
				var lab := str(d.get("label", act))
				var cur := str(d.get("bind", d.get("key", "")))
				var a2 := act
				box.add_child(ThemeS.btn("%s   [%s]" % [lab, cur], func():
					rebind_action = a2
					_st("Press a key or button for %s." % lab)
				))
	if App.has_method("reset_binds"):
		box.add_child(ThemeS.btn("Reset binds", func():
			App.reset_binds()
			App.save_now()
			_rebuild()
		))
	box.add_child(ThemeS.btn("Back", func():
		sys_page = "main"
		rebind_action = ""
		_rebuild()
	))
	status = _cap("", 16, Color(0.78, 0.74, 0.66))
	box.add_child(status)


func _slider_row(title: String, value: float, lo: float, hi: float, step: float, on_change: Callable) -> VBoxContainer:
	var wrap := VBoxContainer.new()
	wrap.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	wrap.custom_minimum_size = Vector2(720, 0)
	wrap.add_theme_constant_override("separation", 4)
	wrap.add_child(_cap(title, 20, Color(0.9, 0.84, 0.7)))
	var sl := HSlider.new()
	sl.min_value = lo
	sl.max_value = hi
	sl.step = step
	sl.value = value
	sl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sl.custom_minimum_size = Vector2(720, 28)
	sl.focus_mode = Control.FOCUS_ALL
	sl.value_changed.connect(on_change)
	wrap.add_child(sl)
	return wrap


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


func _st(msg: String) -> void:
	if status:
		status.text = msg
	App.sfx("ui")


func _input(event: InputEvent) -> void:
	if not open or rebind_action == "":
		return
	if event is InputEventKey and event.pressed and not event.echo:
		if App.has_method("rebind"):
			App.rebind(rebind_action, event)
		rebind_action = ""
		App.save_now()
		_rebuild()
		get_viewport().set_input_as_handled()
	elif event is InputEventJoypadButton and event.pressed:
		if App.has_method("rebind"):
			App.rebind(rebind_action, event)
		rebind_action = ""
		App.save_now()
		_rebuild()
		get_viewport().set_input_as_handled()


func _unhandled_input(event: InputEvent) -> void:
	if not open:
		return
	if App.archives_ui and bool(App.archives_ui.get("open")):
		return
	if event.is_action_pressed("tab_right"):
		tab = (tab + 1) % 3
		sys_page = "main"
		_rebuild()
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("tab_left"):
		tab = (tab + 2) % 3
		sys_page = "main"
		_rebuild()
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("ui_cancel") or event.is_action_pressed("pause"):
		if pending:
			pending = false
			pending_id = ""
			App.sfx("ui_cancel")
			_st("Cancelled.")
		elif sys_page == "rebind":
			sys_page = "main"
			rebind_action = ""
			App.sfx("ui_cancel")
			_rebuild()
		else:
			App.sfx("ui_cancel")
			close_ui()
		if App.has_method("swallow_close_pad"):
			App.swallow_close_pad()
		get_viewport().set_input_as_handled()
