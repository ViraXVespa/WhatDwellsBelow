extends Node2D

var grid: PackedByteArray
var w: int = 0
var h: int = 0
const TILE := 64
var floor_a: Texture2D
var floor_b: Texture2D
var wall_tex: Texture2D


func _ready() -> void:
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	floor_a = Art.load_tex("res://assets/tiles/dungeon_floor.png")
	floor_b = Art.load_tex("res://assets/tiles/dungeon_floor_b.png")
	wall_tex = Art.load_tex("res://assets/tiles/dungeon_wall.png")
	queue_redraw()


func _draw() -> void:
	if grid.is_empty():
		return
	var pad := 20
	# Solid rock beyond the carved grid so the hole feels cut from masonry.
	if wall_tex:
		for y in range(-pad, h + pad):
			for x in range(-pad, w + pad):
				if x >= 0 and y >= 0 and x < w and y < h:
					continue
				draw_texture_rect(wall_tex, Rect2(x * TILE, y * TILE, TILE, TILE), false)
	for y in h:
		for x in w:
			var t: int = grid[x + y * DungeonGen.W]
			var r := Rect2(x * TILE, y * TILE, TILE, TILE)
			if t == DungeonGen.FLOOR:
				var tex := floor_b if ((x + y) % 5 == 0) and floor_b else floor_a
				if tex:
					draw_texture_rect(tex, r, false)
				else:
					var shade := 0.04 if ((x + y) % 2 == 0) else 0.0
					draw_rect(r, Color(0.22 + shade, 0.23 + shade, 0.28 + shade))
			elif wall_tex:
				draw_texture_rect(wall_tex, r, false)
			else:
				draw_rect(r, Color(0.16, 0.17, 0.2))
