extends Node3D

const Combat := preload("res://scripts/combat/combat.gd")
const Depth := preload("res://scripts/world/depth.gd")
const FloatS := preload("res://scripts/combat/float_num.gd")

var dir := Vector2.DOWN
var speed := 14.0
var max_range := 8.0
var damage := 14.0
var traveled := 0.0
var los_flag := true
var crit := false
var hurt_player := false
var grant_xp := false
var source := ""
var spr: Sprite3D


func setup(from: Vector3, aim: Vector2, spd: float, rng: float, dmg: float, need_los: bool, is_crit := false, from_enemy := false, tex_path := "", player_xp := false) -> void:
	global_position = from + Vector3(0.0, 0.55, 0.0)
	dir = aim.normalized() if aim.length_squared() > 0.0001 else Vector2.DOWN
	speed = spd
	max_range = rng
	damage = dmg
	los_flag = need_los
	crit = is_crit
	hurt_player = from_enemy
	grant_xp = player_xp and not from_enemy
	spr = Sprite3D.new()
	spr.centered = true
	spr.shaded = false
	spr.billboard = BaseMaterial3D.BILLBOARD_FIXED_Y
	spr.alpha_cut = SpriteBase3D.ALPHA_CUT_OPAQUE_PREPASS
	spr.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	var path := tex_path if tex_path != "" else "res://assets/fx/arrow.png"
	if ResourceLoader.exists(path):
		spr.texture = load(path)
		spr.pixel_size = 0.55 / float(maxi(1, spr.texture.get_height()))
	else:
		spr.modulate = Color(0.85, 0.7, 0.4)
		spr.pixel_size = 0.01
	if hurt_player:
		spr.modulate = Color(1.15, 0.45, 0.35)
	add_child(spr)


func _physics_process(delta: float) -> void:
	var step := speed * delta
	var from := global_position
	var to := from + Vector3(dir.x, 0.0, dir.y) * step
	var space := get_world_3d().direct_space_state
	var q := PhysicsRayQueryParameters3D.create(from, to)
	q.collision_mask = 1
	var wall := space.intersect_ray(q)
	if not wall.is_empty():
		queue_free()
		return
	global_position = to
	traveled += step
	if spr:
		Depth.apply(spr, global_position)
	if hurt_player:
		var tree := get_tree()
		if tree:
			var pnode := tree.get_first_node_in_group("player")
			if pnode is Node3D and pnode.has_method("take_hit"):
				var d := Combat.xz(pnode) - Vector2(global_position.x, global_position.z)
				if d.length() <= 0.42:
					pnode.take_hit(damage, dir, crit, source)
					queue_free()
					return
	else:
		for e in Combat.enemies():
			if e == null or not is_instance_valid(e):
				continue
			if e.has_method("is_alive") and not e.is_alive():
				continue
			var d := Combat.xz(e) - Vector2(global_position.x, global_position.z)
			if d.length() <= 0.38:
				_hit(e)
				return
	for b in get_tree().get_nodes_in_group("breakables"):
		if b == null or not is_instance_valid(b):
			continue
		if hurt_player:
			break
		var bd := Combat.xz(b) - Vector2(global_position.x, global_position.z)
		if bd.length() <= 0.4 and b.has_method("take_hit"):
			b.take_hit(damage, dir, false)
			queue_free()
			return
	if traveled >= max_range:
		queue_free()


func _hit(e: Node) -> void:
	if grant_xp:
		App.prog.skill_grant_hit(false)
	if e.has_method("take_hit"):
		e.take_hit(damage, dir, crit)
	if grant_xp and App.tel:
		App.tel.note_damage_dealt(damage if not crit else damage * App.bal.crit_mult, crit)
	queue_free()
