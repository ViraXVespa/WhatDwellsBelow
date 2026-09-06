extends Label3D

const HOLD := 0.45
const FADE := 0.6

var vel := Vector3(0.0, 1.05, 0.0)
var life := HOLD + FADE
var fade_mul := 1.0


func setup(amount: int, crit: bool, glance := false) -> void:
	text = str(amount)
	billboard = BaseMaterial3D.BILLBOARD_ENABLED
	no_depth_test = true
	render_priority = 48
	outline_render_priority = 47
	pixel_size = 0.012
	shaded = false
	outline_size = 14
	font_size = 28 if glance else (50 if crit else 42)
	if glance:
		modulate = Color(0.82, 0.78, 0.74)
		outline_modulate = Color(0.05, 0.04, 0.06)
		fade_mul = 0.72
	elif crit:
		modulate = Color(1.0, 0.92, 0.2)
		outline_modulate = Color(0.12, 0.04, 0.14)
	else:
		modulate = Color(0.98, 0.88, 0.78)
		outline_modulate = Color(0.05, 0.04, 0.06)


func _process(delta: float) -> void:
	life -= delta
	if is_inside_tree():
		global_position += vel * delta
		sorting_offset = global_position.z * 6.0 + global_position.x * 0.04 + 80.0
	var a := fade_mul
	if life < FADE:
		a *= clampf(life / FADE, 0.0, 1.0)
	modulate.a = a
	outline_modulate.a = a
	if life <= 0.0:
		queue_free()
