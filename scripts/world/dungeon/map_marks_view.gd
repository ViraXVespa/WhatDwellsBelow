extends Control

## Draws map_marks.gd's list over one map TextureRect (HUD minimap or full map). region is the uv window that
## rect shows. Marker size follows the on-screen cell size, clamped, so shapes stay readable at every zoom.
## Each kind has its own shape (colour-blind safe); colours echo the world sprites.

enum { ENEMY, ELITE, BOSS, GOLD, HP, MANA, ITEM, ITEM_BLUE, ITEM_GREEN, CHEST, POT, GATE, SHOP, SHRINE, CAMPFIRE, ORE, WOOD, QUEST, LEVER }
enum { TRI, CIRCLE, DIAMOND, SQUARE, BOX, RING, HDIAMOND, PLUS, CROSS }

const R_MIN := 4.5
const R_MAX := 16.0
const EDGE := Color(0.02, 0.02, 0.03, 0.9)
const LIGHT := Color(1.0, 0.95, 0.85, 1.0)
## kind: [shape, colour, size, light edge]
const STYLE := {
	ENEMY: [TRI, Color(0.95, 0.3, 0.25), 1.0, false],
	ELITE: [TRI, Color(1.0, 0.6, 0.15), 1.25, true],
	BOSS: [TRI, Color(0.95, 0.25, 0.85), 1.6, true],
	GOLD: [CIRCLE, Color(1.0, 0.85, 0.25), 0.7, false],
	HP: [CIRCLE, Color(0.95, 0.35, 0.45), 0.7, false],
	MANA: [CIRCLE, Color(0.35, 0.6, 1.0), 0.7, false],
	ITEM: [DIAMOND, Color(0.92, 0.88, 0.75), 0.9, false],
	ITEM_BLUE: [DIAMOND, Color(0.45, 0.7, 1.0), 0.9, false],
	ITEM_GREEN: [DIAMOND, Color(0.45, 0.9, 0.5), 0.9, false],
	CHEST: [SQUARE, Color(0.85, 0.6, 0.25), 0.9, false],
	POT: [BOX, Color(0.78, 0.68, 0.52), 0.7, false],
	GATE: [RING, Color(0.95, 0.82, 0.35), 1.1, false],
	SHOP: [HDIAMOND, Color(0.55, 0.85, 1.0), 1.0, false],
	SHRINE: [PLUS, Color(0.75, 0.55, 1.0), 1.0, false],
	CAMPFIRE: [PLUS, Color(1.0, 0.55, 0.2), 1.0, false],
	ORE: [CROSS, Color(0.72, 0.74, 0.8), 0.7, false],
	WOOD: [CROSS, Color(0.45, 0.78, 0.4), 0.7, false],
	QUEST: [RING, Color(1.0, 1.0, 1.0), 0.9, false],
	LEVER: [RING, Color(0.7, 0.7, 0.75), 0.6, false],
}

var host: Node = null
var region := Rect2(0, 0, 1, 1)

func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED:
		queue_redraw()

func _draw() -> void:
	if host == null or not is_instance_valid(host) or host.get("data") == null or region.size.x <= 0.0:
		return
	var w: float = maxf(float(host.data.w), 1.0)
	var h: float = maxf(float(host.data.h), 1.0)
	var r: float = clampf(size.x / (w * region.size.x) * 0.55, R_MIN, R_MAX)
	for e: Variant in host.get_meta("map_mark_list", []):
		var at: Vector2 = e[0]
		var p: Vector2 = (Vector2(at.x / w, at.y / h) - region.position) / region.size * size
		if p.x < -r or p.y < -r or p.x > size.x + r or p.y > size.y + r:
			continue
		_shape(p, r, int(e[1]))

func _shape(p: Vector2, r: float, kind: int) -> void:
	var st: Array = STYLE.get(kind, STYLE[ENEMY])
	var col: Color = st[1]
	var s: float = r * float(st[2])
	var edge: Color = LIGHT if bool(st[3]) else EDGE
	match int(st[0]):
		TRI:
			_poly([p + Vector2(0, -s), p + Vector2(s * 0.95, s * 0.8), p + Vector2(-s * 0.95, s * 0.8)], col, edge)
		DIAMOND:
			_poly([p + Vector2(0, -s), p + Vector2(s * 0.8, 0), p + Vector2(0, s), p + Vector2(-s * 0.8, 0)], col, edge)
		SQUARE:
			var q: float = s * 0.8
			_poly([p + Vector2(-q, -q), p + Vector2(q, -q), p + Vector2(q, q), p + Vector2(-q, q)], col, edge)
		CIRCLE:
			draw_circle(p, s + 1.0, edge)
			draw_circle(p, s, col)
		BOX:
			var b := Rect2(p - Vector2(s, s) * 0.75, Vector2(s, s) * 1.5)
			draw_rect(b, edge, false, 3.0)
			draw_rect(b, col, false, 1.5)
		RING:
			draw_arc(p, s * 0.75, 0.0, TAU, 20, edge, maxf(2.5, s * 0.6))
			draw_arc(p, s * 0.75, 0.0, TAU, 20, col, maxf(1.5, s * 0.35))
		HDIAMOND:
			var d := PackedVector2Array([p + Vector2(0, -s), p + Vector2(s * 0.8, 0), p + Vector2(0, s), p + Vector2(-s * 0.8, 0), p + Vector2(0, -s)])
			draw_polyline(d, edge, 3.0)
			draw_polyline(d, col, 1.5)
		PLUS:
			_bar(p, Vector2(s, s * 0.3), col, edge)
			_bar(p, Vector2(s * 0.3, s), col, edge)
			draw_rect(Rect2(p - Vector2(s, s * 0.3), Vector2(s, s * 0.3) * 2.0), col)
		CROSS:
			var a: float = s * 0.75
			for seg: Array in [[Vector2(-a, -a), Vector2(a, a)], [Vector2(a, -a), Vector2(-a, a)]]:
				draw_line(p + seg[0], p + seg[1], edge, 3.0)
			for seg: Array in [[Vector2(-a, -a), Vector2(a, a)], [Vector2(a, -a), Vector2(-a, a)]]:
				draw_line(p + seg[0], p + seg[1], col, 1.5)

func _poly(pts: Array, col: Color, edge: Color) -> void:
	var a := PackedVector2Array(pts)
	draw_colored_polygon(a, col)
	a.append(a[0])
	draw_polyline(a, edge, 1.25)

func _bar(p: Vector2, half: Vector2, col: Color, edge: Color) -> void:
	draw_rect(Rect2(p - half - Vector2.ONE, half * 2.0 + Vector2(2, 2)), edge)
	draw_rect(Rect2(p - half, half * 2.0), col)
