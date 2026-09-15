extends Object

## Shared tip host placement helpers (design/reuse-map.md BOT-06).
## Callers keep their own tip text; this only places geometry.


static func defer_next_frame(tree: SceneTree, cb: Callable) -> void:
	if tree == null:
		return
	tree.process_frame.connect(cb, CONNECT_ONE_SHOT)


static func clamp_pos(pos: Vector2, sz: Vector2, view: Vector2, margin: float = 16.0) -> Vector2:
	var out := pos
	out.x = clampf(out.x, margin, view.x - sz.x - margin)
	out.y = clampf(out.y, margin, view.y - maxf(sz.y, 80.0) - margin)
	return out


## Prefer below the anchor; flip above if the tip would cross footer_top.
static func place_flip_below(
	host: Control,
	anchor: Rect2,
	footer_top: float,
	width: float,
	gap: float = 8.0,
	x_min: float = 20.0,
	x_max: float = 1900.0,
) -> void:
	var h: float = host.size.y
	if h <= 0.0:
		h = host.get_combined_minimum_size().y
	var below: float = anchor.position.y + anchor.size.y + gap
	var above: float = anchor.position.y - h - gap
	var pos := Vector2(anchor.position.x + anchor.size.x - width, below)
	if below + h > footer_top:
		pos.y = above
	if pos.x + width > x_max:
		pos.x = x_max - width
	if pos.x < x_min:
		pos.x = x_min
	host.position = pos
