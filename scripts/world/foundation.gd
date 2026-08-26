extends Node3D

const T := preload("res://scripts/data/tunables.gd")
const Depth := preload("res://scripts/world/depth.gd")
const PlayerS := preload("res://scripts/world/player.gd")
const DummyS := preload("res://scripts/combat/dummy.gd")

var player: CharacterBody3D
var hint: Label
var fps_lab: Label
var frame_acc := 0.0
var frame_n := 0
var smoke_frames := 0


func _ready() -> void:
	_world()
	_ground()
	_walls()
	_sort_props()
	player = PlayerS.new()
	player.position = Vector3(float(T.ARENA) * 0.5, 0.0, float(T.ARENA) * 0.5)
	add_child(player)
	_dummies()
	_hud()
	var args := OS.get_cmdline_user_args()
	if "--wdb-phase1-smoke" in args or "--wdb-phase2-smoke" in args:
		_smoke()


func _process(delta: float) -> void:
	smoke_frames += 1
	frame_acc += delta
	frame_n += 1
	if frame_acc >= 0.5 and fps_lab:
		var fps := float(frame_n) / frame_acc
		fps_lab.text = "%d FPS" % int(round(fps))
		frame_acc = 0.0
		frame_n = 0
	if Input.is_action_just_pressed("pause"):
		App.go_title()
	if Input.is_action_just_pressed("tab_right") or Input.is_action_just_pressed("tab_left"):
		var next := "female" if App.character_type == "male" else "male"
		App.set_character(next)
		if player.has_method("reload_character"):
			player.reload_character()
		_refresh_hint()
	if player:
		_refresh_hint()


func _world() -> void:
	var env := WorldEnvironment.new()
	var e := Environment.new()
	e.background_mode = Environment.BG_COLOR
	e.background_color = Color(0.04, 0.045, 0.06)
	e.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	e.ambient_light_color = Color(0.78, 0.74, 0.68)
	e.ambient_light_energy = 0.9
	e.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.environment = e
	add_child(env)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-52.0, 28.0, 0.0)
	sun.light_energy = 0.75
	sun.light_color = Color(0.85, 0.88, 0.95)
	sun.shadow_enabled = false
	add_child(sun)


func _ground() -> void:
	var mesh := PlaneMesh.new()
	mesh.size = Vector2(T.TILE, T.TILE)
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.mesh = mesh
	var n := T.ARENA * T.ARENA
	mm.instance_count = n
	var i := 0
	for z in T.ARENA:
		for x in T.ARENA:
			var xf := Transform3D.IDENTITY
			xf.origin = Vector3(float(x) + 0.5, T.FLOOR_Y, float(z) + 0.5)
			mm.set_instance_transform(i, xf)
			i += 1
	var inst := MultiMeshInstance3D.new()
	inst.multimesh = mm
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	var floor_path := "res://assets/tiles/foundation_floor.png"
	if ResourceLoader.exists(floor_path):
		mat.albedo_texture = load(floor_path)
	else:
		mat.albedo_color = Color(0.22, 0.2, 0.18)
	inst.material_override = mat
	add_child(inst)


