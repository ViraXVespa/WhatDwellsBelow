class_name Projectile
extends Area2D

var dir := Vector2.RIGHT
var speed := 240.0
var damage := 8.0
var life := 2.2


func setup(p_dir: Vector2, p_damage: float) -> void:
	dir = p_dir.normalized()
	damage = p_damage


func _ready() -> void:
	collision_layer = 8
	collision_mask = 1 | 2
	var cs := CollisionShape2D.new()
	var sh := CircleShape2D.new()
	sh.radius = 8
	cs.shape = sh
	add_child(cs)
	var spr := Sprite2D.new()
	spr.texture = Art.solid(Vector2i(12, 12), Color(0.85, 0.35, 0.2))
	add_child(spr)
	body_entered.connect(_on_body)


func _physics_process(delta: float) -> void:
	var from := global_position
	var motion := dir * speed * delta
	var space := get_world_2d().direct_space_state
	var q := PhysicsRayQueryParameters2D.create(from, from + motion)
	q.collision_mask = 1 | 2
	q.collide_with_areas = false
	q.collide_with_bodies = true
	var hit := space.intersect_ray(q)
	if not hit.is_empty():
		var col = hit.get("collider")
		if col is Player:
			(col as Player).take_damage(damage)
		queue_free()
		return
	position += motion
	life -= delta
	if life <= 0.0:
		queue_free()


func _on_body(body: Node) -> void:
	if body is Player:
		(body as Player).take_damage(damage)
		queue_free()
		return
	if body is StaticBody2D:
		queue_free()
