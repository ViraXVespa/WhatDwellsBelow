extends Node3D

const T := preload("res://scripts/data/tunables.gd")
const PlayerS := preload("res://scripts/world/player.gd")
const SpotS := preload("res://scripts/world/interact.gd")
const UiS := preload("res://scripts/ui/progress_ui.gd")
const StoreS := preload("res://scripts/data/save_store.gd")

var player: CharacterBody3D
var ui: CanvasLayer
var hint: Label
var prompt: Label
var smoke_entered := false


func _ready() -> void:
	App.in_dungeon = false
	_world()
	_ground()
	_buildings()
	player = PlayerS.new()
	player.position = Vector3(16.0, 0.0, 16.0)
	add_child(player)
	_spots()
	ui = UiS.new()
	add_child(ui)
	_hud()
	_music()
	if App.wake_pending:
		App.wake_pending = false
		if App.present and App.present.has_method("play_wake"):
			App.present.play_wake()
		App.prog.roll_quests(true)
		var r := App.prog.restock()
		if r != "":
			App.toast(r)
	var args := OS.get_cmdline_user_args()
	if "--wdb-phase8-smoke" not in args and not (App.playtest and bool(App.playtest.get("live_running"))):
		App.save_now()
	if "--wdb-phase6-smoke" in args:
		_smoke6()
	if "--wdb-phase8-smoke" in args:
		_smoke8()


func world_ui() -> Node:
	return ui


func _process(_delta: float) -> void:
	if Input.is_action_just_pressed("pause"):
		if App.ui_open and ui and ui.visible:
			ui.close_ui()
		elif App.pause_menu and App.pause_menu.has_method("toggle"):
			App.pause_menu.toggle()
	if hint:
		var hot := ""
		if App.prog.food_t > 0.0:
			hot = "  ·  Food HoT %ds" % int(ceil(App.prog.food_t))
		hint.text = "Placeholdia  ·  bank %dg  %d ore  %d wood  ·  deepest F%d%s\nCrystal  ·  Anvil  ·  Vendor  ·  Guild  ·  Billboard  ·  Start pause" % [App.bank_gold, App.bank_ore, App.bank_wood, App.prog.deepest, hot]
	if prompt:
		prompt.text = App.interact_prompt
	var bt := App.web_buttons()
	if bt.size() > 0 and Time.get_ticks_msec() % 400 < 30:
		print("js0=", bt[0] if bt.size() > 0 else -1,
			" js1=", bt[1] if bt.size() > 1 else -1,
			" js9=", bt[9] if bt.size() > 9 else -1)


func _world() -> void:
	var env := WorldEnvironment.new()
	var e := Environment.new()
	e.background_mode = Environment.BG_COLOR
	e.background_color = Color(0.45, 0.58, 0.62)
	e.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	e.ambient_light_color = Color(0.95, 0.86, 0.7)
	e.ambient_light_energy = 1.15
	e.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.environment = e
	add_child(env)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-50.0, 30.0, 0.0)
	sun.light_energy = 0.9
	add_child(sun)


func _ground() -> void:
	var body := StaticBody3D.new()
	body.collision_layer = 1
	add_child(body)
	var cs := CollisionShape3D.new()
	var sh := BoxShape3D.new()
	sh.size = Vector3(36.0, 0.4, 32.0)
	cs.shape = sh
	cs.position = Vector3(16.0, -0.2, 14.0)
	body.add_child(cs)
	var vis := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = Vector3(36.0, 0.08, 32.0)
	vis.mesh = box
	vis.position = Vector3(16.0, -0.02, 14.0)
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_color = Color(0.42, 0.48, 0.32)
	if ResourceLoader.exists("res://assets/tiles/plaza_ground.png"):
		mat.albedo_texture = load("res://assets/tiles/plaza_ground.png")
		mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	vis.material_override = mat
	add_child(vis)


