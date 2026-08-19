extends Node2D

const TILE := 64
var ground_a: Texture2D
var ground_b: Texture2D
var wall_tex: Texture2D


func _ready() -> void:
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	ground_a = Art.load_tex("res://assets/tiles/plaza_ground.png")
	ground_b = Art.load_tex("res://assets/tiles/plaza_ground_b.png")
	wall_tex = Art.load_tex("res://assets/tiles/plaza_wall.png")
	queue_redraw()


func _draw() -> void:
	for y in 18:
		for x in 24:
			var r := Rect2(x * TILE, y * TILE, TILE, TILE)
			var border := x == 0 or y == 0 or x == 23 or y == 17
			if border and wall_tex:
				draw_texture_rect(wall_tex, r, false)
			else:
				var tex := ground_b if ((x * 3 + y) % 7 == 0) and ground_b else ground_a
				if tex:
					draw_texture_rect(tex, r, false)
				else:
					draw_rect(r, Color(0.45, 0.36, 0.26))
