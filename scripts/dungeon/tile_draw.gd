extends Node2D

var grid: PackedByteArray
var w: int = 0
var h: int = 0
const TILE := 64


func _draw() -> void:
	if grid.is_empty():
		return
	for y in h:
		for x in w:
			var t: int = grid[x + y * DungeonGen.W]
			var r := Rect2(x * TILE, y * TILE, TILE, TILE)
			if t == DungeonGen.FLOOR:
				var shade := 0.04 if ((x + y) % 2 == 0) else 0.0
				draw_rect(r, Color(0.22 + shade, 0.23 + shade, 0.28 + shade))
			else:
				draw_rect(r, Color(0.08, 0.08, 0.10))
