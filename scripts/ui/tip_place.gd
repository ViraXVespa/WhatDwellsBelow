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

## Put a popup panel beside its source control (right, else left), top-aligned with it, clamped on screen.
## Runs a frame later so the panel has its real size. A missing source leaves the panel where it is.
static func near(panel: Control, src: Control, gap: float = 12.0) -> void:
	if panel == null or src == null or not is_instance_valid(src) or not src.is_inside_tree():
		return
	var src_r: Rect2 = src.get_global_rect()
	defer_next_frame(panel.get_tree(), func():
		if not is_instance_valid(panel) or not panel.is_inside_tree():
			return
		var view: Vector2 = panel.get_viewport().get_visible_rect().size
		var sz: Vector2 = panel.size.max(panel.get_combined_minimum_size())
		var x: float = src_r.end.x + gap
		if x + sz.x > view.x - 16.0:
			x = src_r.position.x - sz.x - gap
		panel.global_position = clamp_pos(Vector2(x, src_r.position.y), sz, view))
