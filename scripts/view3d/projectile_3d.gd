extends Area3D

const V3 := preload("res://scripts/view3d/v3.gd")

var dir := Vector2.RIGHT
var speed := 240.0 / 64.0
var damage := 8.0
var life := 2.2


func setup(p_dir: Vector2, p_damage: float) -> void:
	dir = p_dir.normalized()
	damage = p_damage


func _ready() -> void:
	collision_layer = 8
	collision_mask = 1 | 2
	var cs := CollisionShape3D.new()
	var sh := SphereShape3D.new()
	sh.radius = 0.13
	cs.shape = sh
	add_child(cs)
	var tex := Art.load_tex("res://assets/sprites/props/bolt.png")
	if tex == null:
		tex = Art.solid(Vector2i(12, 12), Color(0.85, 0.35, 0.2))
	add_child(V3.sprite(tex, 0.35, true))
	body_entered.connect(_on_body)


func _physics_process(delta: float) -> void:
	var from := global_position + Vector3(0, 0.45, 0)
	var motion := Vector3(dir.x, 0.0, dir.y) * speed * delta
	var space := get_world_3d().direct_space_state
	var q := PhysicsRayQueryParameters3D.create(from, from + motion)
	q.collision_mask = 1 | 2
	q.collide_with_areas = false
	q.collide_with_bodies = true
	q.exclude = [self]
	var hit := space.intersect_ray(q)
	if not hit.is_empty():
		var col = hit.get("collider")
		if col is Node and (col as Node).is_in_group("player") and col.has_method("take_damage"):
			col.take_damage(damage, V3.xz(global_position))
		queue_free()
		return
	position += motion
	life -= delta
	if life <= 0.0:
		queue_free()


func _on_body(body: Node) -> void:
	if body.is_in_group("player") and body.has_method("take_damage"):
		body.take_damage(damage, V3.xz(global_position))
		queue_free()
		return
	if body is StaticBody3D:
		queue_free()
