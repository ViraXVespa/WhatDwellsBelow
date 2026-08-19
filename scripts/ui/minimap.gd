class_name Minimap
extends Control

func _ready() -> void:
	custom_minimum_size = Vector2(220, 160)
	size = Vector2(220, 160)


func refresh() -> void:
	queue_redraw()


func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), Color(0.05, 0.05, 0.08, 0.75))
	if not Game.in_dungeon:
		draw_string(ThemeDB.fallback_font, Vector2(12, 28), "Town", HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color(0.9, 0.85, 0.7))
		return
	var floor := get_tree().current_scene
	if floor == null or floor.get("data") == null:
		return
	var data: Dictionary = floor.data
	if data.is_empty():
		return
	var w: int = data.w
	var h: int = data.h
	var visited: PackedByteArray = floor.fog_visited
	var sx := size.x / float(w)
	var sy := size.y / float(h)
	for y in h:
		for x in w:
			var i: int = x + y * DungeonGen.W
			if visited[i] == 0:
				continue
			var t: int = data.grid[i]
			var col := Color(0.3, 0.32, 0.4) if t == DungeonGen.FLOOR else Color(0.08, 0.08, 0.1)
			draw_rect(Rect2(x * sx, y * sy, sx + 0.5, sy + 0.5), col)
	var p := get_tree().get_first_node_in_group("player") as Node2D
	if p:
		var tx: float = p.position.x / 64.0
		var ty: float = p.position.y / 64.0
		draw_circle(Vector2(tx * sx, ty * sy), 3.0, Color(0.95, 0.85, 0.3))
