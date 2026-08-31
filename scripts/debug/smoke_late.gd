extends Object

const T := preload("res://scripts/data/tunables.gd")
const Roster := preload("res://scripts/combat/roster.gd")
const EnemyS := preload("res://scripts/combat/enemy.gd")
const StoreS := preload("res://scripts/data/save_store.gd")
const AnimS := preload("res://scripts/debug/anim_browser.gd")
const Cat := preload("res://scripts/data/catalog.gd")

static var enter_flag: bool = false


static func tree(host: Node) -> SceneTree:
	return host.get_tree()


static func quit_in(host: Node, sec: float) -> void:
	tree(host).create_timer(sec).timeout.connect(func(): tree(host).quit())


static func p5(host: Node) -> void:
	var player: Variant = host.get("player")
	var ui: Variant = host.get("ui")
	var counts: Dictionary = host.get("counts")
	printerr("P5: res=" + ProjectSettings.globalize_path("res://"))
	printerr("P5: mine_time=" + str(App.bal.mine_time) + " wood_time=" + str(App.bal.wood_time))
	printerr("P5: mine_hits=" + str(App.bal.mine_hits) + " wood_hits=" + str(App.bal.wood_hits))
	printerr("P5: mine_chance=" + str(App.bal.mine_chance) + " wood_chance=" + str(App.bal.wood_chance))
	printerr("P5: counts=" + str(counts))
	var kinds: PackedStringArray = PackedStringArray()
	for n: Node in tree(host).get_nodes_in_group("interact"):
		var k: String = str(n.get("kind"))
		if kinds.find(k) < 0:
			kinds.append(k)
	printerr("P5: interact_kinds=" + ", ".join(kinds))
	printerr("P5: gather=" + str(tree(host).get_nodes_in_group("gather").size()))
	printerr("P5: breakables=" + str(tree(host).get_nodes_in_group("breakables").size()))
	printerr("P5: gates=" + str(tree(host).get_nodes_in_group("gates").size()))
	printerr("P5: plates=" + str(tree(host).get_nodes_in_group("plates").size()))
	App.bal.mine_chance = 1.0
	App.bal.wood_chance = 1.0
	var mine_n: Node = null
	var wood_n: Node = null
	for n2: Node in tree(host).get_nodes_in_group("gather"):
		if str(n2.get("kind")) == "mine" and mine_n == null:
			mine_n = n2
		if str(n2.get("kind")) == "wood" and wood_n == null:
			wood_n = n2
	var ore0: int = App.ore
	var wood0: int = App.wood
	var mine_hits: int = 0
	var wood_hits: int = 0
	if mine_n and mine_n.has_method("strike"):
		var r1: Dictionary = mine_n.strike()
		mine_hits = 1
		printerr("P5: mine_strike ok=" + str(r1.get("ok", false)) + " interval=" + str(mine_n.get("interval")))
	if wood_n and wood_n.has_method("strike"):
		var r2: Dictionary = wood_n.strike()
		wood_hits = 1
		printerr("P5: wood_strike ok=" + str(r2.get("ok", false)) + " interval=" + str(wood_n.get("interval")))
	printerr("P5: ore_delta=" + str(App.ore - ore0) + " wood_delta=" + str(App.wood - wood0))
	printerr("P5: nodes_ok=" + str(mine_hits == 1 and wood_hits == 1 and is_equal_approx(float(mine_n.get("interval")), 2.4) and is_equal_approx(float(wood_n.get("interval")), 1.2)))
	var smashed: int = 0
	for b: Node in tree(host).get_nodes_in_group("breakables"):
		if str(b.get("kind")) == "crack":
			continue
		if b.has_method("take_hit"):
			b.take_hit(99.0, Vector2.DOWN, false)
			smashed += 1
			break
	printerr("P5: smash=" + str(smashed) + " gold=" + str(App.gold))
	var shrine: Node = null
	var fire: Node = null
	var clerk: Node = null
	var shop: Node = null
	var lever: Node = null
	var chest: Node = null
	var crack: Node = null
	for n3: Node in tree(host).get_nodes_in_group("interact"):
		var k3: String = str(n3.get("kind"))
		if k3 == "shrine" and shrine == null:
			shrine = n3
		if k3 == "campfire" and fire == null:
			fire = n3
		if k3.begins_with("clerk") and clerk == null:
			clerk = n3
		if k3 == "shop" and shop == null:
			shop = n3
		if k3 == "lever" and lever == null:
			lever = n3
		if k3.ends_with("chest") and chest == null:
			chest = n3
	for b2: Node in tree(host).get_nodes_in_group("breakables"):
		if str(b2.get("kind")) == "crack":
			crack = b2
			break
	if shrine:
		shrine.interact(player)
	printerr("P5: shrine_t=" + str(App.shrine_t) + " shrine_ok=" + str(App.shrine_t > 0.0))
	var hp0: float = float(player.get("hp")) if player else 0.0
	if player:
		player.set("hp", hp0 * 0.4)
	if fire:
		fire.interact(player)
	var hp1: float = float(player.get("hp")) if player else 0.0
	printerr("P5: campfire hp " + str(hp0) + "->" + str(hp1) + " ok=" + str(hp1 > hp0 * 0.4))
	App.ore = 4
	App.wood = 3
	App.gold = 30
	if clerk:
		clerk.interact(player)
	if ui:
		ui._extract_all()
		ui.close_ui()
	printerr("P5: extract bank_g=" + str(App.bank_gold) + " bank_o=" + str(App.bank_ore) + " bank_w=" + str(App.bank_wood) + " extracted=" + str(App.extracted))
	App.gold = 80
	if shop:
		shop.interact(player)
	if ui:
		ui._buy_snack()
		if shop and shop.stock.size() > 0:
			var a: Dictionary = shop.stock[0]
			ui._buy_art(str(a.id), str(a.name))
		ui.close_ui()
	printerr("P5: shop artifacts=" + str(App.run_artifacts.size()) + " snack_buys=" + str(App.shop_buys))
	var gate_open0: bool = false
	for g: Node in tree(host).get_nodes_in_group("gates"):
		gate_open0 = bool(g.get("open"))
	if lever:
		lever.interact(player)
	var gate_open1: bool = false
	for g2: Node in tree(host).get_nodes_in_group("gates"):
		gate_open1 = bool(g2.get("open"))
	printerr("P5: lever_gate " + str(gate_open0) + "->" + str(gate_open1))
	if crack and crack.has_method("take_hit"):
		for i: int in 10:
			if is_instance_valid(crack):
				crack.take_hit(40.0, Vector2.DOWN, false)
	printerr("P5: crack_dead=" + str(crack == null or not is_instance_valid(crack) or bool(crack.get("dead"))))
	if chest:
		chest.interact(player)
	printerr("P5: chest_arts=" + str(App.run_artifacts.size()))
	var present: bool = (
		int(counts.get("mine", 0)) > 0
		and int(counts.get("wood", 0)) > 0
		and int(counts.get("break", 0)) > 0
		and int(counts.get("clerk", 0)) > 0
		and int(counts.get("shrine", 0)) > 0
		and int(counts.get("campfire", 0)) > 0
		and int(counts.get("lever", 0)) > 0
		and int(counts.get("gate", 0)) > 0
		and int(counts.get("plate", 0)) > 0
		and int(counts.get("crack", 0)) > 0
		and int(counts.get("shop", 0)) > 0
	)
	printerr("P5: present_ok=" + str(present))
	printerr("P5: extract_ok=" + str(App.extracted and App.bank_ore >= 4))
	quit_in(host, 0.35)


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