func _buildings() -> void:
	_solid(Vector3(8.0, 1.7, 6.0), Vector3(5.2, 3.4, 4.2), Color(0.45, 0.32, 0.22), "res://assets/sprites/buildings/guild.png")
	_solid(Vector3(14.2, 1.5, 5.4), Vector3(4.0, 3.0, 3.6), Color(0.5, 0.38, 0.28), "res://assets/sprites/buildings/guild_reception.png")
	_solid(Vector3(25.0, 1.2, 8.0), Vector3(4.6, 2.4, 3.4), Color(0.55, 0.35, 0.2), "res://assets/sprites/buildings/stall.png")


func _solid(pos: Vector3, size: Vector3, col: Color, tex: String) -> void:
	var body := StaticBody3D.new()
	body.collision_layer = 1
	body.position = pos
	add_child(body)
	var cs := CollisionShape3D.new()
	var sh := BoxShape3D.new()
	sh.size = size
	cs.shape = sh
	body.add_child(cs)
	var vis := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = size
	vis.mesh = box
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_PER_PIXEL
	mat.albedo_color = col
	mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	vis.material_override = mat
	body.add_child(vis)
	if ResourceLoader.exists(tex):
		var face := Sprite3D.new()
		face.texture = load(tex)
		face.centered = true
		face.shaded = false
		face.alpha_cut = SpriteBase3D.ALPHA_CUT_OPAQUE_PREPASS
		face.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
		face.pixel_size = size.y / float(maxi(1, face.texture.get_height()))
		face.position = Vector3(0.0, 0.05, size.z * 0.5 + 0.04)
		body.add_child(face)


func _banner() -> void:
	var pole := StaticBody3D.new()
	pole.collision_layer = 1
	pole.position = Vector3(16.0, 1.1, 22.0)
	add_child(pole)
	var cs := CollisionShape3D.new()
	var sh := BoxShape3D.new()
	sh.size = Vector3(4.2, 2.2, 0.45)
	cs.shape = sh
	pole.add_child(cs)
	var spr := Sprite3D.new()
	var path := "res://assets/sprites/props/welcome_banner.png"
	if ResourceLoader.exists(path):
		spr.texture = load(path)
	elif ResourceLoader.exists("res://assets/sprites/props/banner.png"):
		spr.texture = load("res://assets/sprites/props/banner.png")
	spr.centered = true
	spr.shaded = false
	spr.billboard = BaseMaterial3D.BILLBOARD_FIXED_Y
	spr.alpha_cut = SpriteBase3D.ALPHA_CUT_OPAQUE_PREPASS
	spr.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	if spr.texture:
		spr.pixel_size = 2.2 / float(maxi(1, spr.texture.get_height()))
	spr.position.y = 0.2
	pole.add_child(spr)


func _spots() -> void:
	_banner()
	var c := SpotS.new()
	c.setup("loadout_crystal", Vector3(16.0, 0.0, 14.0))
	add_child(c)
	var a := SpotS.new()
	a.setup("anvil", Vector3(12.0, 0.0, 13.2))
	add_child(a)
	var q := SpotS.new()
	q.setup("quest_board", Vector3(11.5, 0.0, 8.2))
	add_child(q)
	var rec := SpotS.new()
	rec.setup("receptionist", Vector3(14.2, 0.0, 8.0))
	add_child(rec)
	var v := SpotS.new()
	v.setup("vendor", Vector3(25.0, 0.0, 10.4))
	add_child(v)
	var d := SpotS.new()
	d.setup("dumpster", Vector3(5.5, 0.0, 9.2))
	add_child(d)
	var b := SpotS.new()
	b.setup("billboard", Vector3(20.5, 0.0, 16.5))
	add_child(b)


func _music() -> void:
	if App.music and App.music.has_method("play_hub"):
		App.music.play_hub()


