extends Label3D

var vel := 1.1
var life := 0.7


func _process(delta: float) -> void:
	position.y += vel * delta
	vel += 0.35 * delta
	life -= delta
	modulate.a = clampf(life / 0.25, 0.0, 1.0)
	if life <= 0.0:
		queue_free()