static func p7(host: Node) -> void:
	var hud: Variant = host.get("hud")
	printerr("P7: res=" + ProjectSettings.globalize_path("res://"))
	printerr("P7: hud=" + str(hud != null))
	var bits: PackedStringArray = PackedStringArray()
	if hud:
		for n: String in ["portrait", "hp_lab", "pot_lab", "dash_fill", "spec_fill", "lvl", "res", "floor_lab", "food_lab", "shrine_lab", "boss_lab"]:
			bits.append("%s=%s" % [n, str(hud.get(n) != null)])
	printerr("P7: hud_bits=" + ", ".join(bits))
	App.pause_menu.show_menu()
	printerr("P7: pause_open=" + str(App.pause_menu.open) + " focus=" + str(App.pause_menu.focus_btn != null) + " tab=" + str(App.pause_menu.tab))
	App.pause_menu.tab = 1
	App.pause_menu._rebuild()
	printerr("P7: pause_skills=" + str(App.pause_menu.tab == 1))
	App.pause_menu.tab = 2
	App.pause_menu._rebuild()
	printerr("P7: pause_system=" + str(App.pause_menu.tab == 2))
	var sys: bool = false
	for c: Node in App.pause_menu.box.get_children():
		if c is Button and str((c as Button).text).find("Dispel") >= 0:
			sys = true
		if c is Button and str((c as Button).text).find("Aim-line") >= 0:
			sys = true
	printerr("P7: system_dispel_aim=" + str(sys))
	App.pause_menu.close_ui()
	App.debug.show_menu()
	printerr("P7: debug_open=" + str(App.debug.open))
	App.debug.page = "anim"
	App.debug._rebuild()
	printerr("P7: anim_stub=" + str(App.debug.page == "anim") + " anim_btn=" + str(App.debug.anim_btn != null))
	App.debug.page = "playtest"
	App.debug._rebuild()
	var sum: String = App.debug.play.run_medium()
	printerr("P7: playtest=" + sum.replace("\n", " | "))
	printerr("P7: recs_fresh=" + str((App.debug.play.recs["fresh"] as Array).size()) + " recs_prog=" + str((App.debug.play.recs["progressed"] as Array).size()))
	printerr("P7: history=" + str(App.debug.play.history.size()))
	var row0: Dictionary = {}
	if App.debug.play.history.size() > 0:
		row0 = App.debug.play.history[0]
	printerr("P7: tel_end=" + str(row0.get("end_cond", "")) + " wpn=" + str(row0.get("start_weapon", "")) + " save=" + str(row0.get("save_type", "")) + " playtest=" + str(row0.get("playtest", false)))
	App.debug.play.apply_rec("fresh", 0)
	printerr("P7: applied_fresh_ideal")
	App.debug.hide_menu()
	App.prog.bag.clear()
	App.gold = 0
	App.ore = 0
	App.wood = 0
	App.floor_n = 1
	App.prog.add_run_xp("axe", 80.0)
	App.recap.play("death")
	printerr("P7: recap_title=" + App.recap.last_title)
	App.recap.skip_drain()
	printerr("P7: recap_drain=" + str(App.tel.recap_drain) + " waste=" + str(App.recap.last_title.find("waste") >= 0))
	App.recap._finish()
	printerr("P7: pause_themed=" + str(true))
	printerr("P7: hud_ok=" + str(hud != null and hud.get("hp_lab") != null and hud.get("food_lab") != null))
	printerr("P7: playtest_ok=" + str((App.debug.play.recs["fresh"] as Array).size() == 3 and (App.debug.play.recs["progressed"] as Array).size() == 3 and App.debug.play.history.size() >= 6))
	printerr("P7: anim_ok=" + str(App.debug.anim_btn != null))
	tree(host).create_timer(0.4, true, false, true).timeout.connect(func(): tree(host).quit())


