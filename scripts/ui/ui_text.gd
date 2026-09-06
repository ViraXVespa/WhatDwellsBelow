extends Object

const T := preload("res://scripts/data/tunables.gd")


static func default_floor() -> float:
	return T.UI_TEXT_FLOOR


static func clamp_floor(v: float) -> float:
	return clampf(v, T.UI_TEXT_FLOOR_MIN, T.UI_TEXT_FLOOR_MAX)


static func applied() -> float:
	if App.has_method("ui_text_applied"):
		return App.ui_text_applied()
	return T.UI_TEXT_SCALE_MIN


static func font_px(size: int) -> int:
	return maxi(1, int(round(float(size) * applied())))


static func min_size(w: float, h: float) -> Vector2:
	var sc: float = applied()
	return Vector2(w * sc, h * sc)


static func compute(floor_px: float) -> float:
	var win: Vector2i = DisplayServer.window_get_size()
	var vp: Vector2 = _vp_size()
	var sx: float = float(win.x) / maxf(vp.x, 1.0)
	var sy: float = float(win.y) / maxf(vp.y, 1.0)
	var spd: float = minf(sx, sy)
	var design_px: float = T.UI_TEXT_REF * spd
	if design_px <= 0.001:
		return T.UI_TEXT_SCALE_MIN
	return clampf(floor_px / design_px, T.UI_TEXT_SCALE_MIN, T.UI_TEXT_SCALE_MAX)


static func refresh() -> void:
	App.ui_text_floor = clamp_floor(float(App.ui_text_floor))
	App.ui_text_scale = compute(App.ui_text_floor)


static func _vp_size() -> Vector2:
	var loop := Engine.get_main_loop()
	if loop == null:
		return Vector2(1920, 1080)
	var tree := loop as SceneTree
	if tree == null or tree.root == null:
		return Vector2(1920, 1080)
	return tree.root.get_visible_rect().size
