class_name FloatNum
extends Node2D

var vel := Vector2(0, -42)
var life := 0.7
var lab: Label


func setup(amount: float, crit := false) -> void:
	lab = Label.new()
	lab.text = str(int(round(amount)))
	lab.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lab.add_theme_font_size_override("font_size", 22 if not crit else 28)
	lab.add_theme_color_override("font_color", Color(1.0, 0.92, 0.45) if crit else Color(0.98, 0.88, 0.78))
	lab.add_theme_color_override("font_outline_color", Color(0.05, 0.04, 0.06))
	lab.add_theme_constant_override("outline_size", 5)
	lab.position = Vector2(-24, -18)
	lab.size = Vector2(48, 24)
	add_child(lab)
	z_index = 30


func _process(delta: float) -> void:
	position += vel * delta
	vel.y += 18.0 * delta
	life -= delta
	modulate.a = clampf(life / 0.25, 0.0, 1.0)
	if life <= 0.0:
		queue_free()