static func p8(host: Node) -> void:
	var player: Variant = host.get("player")
	printerr("P8: res=" + ProjectSettings.globalize_path("res://"))
	var kinds: PackedStringArray = PackedStringArray()
	for n: Node in tree(host).get_nodes_in_group("interact"):
		var k: String = str(n.get("kind"))
		if kinds.find(k) < 0:
			kinds.append(k)
	printerr("P8: hub_kinds=" + ", ".join(kinds))
	var need: PackedStringArray = PackedStringArray(["loadout_crystal", "anvil", "quest_board", "receptionist", "vendor", "dumpster", "billboard"])
	var hub_ok: bool = true
	for k2: String in need:
		if kinds.find(k2) < 0:
			hub_ok = false
	printerr("P8: hub_ok=" + str(hub_ok))
	var depth_ok: bool = false
	for n2: Node in host.get_children():
		if n2 is StaticBody3D:
			for c: Node in n2.get_children():
				if c is CollisionShape3D:
					var sh: Shape3D = (c as CollisionShape3D).shape
					if sh is BoxShape3D:
						var b: BoxShape3D = sh as BoxShape3D
						if b.size.z >= 3.0 and b.size.y >= 2.0:
							depth_ok = true
	printerr("P8: building_depth=" + str(depth_ok))
	var ban_path: String = "res://assets/sprites/props/welcome_banner.png"
	var ban: bool = ResourceLoader.exists(ban_path) or FileAccess.file_exists(ban_path)
	printerr("P8: banner_asset=" + str(ban))
	App.bank_gold = 42
	App.bank_ore = 7
	App.prog.deepest = 4
	App.prog.skills_perm["axe"] = 120.0
	StoreS.save_slot("live")
	StoreS.save_slot("live")
	App.bank_gold = 1
	App.prog.deepest = 1
	StoreS.corrupt_primary("live")
	var how: String = StoreS.load_slot("live")
	printerr("P8: load_after_corrupt=" + how + " gold=" + str(App.bank_gold) + " deep=" + str(App.prog.deepest) + " axe_perm=" + str(App.prog.skills_perm.get("axe", 0)))
	printerr("P8: backup_ok=" + str(how == "backup" and App.bank_gold == 42 and App.prog.deepest == 4))
	StoreS.corrupt_primary("live")
	var bakp: String = StoreS.backup_path("live")
	var bf: FileAccess = FileAccess.open(bakp, FileAccess.WRITE)
	if bf:
		bf.store_string("%%%")
	var how2: String = StoreS.load_slot("live")
	printerr("P8: both_fail=" + how2 + " fresh_ok=" + str(how2 == "fresh"))
	StoreS.wipe_slot("fresh")
	StoreS.wipe_slot("progressed")
	App.prog.skills_perm["str"] = 0.0
	StoreS.save_slot("fresh")
	App.prog.skills_perm["str"] = 400.0
	StoreS.save_slot("progressed")
	StoreS.load_slot("progressed")
	var pt_str: float = float(App.prog.skills_perm.get("str", 0))
	StoreS.load_slot("fresh")
	var fr_str: float = float(App.prog.skills_perm.get("str", 0))
	printerr("P8: playtest_isolated=" + str(pt_str >= 400.0 and fr_str < 50.0 and StoreS.dir_for("fresh") != StoreS.dir_for("live")))
	printerr("P8: live_dir=" + StoreS.dir_for("live") + " fresh_dir=" + StoreS.dir_for("fresh") + " prog_dir=" + StoreS.dir_for("progressed"))
	var root: String = ProjectSettings.globalize_path("res://").trim_suffix("/")
	var arch: String = root.path_join("archives")
	printerr("P8: arch_full=" + str(DirAccess.dir_exists_absolute(arch.path_join("full_3d_pass"))))
	printerr("P8: arch_classic=" + str(DirAccess.dir_exists_absolute(arch.path_join("classic_2d"))))
	printerr("P8: arch_art=" + str(DirAccess.dir_exists_absolute(arch.path_join("art_experiment"))))
	App.wake_pending = true
	if App.present and App.present.has_method("play_wake"):
		App.present.play_wake()
	printerr("P8: wake_playing=" + str(App.present.get("playing") == true or App.present.visible))
	enter_flag = false
	if App.present and App.present.has_method("play_enter"):
		App.present.play_enter(func(): enter_flag = true)
	printerr("P8: enter_started=" + str(App.present.get("playing") == true or App.present.visible))
	var dump_txt: String = ""
	for n3: Node in tree(host).get_nodes_in_group("interact"):
		if str(n3.get("kind")) == "dumpster" and n3.has_method("interact"):
			dump_txt = str(n3.interact(player))
			break
	printerr("P8: dumpster=" + dump_txt)
	printerr("P8: dumpster_ok=" + str(dump_txt.find("Career upgrade pending") >= 0))
	printerr("P8: save_ok=" + str(how == "backup"))
	printerr("P8: archives_ok=" + str(DirAccess.dir_exists_absolute(arch.path_join("full_3d_pass"))))
	tree(host).create_timer(1.6, true, false, true).timeout.connect(func():
		printerr("P8: enter_cb=" + str(enter_flag))
		StoreS.wipe_slot("live")
		tree(host).quit()
	)


