extends Node2D

const TILE := 64
var w := 40
var h := 28
var yard := Rect2i(5, 5, 30, 18)
var ground_a: Texture2D
var ground_b: Texture2D
var grass: Texture2D


func _ready() -> void:
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	ground_a = Art.load_tex("res://assets/tiles/plaza_ground.png")
	ground_b = Art.load_tex("res://assets/tiles/plaza_ground_b.png")
	grass = Art.load_tex("res://assets/tiles/plaza_grass.png")
	z_index = -8
	y_sort_enabled = false
	queue_redraw()


func _draw() -> void:
	for y in h:
		for x in w:
			var r := Rect2(x * TILE, y * TILE, TILE, TILE)
			var inside := yard.has_point(Vector2i(x, y))
			var tex: Texture2D = null
			if inside:
				tex = ground_b if ((x * 3 + y) % 7 == 0) and ground_b else ground_a
			else:
				tex = grass if grass else ground_a
			if tex:
				draw_texture_rect(tex, r, false)
			else:
				draw_rect(r, Color(0.28, 0.38, 0.22) if not inside else Color(0.45, 0.36, 0.26))
