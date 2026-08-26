extends Node3D

const Depth := preload("res://scripts/world/depth.gd")
const PickupS := preload("res://scripts/world/pickup.gd")

var kind := "pot"
var hp := 1.0
var dead := false
var spr: Sprite3D
var mesh: MeshInstance3D
var body: StaticBody3D
var reveal: Node = null


func setup(k: String, pos: Vector3) -> void:
	kind = k
	position = pos
	add_to_group("breakables")
	if kind == "crack":
		hp = App.bal.crack_hp
		_wall()
	else:
		hp = 1.0
		_spr()


func is_alive() -> bool:
	return not dead


func take_hit(raw: float, _from_dir: Vector2, _crit: bool) -> void:
	if dead:
		return
	hp -= maxf(1.0, raw * 0.08)
	if kind != "crack":
		hp = 0.0
	if spr:
		spr.modulate = Color(1.5, 1.5, 1.5)
	App.sfx("smash")
	if hp <= 0.0:
		_die()


func _die() -> void:
	if dead:
		return
	dead = true
	remove_from_group("breakables")
	if kind == "crack":
		if body:
			body.collision_layer = 0
		if reveal and reveal.has_method("unlock_hidden"):
			reveal.unlock_hidden()
		App.toast("The wall gives.")
		var tw := create_tween()
		if mesh:
			tw.tween_property(mesh, "scale", Vector3(0.2, 0.2, 0.2), 0.2)
		tw.finished.connect(queue_free)
		return
	_drop()
	if spr:
		var tw := create_tween()
		tw.tween_property(spr, "modulate:a", 0.0, 0.12)
		tw.finished.connect(queue_free)
	else:
		queue_free()


func _drop() -> void:
	var host := get_parent()
	if host == null:
		return
	if randf() < App.bal.break_gold:
		var n: int = 1 + randi() % 4
		_spawn_pick("gold", n)
	if randf() < App.bal.break_orb:
		_spawn_pick("hp", 0)


func _spawn_pick(what: String, n: int) -> void:
	var p = PickupS.new()
	p.setup(what, global_position + Vector3(randf_range(-0.2, 0.2), 0.0, randf_range(-0.2, 0.2)), n)
	var host := get_parent()
	if host:
		host.add_child(p)


func _spr() -> void:
	spr = Sprite3D.new()
	spr.centered = true
	spr.shaded = false
	spr.billboard = BaseMaterial3D.BILLBOARD_FIXED_Y
	spr.alpha_cut = SpriteBase3D.ALPHA_CUT_OPAQUE_PREPASS
	spr.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	var path := "res://assets/sprites/props/barrel.png" if kind == "barrel" else "res://assets/sprites/props/pot.png"
	if ResourceLoader.exists(path):
		spr.texture = load(path)
		spr.pixel_size = 0.85 / float(maxi(1, spr.texture.get_height()))
	spr.position.y = 0.4
	add_child(spr)
	Depth.apply(spr, position)


func _wall() -> void:
	body = StaticBody3D.new()
	body.collision_layer = 1
	body.collision_mask = 0
	add_child(body)
	var cs := CollisionShape3D.new()
	var sh := BoxShape3D.new()
	sh.size = Vector3(1.05, 1.45, 0.45)
	cs.shape = sh
	cs.position.y = 0.72
	body.add_child(cs)
	mesh = MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = Vector3(1.05, 1.45, 0.45)
	mesh.mesh = box
	mesh.position.y = 0.72
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.albedo_color = Color(0.38, 0.32, 0.28)
	mesh.material_override = m
	add_child(mesh)
	var lab := Label3D.new()
	lab.text = "CRACKED"
	lab.position = Vector3(0.0, 1.55, 0.0)
	lab.font_size = 28
	lab.outline_size = 8
	lab.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	lab.no_depth_test = true
	lab.pixel_size = 0.01
	lab.modulate = Color(0.95, 0.7, 0.4)
	add_child(lab)
