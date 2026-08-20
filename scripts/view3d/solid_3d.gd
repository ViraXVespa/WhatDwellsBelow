extends StaticBody3D

const V3 := preload("res://scripts/view3d/v3.gd")
const PickupS := preload("res://scripts/view3d/area_3d.gd")

var kind := "pot"
var hp := 1.0
var gate_id := 0
var open := false
var spr: Sprite3D
var col: CollisionShape3D
var rng := RandomNumberGenerator.new()


func setup_breakable(p_kind: String) -> void:
	kind = p_kind
	hp = 1.0
	rng.randomize()
	collision_layer = 1
	collision_mask = 0
	add_to_group("breakables")
	add_to_group("hittable")
	col = V3.add_box(self, Vector3(0.44, 0.55, 0.44), Vector3(0, 0.28, 0))
	var path := "res://assets/3d/props/%s.png" % kind
	var tex := Art.load_tex(path)
	if tex == null:
		tex = Art.chest(Vector2i(40, 40)) if kind == "barrel" else Art.solid(Vector2i(28, 32), Color(0.62, 0.38, 0.2))
	spr = V3.sprite(tex, 0.7 if kind == "barrel" else 0.55, true)
	add_child(spr)


func setup_cracked() -> void:
	kind = "crack"
	hp = 8.0
	collision_layer = 1
	collision_mask = 0
	add_to_group("hittable")
	col = V3.add_box(self, Vector3(1.0, V3.WALL_H, 1.0), Vector3(0, V3.WALL_H * 0.5, 0))
	spr = V3.sprite(Art.solid(Vector2i(62, 62), Color(0.38, 0.34, 0.32)), 1.05, false)
	add_child(spr)


func setup_gate(id: int) -> void:
	kind = "gate"
	gate_id = id
	add_to_group("gates")
	collision_layer = 1
	collision_mask = 0
	col = V3.add_box(self, Vector3(1.0, V3.WALL_H, 1.0), Vector3(0, V3.WALL_H * 0.5, 0))
	spr = V3.sprite(Art.solid(Vector2i(58, 58), Color(0.42, 0.38, 0.34)), 1.15, false)
	add_child(spr)


func open_gate() -> void:
	if open:
		return
	open = true
	if col:
		col.disabled = true
	if spr:
		spr.modulate = Color(1, 1, 1, 0.15)
	Sfx.play("ui")


func take_damage(amount: float, _from: Node = null) -> void:
	hp -= amount
	if spr:
		spr.modulate = Color(0.7, 0.55, 0.5)
	if hp > 0.0:
		return
	Sfx.play("smash")
	if kind == "crack":
		queue_free()
		return
	_smash()


func _smash() -> void:
	var parent := get_parent()
	var pos := global_position
	if rng.randf() < 0.85:
		Game.add_run_gold(rng.randi_range(1, 5))
	if rng.randf() < 0.42 and parent:
		var p = PickupS.new()
		parent.add_child(p)
		p.setup_pickup("hp", rng.randf_range(10.0, 18.0), pos + Vector3(rng.randf_range(-0.16, 0.16), 0.15, rng.randf_range(-0.12, 0.12)))
	queue_free()