func _hud() -> void:
	var layer := CanvasLayer.new()
	add_child(layer)
	var panel := ColorRect.new()
	panel.color = Color(0.1, 0.08, 0.06, 0.82)
	panel.position = Vector2(32, 28)
	panel.size = Vector2(980, 150)
	layer.add_child(panel)
	hint = Label.new()
	hint.position = Vector2(48, 40)
	hint.size = Vector2(950, 80)
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	hint.add_theme_font_size_override("font_size", 20)
	hint.add_theme_color_override("font_color", Color(0.92, 0.86, 0.72))
	hint.add_theme_color_override("font_outline_color", Color(0.05, 0.04, 0.03))
	hint.add_theme_constant_override("outline_size", 6)
	layer.add_child(hint)
	prompt = Label.new()
	prompt.position = Vector2(48, 118)
	prompt.size = Vector2(900, 40)
	prompt.add_theme_font_size_override("font_size", 22)
	prompt.add_theme_color_override("font_color", Color(0.95, 0.82, 0.4))
	prompt.add_theme_color_override("font_outline_color", Color(0.05, 0.04, 0.03))
	prompt.add_theme_constant_override("outline_size", 6)
	layer.add_child(prompt)


func _smoke6() -> void:
	printerr("P6: res=" + ProjectSettings.globalize_path("res://"))
	printerr("P6: sets=" + str(App.prog.SETS.size()) + " " + ", ".join(App.prog.SETS))
	var sizes: PackedStringArray = PackedStringArray()
	const Cat := preload("res://scripts/data/catalog.gd")
	for s in App.prog.SETS:
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
	var p1 := App.prog.use_potion()
	var hp1 := float(player.get("hp"))
	printerr("P6: potion=" + p1 + " hp=" + str(hp1) + " instant_ok=" + str(hp1 > 40.0))
	player.set("hp", 40.0)
	var f1 := App.prog.use_food()
	var f2 := App.prog.use_food()
	printerr("P6: food1=" + f1 + " food_same=" + f2)
	printerr("P6: food_hot=" + str(App.prog.food_t > 0.0) + " same_blocked=" + str(f2.find("Already") >= 0))
	App.prog.slots["food"] = App.prog.make_food("bread", 2)
	var f3 := App.prog.use_food()
	printerr("P6: food_swap=" + f3 + " id=" + App.prog.food_id + " swap_ok=" + str(App.prog.food_id == "bread"))
	App.gold = 80
	App.ore = 12
	App.prog.root = 6
	App.prog.add_item(App.prog.make_weapon("great_axe", "white"))
	var axe: Dictionary = App.prog.bag[App.prog.bag.size() - 1]
	var forge := App.prog.forge_item(axe)
	printerr("P6: forge=" + forge + " holds=" + str((App.prog.holds["weapon"] as Array).size()) + " forge_ok=" + str((App.prog.holds["weapon"] as Array).size() > 0))
	App.gold = 10
	App.ore = 8
	App.wood = 5
	App.prog.add_item(App.prog.make_armor("head", "white"))
	var ex := App.prog.extract_all("patty")
	printerr("P6: extract=" + ex + " extracted=" + str(App.extracted) + " bank_o=" + str(App.bank_ore))
	App.prog.quest_active = {}
	App.prog.roll_quests(false)
	var acc := App.prog.accept_quest(0)
	printerr("P6: quest=" + acc + " active=" + str(App.prog.quest_active.get("title", "")))
	App.prog.quest_active = {}
	App.quest_named_type = ""
	var named_q := false
	for i in App.prog.quests_offered.size():
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
	get_tree().create_timer(0.4).timeout.connect(func(): get_tree().quit())


