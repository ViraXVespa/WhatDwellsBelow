extends Node2D

const TILE := 64


func _draw() -> void:
	draw_rect(Rect2(0, 0, 24 * TILE, 18 * TILE), Color(0.45, 0.36, 0.26))
	for y in 18:
		for x in 24:
			if (x + y) % 7 == 0:
				draw_rect(Rect2(x * TILE, y * TILE, TILE, TILE), Color(0.42, 0.33, 0.24))
	draw_rect(Rect2(3 * TILE, 3 * TILE, 5 * TILE, 3 * TILE), Color(0.35, 0.22, 0.16))
	draw_rect(Rect2(16 * TILE, 3 * TILE, 5 * TILE, 3 * TILE), Color(0.32, 0.24, 0.18))
	draw_rect(Rect2(3 * TILE, 13 * TILE, 4 * TILE, 2 * TILE), Color(0.28, 0.28, 0.30))
	draw_rect(Rect2(11 * TILE, 3 * TILE, 2 * TILE, 2 * TILE), Color(0.25, 0.55, 0.58))