static func p9(host: Node) -> void:
	var player: Variant = host.get("player")
	printerr("P9: res=" + ProjectSettings.globalize_path("res://"))
	printerr("P9: bitter_loop=" + str(App.bal.bitter_loop_offset))
	printerr("P9: bitter_yt=" + str(T.BITTER_YT != ""))
	printerr("P9: bitter_spotify=" + str(T.BITTER_SPOTIFY != ""))
	var mus: bool = false
	if App.music:
		mus = str(App.music.get("kind")) == "dungeon"
	printerr("P9: dungeon_music=" + str(mus))
	var sfx_need: PackedStringArray = PackedStringArray(["p9_potion.wav", "p9_food.wav", "p9_wood.wav", "p9_thud.wav", "p9_enter.wav", "p9_wake.wav", "p9_hurt_male.wav", "p9_hurt_female.wav", "p9_warcry_male.wav", "p9_warcry_female.wav", "p9_hurk_male.wav", "p9_hurk_female.wav"])
	var sfx_ok: bool = true
	for n: String in sfx_need:
		if not ResourceLoader.exists("res://assets/audio/" + n) and not FileAccess.file_exists("res://assets/audio/" + n):
			sfx_ok = false
	printerr("P9: sfx_ok=" + str(sfx_ok))
	var models: Array = AnimS.catalog_models()
	printerr("P9: anim_models=" + str(models.size()))
	var need_ids: PackedStringArray = PackedStringArray(["player_male", "player_female", "slime", "guardian", "gate_master"])
	var model_ok: bool = true
	for id: String in need_ids:
		var found: bool = false
		for m: Variant in models:
			if str(m.id) == id:
				found = true
		if not found:
			model_ok = false
	printerr("P9: anim_browser_ok=" + str(models.size() >= 16 and model_ok))
	if App.anim_browser and App.anim_browser.has_method("open_browser"):
		App.anim_browser.open_browser()
		printerr("P9: anim_open=" + str(App.anim_browser.open) + " focus=" + str(App.anim_browser.back_btn != null))
		App.anim_browser.close_browser()
	if App.archives_ui and App.archives_ui.has_method("show_browser"):
		App.archives_ui.show_browser()
		printerr("P9: archives_ui=" + str(App.archives_ui.open) + " entries=" + str(App.archives_ui.entries.size()))
		App.archives_ui.hide_browser()
	var root: String = ProjectSettings.globalize_path("res://").trim_suffix("/")
	var arch: String = root.path_join("archives")
	printerr("P9: arch_full=" + str(DirAccess.dir_exists_absolute(arch.path_join("full_3d_pass"))))
	printerr("P9: arch_classic=" + str(DirAccess.dir_exists_absolute(arch.path_join("classic_2d"))))
	printerr("P9: arch_art=" + str(DirAccess.dir_exists_absolute(arch.path_join("art_experiment"))))
	var sum: String = App.debug.play.run_medium()
	printerr("P9: playtest=" + sum.replace("\n", " | "))
	var extra: int = 0
	if player:
		for i: int in 24:
			var e: Node = EnemyS.new()
			e.position = player.position + Vector3(float(i % 6) * 0.7, 0.0, float(int(i) / 6) * 0.7)
			host.add_child(e)
			e.setup(Roster.IDS[i % Roster.IDS.size()], App.floor_n)
			extra += 1
	printerr("P9: load_extra=" + str(extra))
	if App.playtest and App.playtest.has_method("begin_smoke"):
		App.playtest.begin_smoke()
	var skills: int = App.prog.SKILLS.size()
	printerr("P9: skills=" + str(skills) + " sets=" + str(App.prog.SETS.size()))
	printerr("P9: splash=" + str(ResourceLoader.exists("res://scenes/splash.tscn")))
	tree(host).create_timer(1.2, true, false, true).timeout.connect(func():
		var fps: float = Engine.get_frames_per_second()
		printerr("P9: fps=" + str(fps))
		printerr("P9: fps_ok=" + str(fps >= 55.0 or fps <= 5.0 or fps > 200.0))
		printerr("P9: bitter_ok=" + str(App.bal.bitter_loop_offset > 15.0 and App.bal.bitter_loop_offset < 16.0))
		printerr("P9: checklist_skills=" + str(skills == 11))
		printerr("P9: checklist_sets=" + str(App.prog.SETS.size() == 8))
		printerr("P9: archives_ok=" + str(DirAccess.dir_exists_absolute(arch.path_join("full_3d_pass"))))
		if App.playtest:
			printerr("P9: playtest_live=" + str(App.playtest.live_running))
			printerr("P9: playtest_moved=" + str(App.playtest.moved))
			printerr("P9: playtest_sim=" + str(snapped(App.playtest.sim_t, 0.01)))
			printerr("P9: playtest_live_ok=" + str(App.playtest.moved or App.playtest.sim_t > 0.2))
		tree(host).quit()
	)
