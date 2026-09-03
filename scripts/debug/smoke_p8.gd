extends Object

const StoreS := preload("res://scripts/data/save_store.gd")
const CatS := preload("res://scripts/data/archives_catalog.gd")

static var enter_flag: bool = false


static func tree(host: Node) -> SceneTree:
	return host.get_tree()


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
	printerr("P8: arch_n=" + str(CatS.all().size()))
	printerr("P8: arch_classic=" + str(not CatS.by_id("classic_2d").is_empty()))
	printerr("P8: arch_art=" + str(not CatS.by_id("art_experiment").is_empty()))
	printerr("P8: arch_full=" + str(not CatS.by_id("full_3d_pass").is_empty()))
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
	printerr("P8: archives_ok=" + str(CatS.ok()))
	tree(host).create_timer(1.6, true, false, true).timeout.connect(func():
		printerr("P8: enter_cb=" + str(enter_flag))
		StoreS.wipe_slot("live")
		tree(host).quit()
	)
