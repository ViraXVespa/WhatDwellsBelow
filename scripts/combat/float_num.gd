extends Label3D

var vel := Vector3(0.0, 1.15, 0.0)
var life := 0.7


func setup(amount: int, crit: bool) -> void:
	text = str(amount)
	billboard = BaseMaterial3D.BILLBOARD_ENABLED
	font_size = 42 if not crit else 50
	outline_size = 10
	outline_modulate = Color(0.05, 0.04, 0.06)
	no_depth_test = true
	pixel_size = 0.012
	if crit:
		modulate = Color(1.0, 0.92, 0.2)
		outline_modulate = Color(0.85, 0.1, 0.75)
	else:
		modulate = Color(0.98, 0.88, 0.78)


func _process(delta: float) -> void:
	life -= delta
	position += vel * delta
	modulate.a = clampf(life / 0.7, 0.0, 1.0)
	if life <= 0.0:
		queue_free()