func _walls() -> void:
	var body := StaticBody3D.new()
	body.name = "Walls"
	body.collision_layer = 1
	body.collision_mask = 0
	add_child(body)
	var w := float(T.ARENA)
	_box(body, Vector3(w, T.WALL_H, 1.0), Vector3(w * 0.5, T.WALL_H * 0.5, 0.5))
	_box(body, Vector3(w, T.WALL_H, 1.0), Vector3(w * 0.5, T.WALL_H * 0.5, w - 0.5))
	_box(body, Vector3(1.0, T.WALL_H, w), Vector3(0.5, T.WALL_H * 0.5, w * 0.5))
	_box(body, Vector3(1.0, T.WALL_H, w), Vector3(w - 0.5, T.WALL_H * 0.5, w * 0.5))
	var stone := _stone_mat()
	_clone_wall_mesh(stone, Vector3(w * 0.5, T.WALL_H * 0.5, 0.5), Vector3(w, T.WALL_H, 1.0))
	_clone_wall_mesh(stone, Vector3(w * 0.5, T.WALL_H * 0.5, w - 0.5), Vector3(w, T.WALL_H, 1.0))
	_clone_wall_mesh(stone, Vector3(0.5, T.WALL_H * 0.5, w * 0.5), Vector3(1.0, T.WALL_H, w))
	_clone_wall_mesh(stone, Vector3(w - 0.5, T.WALL_H * 0.5, w * 0.5), Vector3(1.0, T.WALL_H, w))
	_box(body, Vector3(1.6, T.WALL_H, 1.6), Vector3(8.0, T.WALL_H * 0.5, 7.0))
	_box(body, Vector3(2.2, T.WALL_H, 1.1), Vector3(14.5, T.WALL_H * 0.5, 12.0))
	_box(body, Vector3(1.1, T.WALL_H, 2.4), Vector3(6.0, T.WALL_H * 0.5, 15.5))
	_clone_wall_mesh(stone, Vector3(8.0, T.WALL_H * 0.5, 7.0), Vector3(1.6, T.WALL_H, 1.6))
	_clone_wall_mesh(stone, Vector3(14.5, T.WALL_H * 0.5, 12.0), Vector3(2.2, T.WALL_H, 1.1))
	_clone_wall_mesh(stone, Vector3(6.0, T.WALL_H * 0.5, 15.5), Vector3(1.1, T.WALL_H, 2.4))


func _stone_mat() -> StandardMaterial3D:
	var stone := StandardMaterial3D.new()
	stone.shading_mode = BaseMaterial3D.SHADING_MODE_PER_PIXEL
	stone.albedo_color = Color(0.28, 0.26, 0.24)
	stone.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	var wall_path := "res://assets/tiles/foundation_wall.png"
	if ResourceLoader.exists(wall_path):
		stone.albedo_texture = load(wall_path)
	return stone


func _clone_wall_mesh(mat: Material, pos: Vector3, size: Vector3) -> void:
	var vis := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = size
	vis.mesh = box
	vis.position = pos
	vis.material_override = mat
	add_child(vis)


func _box(host: StaticBody3D, size: Vector3, offset: Vector3) -> void:
	var cs := CollisionShape3D.new()
	var sh := BoxShape3D.new()
	sh.size = size
	cs.shape = sh
	cs.position = offset
	host.add_child(cs)


func _sort_props() -> void:
	var spots := [
		Vector3(10.5, 0.0, 9.2),
		Vector3(12.2, 0.0, 10.8),
		Vector3(9.4, 0.0, 11.6),
		Vector3(16.0, 0.0, 8.0),
		Vector3(5.5, 0.0, 9.8),
	]
	for p in spots:
		var s := Sprite3D.new()
		s.centered = true
		s.shaded = false
		s.double_sided = true
		s.alpha_cut = SpriteBase3D.ALPHA_CUT_OPAQUE_PREPASS
		s.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
		s.billboard = BaseMaterial3D.BILLBOARD_FIXED_Y
		s.render_priority = 1
		var crate := "res://assets/props/sort_crate.png"
		if ResourceLoader.exists(crate):
			s.texture = load(crate)
			s.pixel_size = 1.05 / float(maxi(1, s.texture.get_height()))
		s.position = p + Vector3(0.0, 0.55, 0.0)
		Depth.apply(s, p)
		add_child(s)


func _hud() -> void:
	var layer := CanvasLayer.new()
	add_child(layer)
	var panel := ColorRect.new()
	panel.color = Color(0.08, 0.07, 0.06, 0.82)
	panel.position = Vector2(32, 28)
	panel.size = Vector2(720, 168)
	layer.add_child(panel)
	var edge := ColorRect.new()
	edge.color = Color(0.62, 0.48, 0.28, 0.95)
	edge.position = Vector2(32, 28)
	edge.size = Vector2(640, 4)
	layer.add_child(edge)
	hint = Label.new()
	hint.position = Vector2(48, 40)
	hint.size = Vector2(608, 120)
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	hint.add_theme_font_size_override("font_size", 20)
	hint.add_theme_color_override("font_color", Color(0.92, 0.86, 0.72))
	hint.add_theme_color_override("font_outline_color", Color(0.05, 0.04, 0.03))
	hint.add_theme_constant_override("outline_size", 6)
	layer.add_child(hint)
	fps_lab = Label.new()
	fps_lab.position = Vector2(1720, 32)
	fps_lab.size = Vector2(160, 40)
	fps_lab.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	fps_lab.add_theme_font_size_override("font_size", 22)
	fps_lab.add_theme_color_override("font_color", Color(0.75, 0.9, 0.7))
	fps_lab.add_theme_color_override("font_outline_color", Color(0.04, 0.05, 0.04))
	fps_lab.add_theme_constant_override("outline_size", 6)
	layer.add_child(fps_lab)
	_refresh_hint()


