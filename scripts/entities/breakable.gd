class_name Breakable
extends StaticBody2D

var hp := 1.0
var kind := "pot"
var rng := RandomNumberGenerator.new()


func setup(p_kind: String) -> void:
	kind = p_kind
	rng.randomize()
	collision_layer = 1
	collision_mask = 0
	add_to_group("breakables")
	add_to_group("hittable")
	var cs := CollisionShape2D.new()
	var sh := RectangleShape2D.new()
	sh.size = Vector2(28, 28)
	cs.shape = sh
	add_child(cs)
	var path := "res://assets/sprites/props/%s.png" % kind
	var tex := Art.load_tex(path)
	if tex == null:
		tex = Art.chest(Vector2i(40, 40)) if kind == "barrel" else Art.solid(Vector2i(28, 32), Color(0.62, 0.38, 0.2))
	add_child(Art.make_sprite(tex, 0.58 if kind == "barrel" else 0.52))


func take_damage(amount: float, _from: Node = null) -> void:
	hp -= amount
	if hp <= 0.0:
		Sfx.play("smash")
		_smash()


func _smash() -> void:
	var parent := get_parent()
	var pos := global_position
	if rng.randf() < 0.85:
		Game.add_run_gold(rng.randi_range(1, 5))
	if rng.randf() < 0.42:
		_spawn_pickup(parent, pos + Vector2(rng.randf_range(-10, 10), rng.randf_range(-8, 8)), "hp", rng.randf_range(10.0, 18.0))
	queue_free()


func _spawn_pickup(parent: Node, pos: Vector2, p_kind: String, amount: float) -> void:
	if parent == null:
		return
	var p := FloorPickup.new()
	p.position = pos
	parent.add_child(p)
	p.setup(p_kind, amount)
