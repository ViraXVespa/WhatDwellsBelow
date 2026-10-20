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
