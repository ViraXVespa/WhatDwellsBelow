extends Object

const ThemeS := preload("res://scripts/ui/theme.gd")
const Prompts := preload("res://scripts/input/prompts.gd")
const PromptView := preload("res://scripts/ui/prompt_view.gd")


static func _anvil():
	return load("res://scripts/ui/gear_board_anvil.gd")


static func tab(ui: CanvasLayer) -> String:
	var t := str(ui.get("anvil_tab"))
	return t if t == "forge" else "analyze"


static func footer(ui: CanvasLayer) -> void:
	_tabs(ui)
	ui.box.add_child(ThemeS.lab("Bank %dg  %d ore  %d root    Carried %dg  %d ore  %d root" % [App.bank_gold, App.bank_ore, App.bank_root, App.gold, App.ore, App.prog.root], 16, Color(0.8, 0.85, 0.7)))
	var smith := App.prog.skill_lv("smith")
	if tab(ui) == "forge":
		_forge_body(ui, smith)
	else:
		_analyze_body(ui, smith)


static func _tabs(ui: CanvasLayer) -> void:
	var wrap := HBoxContainer.new()
	wrap.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	wrap.add_theme_constant_override("separation", 10)
	var left := HBoxContainer.new()
	left.mouse_filter = Control.MOUSE_FILTER_IGNORE
	left.custom_minimum_size = Vector2(36, 28)
	left.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	var right := HBoxContainer.new()
	right.mouse_filter = Control.MOUSE_FILTER_IGNORE
	right.custom_minimum_size = Vector2(36, 28)
	right.size_flags_horizontal = Control.SIZE_SHRINK_END
	var sc := ScrollContainer.new()
	sc.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sc.custom_minimum_size = Vector2(200, 52)
	sc.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	sc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_SHOW_NEVER
	sc.follow_focus = true
	var row := HBoxContainer.new()
	row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_theme_constant_override("separation", 10)
	var on_a := tab(ui) == "analyze"
	var a := ThemeS.btn("Analyze", func(): set_tab(ui, "analyze"), true)
	var f := ThemeS.btn("Forge", func(): set_tab(ui, "forge"), true)
	a.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	f.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	a.custom_minimum_size = Vector2(160, 44)
	f.custom_minimum_size = Vector2(160, 44)
	if on_a:
		a.disabled = true
		a.focus_mode = Control.FOCUS_NONE
	else:
		f.disabled = true
		f.focus_mode = Control.FOCUS_NONE
	row.add_child(a)
	row.add_child(f)
	sc.add_child(row)
	wrap.add_child(left)
	wrap.add_child(sc)
	wrap.add_child(right)
	PromptView.fill(left, [{"action": "tab_left"}], 16, Color(0.72, 0.66, 0.52))
	PromptView.fill(right, [{"action": "tab_right"}], 16, Color(0.72, 0.66, 0.52))
	ui.box.add_child(wrap)


static func set_tab(ui: CanvasLayer, t: String) -> void:
	ui.anvil_tab = t
	ui.anvil_item = {}
	ui.pending = false
	ui.call_deferred("_rebuild_anvil")
	ui.call_deferred("_show")


static func _analyze_body(ui: CanvasLayer, smith: int) -> void:
	ui.status.text = "Smithing %d. Analyze DESTROYS the piece. Remains wait on Forge. Starters stay off this list." % smith
	var n := App.prog.analyzed.size()
	ui.box.add_child(ThemeS.lab("Remains waiting to forge: %d" % n, 18, Color(0.88, 0.82, 0.7)))
	if n > 0:
		var names: PackedStringArray = PackedStringArray()
		for raw: Variant in App.prog.analyzed:
			if raw is Dictionary:
				names.append(str(raw.get("name", "?")))
		ui.box.add_child(ThemeS.lab(", ".join(names), 16, Color(0.75, 0.85, 0.7)))


static func _forge_body(ui: CanvasLayer, smith: int) -> void:
	if App.prog.analyzed.is_empty() and _no_holds():
		ui.status.text = "Smithing %d. Nothing to forge. Analyze a piece first." % smith
		return
	if ui.anvil_item.is_empty():
		ui.status.text = "Smithing %d. Pick a slot — analyzed remains or a hold." % smith
		_hold_lines(ui)
		return
	var it: Dictionary = ui.anvil_item
	var slot := str(it.get("slot", ""))
	var h: Array = App.prog.holds.get(slot, [])
	var first := str(ui.get("anvil_src")) != "hold" and not bool(it.get("hold", false))
	var cost: Dictionary = App.prog.forge_cost(first)
	var wait := App.prog.forge_duration()
	ui.box.add_child(ThemeS.lab("Ready to forge — %s" % str(it.get("name", "?")), 22, Color(0.95, 0.86, 0.55)))
	ui.box.add_child(ThemeS.lab("Slot %s   %s   +%d dmg   +%d def   +%d HP" % [slot, str(it.get("rarity", "white")), int(it.get("dmg", 0)), int(it.get("def", 0)), int(it.get("hp", 0))], 16, Color(0.88, 0.82, 0.7)))
	ui.box.add_child(ThemeS.lab("Smithing %d. Holds %d/3. Wait %.1fs." % [smith, h.size(), wait], 16, Color(0.8, 0.85, 0.7)))
	if first:
		ui.status.text = "First forge from remains: %dg  %d ore  %d root." % [cost.gold, cost.ore, cost.root]
		ui.focus_btn = ThemeS.btn("Forge remains  (confirm)", func(): ui._confirm(func(): _anvil().start_forge(ui), "forge"))
	else:
		ui.status.text = "Re-forge hold: %dg  %d ore  %d root." % [cost.gold, cost.ore, cost.root]
		ui.focus_btn = ThemeS.btn("Re-forge  (confirm)", func(): ui._confirm(func(): _anvil().start_forge(ui), "forge"))
	ui.box.add_child(ui.focus_btn)
	_hold_lines(ui)


static func _no_holds() -> bool:
	for s: String in ["weapon", "tool", "head", "body", "legs"]:
		if not App.prog.holds.get(s, []).is_empty():
			return false
	return true


static func _hold_lines(ui: CanvasLayer) -> void:
	for s: String in ["weapon", "tool", "head", "body", "legs"]:
		var h: Array = App.prog.holds.get(s, [])
		if h.is_empty():
			continue
		var names: PackedStringArray = PackedStringArray()
		for x: Variant in h:
			if x is Dictionary:
				names.append(str(x.get("name", "?")))
		ui.box.add_child(ThemeS.lab("Holds %s: %s" % [s, ", ".join(names)], 16, Color(0.75, 0.85, 0.7)))