func _dummies() -> void:
	var spots := [
		Vector3(11.0, 0.0, 12.2),
		Vector3(11.0, 0.0, 14.5),
		Vector3(14.6, 0.0, 11.0),
		Vector3(8.2, 0.0, 11.2),
		Vector3(13.4, 0.0, 13.6),
		Vector3(9.2, 0.0, 14.8),
		Vector3(16.2, 0.0, 16.0),
	]
	for p in spots:
		var d = DummyS.new()
		d.position = p
		add_child(d)


func _refresh_hint() -> void:
	if hint == null:
		return
	var w: String = App.weapon
	var lock := ""
	if player and player.get("lock_armed"):
		lock = "  ·  LOCK"
	hint.text = "Phase 2  ·  %s  ·  %s%s\nRT attack  ·  LT special  ·  B dash  ·  R3 lock  ·  1/2/3 weapons\nLB/RB character  ·  Start title" % [App.character_type, w, lock]


func _smoke() -> void:
	var cam: Camera3D = get_viewport().get_camera_3d()
	printerr("P1: res=" + ProjectSettings.globalize_path("res://"))
	printerr("P1: app=" + str(get_node_or_null("/root/App") != null))
	printerr("P1: game_autoload_absent=" + str(get_node_or_null("/root/Game") == null))
	printerr("P1: player=" + str(player != null))
	printerr("P1: character=" + App.character_type)
	if cam:
		printerr("P1: cam_ortho=" + str(cam.projection == Camera3D.PROJECTION_ORTHOGONAL))
		printerr("P1: cam_pitch=" + str(snappedf(cam.rotation_degrees.x, 0.1)))
		printerr("P1: cam_size=" + str(snappedf(cam.size, 0.01)))
	var spr = player.get("body") if player else null
	if spr:
		printerr("P1: billboard=" + str(spr.billboard == BaseMaterial3D.BILLBOARD_FIXED_Y))
	if player:
		printerr("P1: facing=" + str(player.get("facing_key")))
	printerr("P2: weapon=" + App.weapon)
	printerr("P2: dummy=" + str(get_tree().get_nodes_in_group("enemies").size()))
	printerr("P2: aim_line=" + str(player.get("aim_line") != null))
	printerr("P2: telegraph=" + str(player.get("telegraph") != null))
	printerr("P2: debug=" + str(App.debug != null))
	get_tree().create_timer(0.35).timeout.connect(_smoke_fire)


func _smoke_fire() -> void:
	if player and player.has_method("set_weapon"):
		player.aim_dir = Vector2.DOWN
		player.set_weapon("great_axe")
		player.atk_state = 1
		player.atk_t = 0.0
		player.hit_done = false
		player._draw_basic_tele(false)
	get_tree().create_timer(0.4).timeout.connect(func():
		if player:
			player._apply_basic()
			player._draw_basic_tele(true)
			printerr("P2: axe_tele_visible=" + str(player.telegraph.visible if player.telegraph else false))
			player.set_weapon("staff")
			player.spec_point = player.global_position + Vector3(0, 0, 2.2)
			player._apply_special()
			player.set_weapon("longbow")
			player._apply_basic()
			player._try_dash(Vector2.DOWN)
		printerr("P2: process_frames=" + str(smoke_frames))
		printerr("P2: fps_est=" + str(smoke_frames))
		printerr("P2: projectiles=" + str(_count_proj()))
		printerr("P2: schema=" + str(App.bal.schema().size()))
		get_tree().quit()
	)


func _count_proj() -> int:
	var n := 0
	for c in get_children():
		if c.get_script() and str(c.get_script().resource_path).ends_with("projectile.gd"):
			n += 1
	return n
