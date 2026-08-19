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
			elif _touches_floor(x, y):
				if wall_tex:
					draw_texture_rect(wall_tex, r, false)
				else:
					draw_rect(r, Color(0.07, 0.07, 0.09))
			# else: padding / off-carve stays clear-color black (endless void)


func _touches_floor(x: int, y: int) -> bool:
	for n: Vector2i in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
		var nx: int = x + n.x
		var ny: int = y + n.y
		if nx < 0 or ny < 0 or nx >= w or ny >= h:
			continue
		if grid[nx + ny * DungeonGen.W] == DungeonGen.FLOOR:
			return true
	return false
