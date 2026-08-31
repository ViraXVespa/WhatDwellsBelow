extends Object

const ThemeS := preload("res://scripts/ui/theme.gd")


static func rebuild_loadout(ui) -> void:
	ui._clear()
	ui.box.add_child(ThemeS.lab("Floor Crystal — Loadout", 32, Color(0.6, 0.9, 1.0)))
	ui.box.add_child(ThemeS.lab("Holds, weapon, tool lock, starting floor. Confirm enter twice. Only floors you have reached. Stairs never go back.", 18, Color(0.82, 0.76, 0.66)))
	ui.status = ThemeS.lab("Weapon %s   Tool %s   Floor %d / deepest %d" % [ui.loadout_wpn, ui.loadout_tool, ui.loadout_floor, App.prog.deepest], 22, Color(0.95, 0.8, 0.45))
	ui.box.add_child(ui.status)
	ui.focus_btn = ThemeS.btn("Character: %s  (switch, confirm)" % App.character_type, func(): ui._confirm(func(): toggle_char(ui), "char"))
	ui.box.add_child(ui.focus_btn)
	ui.box.add_child(ThemeS.btn("Weapon: Great Axe", func(): set_wpn(ui, "great_axe")))
	ui.box.add_child(ThemeS.btn("Weapon: Lightning Staff", func(): set_wpn(ui, "staff")))
	ui.box.add_child(ThemeS.btn("Weapon: Longbow", func(): set_wpn(ui, "longbow")))
	ui.box.add_child(ThemeS.btn("Tool: Pickaxe  (mining)", func(): set_tool(ui, "pickaxe")))
	ui.box.add_child(ThemeS.btn("Tool: Hatchet  (woodcutting)", func(): set_tool(ui, "hatchet")))
	ui.box.add_child(ThemeS.btn("Floor +", func(): floor_step(ui, 1)))
	ui.box.add_child(ThemeS.btn("Floor −", func(): floor_step(ui, -1)))
	for s in App.prog.SLOTS:
		var h: Array = App.prog.holds[s]
		if h.size() > 0:
			for i in h.size():
				var nm := str(h[i].name)
				ui.box.add_child(ThemeS.btn("Use hold %s: %s" % [s, nm], func(): use_hold(ui, s, i)))
	ui.box.add_child(ThemeS.btn("Enter dungeon  (confirm)", func(): ui._confirm(func(): enter(ui), "enter")))
	ui.box.add_child(ThemeS.btn("Back  (B)", func(): ui.close_ui()))


static func toggle_char(ui) -> void:
	App.set_character("female" if App.character_type == "male" else "male")
	App.save_now()
	ui._rebuild_loadout()
	ui._show()


static func set_wpn(ui, w: String) -> void:
	ui.loadout_wpn = w
	App.weapon = w
	App.prog.pick_weapon = w
	App.prog.hold_pick["weapon"] = matching_hold("weapon", "weapon", w)
	ui.status.text = "Weapon %s   Tool %s   Floor %d" % [ui.loadout_wpn, ui.loadout_tool, ui.loadout_floor]


static func set_tool(ui, t: String) -> void:
	ui.loadout_tool = t
	App.prog.tool_type = t
	App.prog.hold_pick["tool"] = matching_hold("tool", "tool", t)
	ui.status.text = "Weapon %s   Tool %s   Floor %d" % [ui.loadout_wpn, ui.loadout_tool, ui.loadout_floor]


static func matching_hold(slot: String, key: String, want: String) -> int:
	var h: Array = App.prog.holds[slot]
	for i in h.size():
		if str(h[i].get(key, "")) == want:
			return i
	return -1


static func floor_step(ui, d: int) -> void:
	ui.loadout_floor = clampi(ui.loadout_floor + d, 1, App.prog.deepest)
	ui.status.text = "Weapon %s   Tool %s   Floor %d" % [ui.loadout_wpn, ui.loadout_tool, ui.loadout_floor]


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
	App.prog.tool_type = ui.loadout_tool
	App.prog.pick_weapon = ui.loadout_wpn
	App.prog.start_floor = ui.loadout_floor
	App.weapon = ui.loadout_wpn
	ui.close_ui()
	App.enter_dungeon()


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
	if ui.focus_btn == null:
		ui.focus_btn = ThemeS.btn("Close  (B)", func(): ui.close_ui())
	ui.box.add_child(ThemeS.btn("Close  (B)", func(): ui.close_ui()))


static func rebuild_controls(ui) -> void:
	ui._clear()
	ui.box.add_child(ThemeS.lab("Controls Billboard", 32, Color(0.95, 0.82, 0.5)))
	ui.box.add_child(ThemeS.lab("What the guild painted up. Bindings follow your System tab.", 18, Color(0.82, 0.76, 0.66)))
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
		ui.box.add_child(ThemeS.lab("%s  —  %s" % [lab, ThemeS.bind_text(name)], 18, Color(0.9, 0.86, 0.74)))
	ui.focus_btn = ThemeS.btn("Leave  (B)", func(): ui.close_ui())
	ui.box.add_child(ui.focus_btn)
