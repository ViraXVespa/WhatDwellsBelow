extends Object

## Unified dungeon overlay plate tokens + ColorRect helpers (design/reuse-map.md Kit A / BOT-01).

const DIM := Color(0.03, 0.02, 0.02, 0.82)
const PLATE := Color(0.13, 0.10, 0.08, 0.97)
const EDGE := Color(0.55, 0.42, 0.22, 1)
const EDGE_H := 8


static func dim(parent: Node, color: Color = DIM) -> ColorRect:
	var r := ColorRect.new()
	r.set_anchors_preset(Control.PRESET_FULL_RECT)
	r.color = color
	r.mouse_filter = Control.MOUSE_FILTER_STOP
	parent.add_child(r)
	return r


static func plate(parent: Node, pos: Vector2, size: Vector2, bg: Color = PLATE) -> ColorRect:
	var r := ColorRect.new()
	r.color = bg
	r.position = pos
	r.size = size
	parent.add_child(r)
	return r


static func edge(parent: Node, pos: Vector2, width: float, height: float = float(EDGE_H)) -> ColorRect:
	var r := ColorRect.new()
	r.color = EDGE
	r.position = pos
	r.size = Vector2(width, height)
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(r)
	return r
