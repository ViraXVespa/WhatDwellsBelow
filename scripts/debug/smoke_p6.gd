extends Object

const Cat := preload("res://scripts/data/catalog.gd")


static func tree(host: Node) -> SceneTree:
	return host.get_tree()


static func quit_in(host: Node, sec: float) -> void:
	tree(host).create_timer(sec).timeout.connect(func(): tree(host).quit())


static func p6(host: Node) -> void:
	var player: Variant = host.get("player")
	var ui: Variant = host.get("ui")
	printerr("P6: res=" + ProjectSettings.globalize_path("res://"))
	printerr("P6: sets=" + str(App.prog.SETS.size()) + " " + ", ".join(App.prog.SETS))
	var sizes: PackedStringArray = PackedStringArray()
	for s: String in App.prog.SETS:
		sizes.append("%s:%d" % [s, Cat.set_size(s)])
	printerr("P6: set_sizes=" + ", ".join(sizes))
	printerr("P6: eight_ok=" + str(App.prog.SETS.size() == 8))
	App.prog.add_item(App.prog.make_artifact("cinder_ember"))
	App.prog.add_item(App.prog.make_artifact("cinder_coil"))
	var c: Dictionary = App.prog.set_counts()
	var st: Dictionary = App.prog.set_stats()
	printerr("P6: cinder=" + str(c.get("cinder", 0)) + " bonus_dmg=" + str(st.dmg))
	printerr("P6: set_bonus_ok=" + str(int(c.get("cinder", 0)) >= 2 and float(st.dmg) > 0.0))
	printerr("P6: bonus_text=" + App.prog.set_bonus_text("cinder").replace("\n", " / "))
	App.prog.add_item(App.prog.make_food("ration", 3))
	App.prog.add_item(App.prog.make_food("bread", 2))
	App.prog.add_item(App.prog.make_potion(2))
	App.prog.slots["potion"] = App.prog.make_potion(2)
	App.prog.slots["food"] = App.prog.make_food("ration", 3)
	player.set("hp", 40.0)
	var p1: String = App.prog.use_potion()
	var hp1: float = float(player.get("hp"))
	printerr("P6: potion=" + p1 + " hp=" + str(hp1) + " instant_ok=" + str(hp1 > 40.0))
	player.set("hp", 40.0)
	var f1: String = App.prog.use_food()
	var f2: String = App.prog.use_food()
	printerr("P6: food1=" + f1 + " food_same=" + f2)
	printerr("P6: food_hot=" + str(App.prog.food_t > 0.0) + " same_blocked=" + str(f2.find("Already") >= 0))
	App.prog.slots["food"] = App.prog.make_food("bread", 2)
	var f3: String = App.prog.use_food()
	printerr("P6: food_swap=" + f3 + " id=" + App.prog.food_id + " swap_ok=" + str(App.prog.food_id == "bread"))
	App.gold = 80
	App.ore = 12
	App.prog.root = 6
	App.prog.add_item(App.prog.make_weapon("great_axe", "white"))
	var axe: Dictionary = App.prog.bag[App.prog.bag.size() - 1]
	var forge: String = App.prog.forge_item(axe)
	printerr("P6: forge=" + forge + " holds=" + str((App.prog.holds["weapon"] as Array).size()) + " forge_ok=" + str((App.prog.holds["weapon"] as Array).size() > 0))
	App.gold = 10
	App.ore = 8
	App.wood = 5
	App.prog.add_item(App.prog.make_armor("head", "white"))
	var ex: String = App.prog.extract_all("patty")
	printerr("P6: extract=" + ex + " extracted=" + str(App.extracted) + " bank_o=" + str(App.bank_ore))
	App.prog.quest_active = {}
	App.prog.roll_quests(false)
	var acc: String = App.prog.accept_quest(0)
	printerr("P6: quest=" + acc + " active=" + str(App.prog.quest_active.get("title", "")))
	App.prog.quest_active = {}
	App.quest_named_type = ""
	var named_q: bool = false
	for i: int in App.prog.quests_offered.size():
		if str(App.prog.quests_offered[i].kind) == "named":
			App.prog.accept_quest(i)
			named_q = App.quest_named_type != ""
			break
	printerr("P6: named_lock=" + App.quest_named_type + " named_ok=" + str(named_q))
	App.prog.tool_type = "hatchet"
	printerr("P6: tool_lock=" + App.prog.tool_type)
	ui.open_loadout()
	printerr("P6: loadout_open=" + str(ui.open) + " focus=" + str(ui.focus_btn != null))
	ui.close_ui()
	ui.open_inventory()
	printerr("P6: inv_open=" + str(ui.open) + " focus=" + str(ui.focus_btn != null))
	ui.close_ui()
	ui.open_anvil()
	printerr("P6: anvil_open=" + str(ui.open) + " focus=" + str(ui.focus_btn != null))
	ui.close_ui()
	ui.open_quest()
	printerr("P6: quest_open=" + str(ui.open) + " focus=" + str(ui.focus_btn != null))
	ui.close_ui()
	printerr("P6: food_hot_left=" + str(App.prog.food_left))
	printerr("P6: loop_ok=" + str(App.extracted and (App.prog.holds["weapon"] as Array).size() > 0 and App.prog.SETS.size() == 8))
	quit_in(host, 0.4)
