class_name Minimap
extends Control

const TILE_PX := 5.0
const BORDER := Color(0.45, 0.38, 0.22, 0.95)


func _ready() -> void:
	custom_minimum_size = Vector2(220, 160)
	size = Vector2(220, 160)
	clip_contents = true


func refresh() -> void:
	queue_redraw()


func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), Color(0, 0, 0, 1))
	if not Game.in_dungeon:
		draw_string(ThemeDB.fallback_font, Vector2(12, 28), Game.DEMO_TOWN, HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color(0.9, 0.85, 0.7))
		_border()
		return
	var dungeon := get_tree().current_scene
	if dungeon == null or dungeon.get("data") == null:
		_border()
		return
	var data: Dictionary = dungeon.data
	if data.is_empty():
		_border()
		return
	var w: int = data.w
	var h: int = data.h
	var visited: PackedByteArray = dungeon.fog_visited
	var p := get_tree().get_first_node_in_group("player") as Node2D
	var cx: float = float(w) * 0.5
	var cy: float = float(h) * 0.5
	if p:
		cx = p.position.x / 64.0
		cy = p.position.y / 64.0
	var half_x := size.x / (2.0 * TILE_PX)
	var half_y := size.y / (2.0 * TILE_PX)
	var x0 := maxi(0, int(floorf(cx - half_x)) - 1)
	var y0 := maxi(0, int(floorf(cy - half_y)) - 1)
	var x1 := mini(w - 1, int(ceilf(cx + half_x)) + 1)
	var y1 := mini(h - 1, int(ceilf(cy + half_y)) + 1)
	for y in range(y0, y1 + 1):
		for x in range(x0, x1 + 1):
			var i: int = x + y * DungeonGen.W
			if visited[i] == 0:
				continue
			if data.grid[i] != DungeonGen.FLOOR:
				continue
			var px := (float(x) - cx) * TILE_PX + size.x * 0.5
			var py := (float(y) - cy) * TILE_PX + size.y * 0.5
			draw_rect(Rect2(px, py, TILE_PX + 0.5, TILE_PX + 0.5), Color(0.42, 0.44, 0.52))
	_mark(data, visited, cx, cy, "crystal", Color(0.45, 0.85, 0.9))
	_mark(data, visited, cx, cy, "stairs", Color(0.95, 0.82, 0.28))
	draw_circle(size * 0.5, 3.0, Color(0.95, 0.85, 0.3))
	_border()


func _mark(data: Dictionary, visited: PackedByteArray, cx: float, cy: float, key: String, col: Color) -> void:
	if not data.has(key):
		return
	var t: Vector2i = data[key]
	if t.x < 0 or t.y < 0 or t.x >= data.w or t.y >= data.h:
		return
	if visited[t.x + t.y * DungeonGen.W] == 0:
		return
	var px := (float(t.x) - cx) * TILE_PX + size.x * 0.5
	var py := (float(t.y) - cy) * TILE_PX + size.y * 0.5
	draw_rect(Rect2(px, py, TILE_PX + 0.5, TILE_PX + 0.5), col)


func _border() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), BORDER, false, 2.0)