func _smoke8() -> void:
	printerr("P8: res=" + ProjectSettings.globalize_path("res://"))
	var kinds: PackedStringArray = PackedStringArray()
	for n in get_tree().get_nodes_in_group("interact"):
		var k := str(n.get("kind"))
		if kinds.find(k) < 0:
			kinds.append(k)
	printerr("P8: hub_kinds=" + ", ".join(kinds))
	var need := ["loadout_crystal", "anvil", "quest_board", "receptionist", "vendor", "dumpster", "billboard"]
	var hub_ok := true
	for k in need:
		if kinds.find(k) < 0:
			hub_ok = false
	printerr("P8: hub_ok=" + str(hub_ok))
	var depth_ok := false
	for n in get_children():
		if n is StaticBody3D:
			for c in n.get_children():
				if c is CollisionShape3D:
					var sh := (c as CollisionShape3D).shape
					if sh is BoxShape3D:
						var b := sh as BoxShape3D
						if b.size.z >= 3.0 and b.size.y >= 2.0:
							depth_ok = true
	printerr("P8: building_depth=" + str(depth_ok))
	var ban_path := "res://assets/sprites/props/welcome_banner.png"
	var ban := ResourceLoader.exists(ban_path) or FileAccess.file_exists(ban_path)
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
	var how := StoreS.load_slot("live")
	printerr("P8: load_after_corrupt=" + how + " gold=" + str(App.bank_gold) + " deep=" + str(App.prog.deepest) + " axe_perm=" + str(App.prog.skills_perm.get("axe", 0)))
	printerr("P8: backup_ok=" + str(how == "backup" and App.bank_gold == 42 and App.prog.deepest == 4))
	StoreS.corrupt_primary("live")
	var bakp := StoreS.backup_path("live")
	var bf := FileAccess.open(bakp, FileAccess.WRITE)
	if bf:
		bf.store_string("%%%")
	var how2 := StoreS.load_slot("live")
	printerr("P8: both_fail=" + how2 + " fresh_ok=" + str(how2 == "fresh"))
	StoreS.wipe_slot("fresh")
	StoreS.wipe_slot("progressed")
	App.prog.skills_perm["str"] = 0.0
	StoreS.save_slot("fresh")
	App.prog.skills_perm["str"] = 400.0
	StoreS.save_slot("progressed")
	StoreS.load_slot("progressed")
	var pt_str := float(App.prog.skills_perm.get("str", 0))
	StoreS.load_slot("fresh")
	var fr_str := float(App.prog.skills_perm.get("str", 0))
	printerr("P8: playtest_isolated=" + str(pt_str >= 400.0 and fr_str < 50.0 and StoreS.dir_for("fresh") != StoreS.dir_for("live")))
	printerr("P8: live_dir=" + StoreS.dir_for("live") + " fresh_dir=" + StoreS.dir_for("fresh") + " prog_dir=" + StoreS.dir_for("progressed"))
	var root := ProjectSettings.globalize_path("res://").trim_suffix("/")
	var arch := root.path_join("archives")
	printerr("P8: arch_full=" + str(DirAccess.dir_exists_absolute(arch.path_join("full_3d_pass"))))
	printerr("P8: arch_classic=" + str(DirAccess.dir_exists_absolute(arch.path_join("classic_2d"))))
	printerr("P8: arch_art=" + str(DirAccess.dir_exists_absolute(arch.path_join("art_experiment"))))
	App.wake_pending = true
	if App.present and App.present.has_method("play_wake"):
		App.present.play_wake()
	printerr("P8: wake_playing=" + str(App.present.get("playing") == true or App.present.visible))
	smoke_entered = false
	if App.present and App.present.has_method("play_enter"):
		App.present.play_enter(Callable(self, "_on_smoke_enter"))
	printerr("P8: enter_started=" + str(App.present.get("playing") == true or App.present.visible))
	var dump_txt := ""
	for n in get_tree().get_nodes_in_group("interact"):
		if str(n.get("kind")) == "dumpster" and n.has_method("interact"):
			dump_txt = str(n.interact(player))
			break
	printerr("P8: dumpster=" + dump_txt)
	printerr("P8: dumpster_ok=" + str(dump_txt.find("Career upgrade pending") >= 0))
	printerr("P8: save_ok=" + str(how == "backup"))
	printerr("P8: archives_ok=" + str(DirAccess.dir_exists_absolute(arch.path_join("full_3d_pass"))))
	get_tree().create_timer(1.6, true, false, true).timeout.connect(func():
		printerr("P8: enter_cb=" + str(smoke_entered))
		StoreS.wipe_slot("live")
		get_tree().quit()
	)


func _on_smoke_enter() -> void:
	smoke_entered = true




