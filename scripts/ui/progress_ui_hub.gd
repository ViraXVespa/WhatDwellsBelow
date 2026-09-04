extends Object

const ThemeS := preload("res://scripts/ui/theme.gd")
const Board := preload("res://scripts/ui/gear_board.gd")
const GearAct := preload("res://scripts/ui/gear_board_act.gd")
const PromptView := preload("res://scripts/ui/prompt_view.gd")


static func rebuild_loadout(ui) -> void:
	ui._clear()
	ui.gear_mode = "loadout"
	Board.build(ui, "loadout")


static func rebuild_anvil(ui) -> void:
	ui._clear()
	ui.gear_mode = "anvil"
	Board.build(ui, "anvil")


static func toggle_char(ui) -> void:
	GearAct.toggle_char(ui)


static func set_wpn(ui, w: String) -> void:
	ui.loadout_wpn = w
	App.weapon = w
	App.prog.pick_weapon = w
	Board.refresh(ui)


static func set_tool(ui, t: String) -> void:
	ui.loadout_tool = t
	App.prog.tool_type = t
	Board.refresh(ui)


static func matching_hold(slot: String, key: String, want: String) -> int:
	var h: Array = App.prog.holds[slot]
	for i in h.size():
		if str(h[i].get(key, "")) == want:
			return i
	return -1


static func floor_step(ui, d: int) -> void:
	GearAct.floor_step(ui, d)


static func use_hold(ui, slot: String, i: int) -> void:
	var h: Array = App.prog.holds[slot]
	if i < 0 or i >= h.size():
		return
	App.prog.hold_pick[slot] = i
	App.prog.slots[slot] = h[i].duplicate(true)
	if slot == "weapon":
		ui.loadout_wpn = str(h[i].get("weapon", ui.loadout_wpn))
		App.prog.pick_weapon = ui.loadout_wpn
	if slot == "tool":
		ui.loadout_tool = str(h[i].get("tool", ui.loadout_tool))
		App.prog.tool_type = ui.loadout_tool
	ui._st("Hold ready: " + str(h[i].name))


static func enter(ui) -> void:
	GearAct.enter(ui)


static func rebuild_quest(ui) -> void:
	ui._clear()
	ui.box.add_child(ThemeS.lab("Guild Tasks", 32, Color(0.95, 0.82, 0.5)))
	ui.box.add_child(ThemeS.lab("Three choices. One active. Named vanquish locks that named foe.", 18, Color(0.82, 0.76, 0.66)))
	ui.status = ThemeS.lab("", 20, Color(0.95, 0.8, 0.45))
	ui.box.add_child(ui.status)
	if not App.prog.quest_active.is_empty():
		var q: Dictionary = App.prog.quest_active
		ui.box.add_child(ThemeS.lab("Active: %s  (%d/%d)" % [q.title, int(q.get("have", 0)), int(q.get("need", 1))], 22, Color(0.75, 0.95, 0.7)))
		ui.box.add_child(ThemeS.btn("Abandon active task  (confirm)", func(): ui._confirm(func(): ui._st(App.prog.abandon_quest()); ui._rebuild_quest(); ui._show(), "abandon")))
	var i := 0
	for q in App.prog.quests_offered:
		var idx := i
		if ui.focus_btn == null:
			ui.focus_btn = ThemeS.btn("%s\nReward: %s" % [q.title, q.reward], func(): ui._st(App.prog.accept_quest(idx)); ui._rebuild_quest(); ui._show())
			ui.box.add_child(ui.focus_btn)
		else:
			ui.box.add_child(ThemeS.btn("%s\nReward: %s" % [q.title, q.reward], func(): ui._st(App.prog.accept_quest(idx)); ui._rebuild_quest(); ui._show()))
		i += 1
	var close := ThemeS.btn("Close", func(): ui.close_ui())
	if ui.focus_btn == null:
		ui.focus_btn = close
	ui.box.add_child(close)


static func rebuild_controls(ui) -> void:
	ui._clear()
	ui.box.add_child(ThemeS.lab("Controls Billboard", 32, Color(0.95, 0.82, 0.5)))
	ui.box.add_child(ThemeS.lab("What the guild painted up. Bindings follow your System tab.", 18, Color(0.82, 0.76, 0.66)))
	var acts := [
		["move_left", "Move left"],
		["move_right", "Move right"],
		["move_up", "Move up"],
		["move_down", "Move down"],
		["attack", "Attack"],
		["special", "Special"],
		["dash", "Dash"],
		["interact", "Interact"],
		["pause", "Pause"],
		["potion", "Potion"],
		["food", "Food"],
		["map_view", "Map"],
		["target_lock", "Target-lock"],
	]
	for pair in acts:
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 10)
		PromptView.fill(row, [{"action": str(pair[0]), "verb": str(pair[1])}], 18, Color(0.9, 0.86, 0.74))
		ui.box.add_child(row)
	ui.focus_btn = ThemeS.btn("Leave", func(): ui.close_ui())
	ui.box.add_child(ui.focus_btn)
