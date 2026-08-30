extends Node3D

const T := preload("res://scripts/data/tunables.gd")
const PlayerS := preload("res://scripts/world/player.gd")
const SpotS := preload("res://scripts/world/interact.gd")
const UiS := preload("res://scripts/ui/progress_ui.gd")
const Smoke := preload("res://scripts/debug/smoke.gd")

const GROUND_W := 36
const GROUND_D := 32
const GROUND_OX := -2
const GROUND_OZ := -2

var player: CharacterBody3D
var ui: CanvasLayer
var hint: Label
var prompt: Label


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
	if not Smoke.phase(8) and not (App.playtest and bool(App.playtest.get("live_running"))):
		App.save_now()
	Smoke.attach_camp(self)


func world_ui() -> Node:
	return ui


func _process(_delta: float) -> void:
	if App.pause_just() if App.has_method("pause_just") else (Input.is_action_just_pressed("pause") or App.pad_just("pause")):
		if App.ui_open and ui and ui.visible:
			ui.close_ui()
			if App.has_method("swallow_close_pad"):
				App.swallow_close_pad()
		elif App.pause_menu and App.pause_menu.has_method("toggle"):
			App.pause_menu.toggle()
	if hint:
		var hot := ""
		if App.prog.food_t > 0.0:
			hot = "  ·  Food HoT %ds" % int(ceil(App.prog.food_t))
		hint.text = "Placeholdia  ·  bank %dg  %d ore  %d wood  ·  deepest F%d%s\nCrystal  ·  Anvil  ·  Vendor  ·  Guild  ·  Billboard  ·  Start pause" % [App.bank_gold, App.bank_ore, App.bank_wood, App.prog.deepest, hot]
	if prompt:
		prompt.text = App.interact_prompt


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
	body.name = "Ground"
	body.collision_layer = 1
	add_child(body)
	var cs := CollisionShape3D.new()
	var sh := BoxShape3D.new()
	sh.size = Vector3(float(GROUND_W), 0.4, float(GROUND_D))
	cs.shape = sh
	cs.position = Vector3(16.0, -0.2, 14.0)
	body.add_child(cs)
	var grass: Array = []
	var packed_a: Array = []
	var packed_b: Array = []
	var path: Array = []
	for z in GROUND_D:
		for x in GROUND_W:
			var gx := GROUND_OX + x
			var gz := GROUND_OZ + z
			var pos := Vector3(float(gx) + 0.5, T.FLOOR_Y, float(gz) + 0.5)
			var in_yard := gx >= 2 and gx <= 30 and gz >= 4 and gz <= 24
			var on_path := (gz >= 13 and gz <= 16 and gx >= 6 and gx <= 26) or (gx >= 15 and gx <= 17 and gz >= 8 and gz <= 22)
			if not in_yard:
				grass.append(pos)
			elif on_path:
				path.append(pos)
			elif (gx * 3 + gz) % 7 == 0:
				packed_b.append(pos)
			else:
				packed_a.append(pos)
	_tile_layer("res://assets/tiles/plaza_grass.png", grass, Color(0.34, 0.46, 0.24))
	_tile_layer("res://assets/tiles/plaza_ground.png", packed_a, Color(0.46, 0.42, 0.30))
	_tile_layer("res://assets/tiles/plaza_ground_b.png", packed_b, Color(0.40, 0.36, 0.26))
	_tile_layer("res://assets/tiles/plaza_ground_b.png", path, Color(0.38, 0.34, 0.24))


func _tile_layer(tex_path: String, points: Array, fallback: Color) -> void:
	if points.is_empty():
		return
	var mesh := PlaneMesh.new()
	mesh.size = Vector2(T.TILE, T.TILE)
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.mesh = mesh
	mm.instance_count = points.size()
	for i in points.size():
		var xf := Transform3D.IDENTITY
		xf.origin = points[i]
		mm.set_instance_transform(i, xf)
	var inst := MultiMeshInstance3D.new()
	inst.multimesh = mm
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	mat.albedo_color = Color.WHITE
	if ResourceLoader.exists(tex_path):
		mat.albedo_texture = load(tex_path)
	else:
		mat.albedo_color = fallback
	inst.material_override = mat
	add_child(inst)


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