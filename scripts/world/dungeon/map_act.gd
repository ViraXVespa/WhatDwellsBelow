extends RefCounted

## Large floor-map zoom / pan. World camera is LookCtrl; this only moves map_rect.
## map_rect lives inside map_clip, so its position is clip-local. Focus arguments stay in viewport space.

const T := preload("res://scripts/data/tunables.gd")
const MapView := preload("res://scripts/world/dungeon/minimap_view.gd")
const ZOOM_MAX := T.MAP_ZOOM_MAX
const FRAME_PAD := 96.0
const FRAME_CAP := 800.0

static var _drag := false
static var _drag_at := Vector2.ZERO

static func is_open(host: Node) -> bool:
	if host == null:
		return false
	var layer: CanvasLayer = host.get("map_layer") as CanvasLayer
	return layer != null and layer.visible

static func reset(host: Node) -> void:
	_drag = false
	if host == null:
		return
	_set_z(host, MapView.reveal_zoom(host))
	apply(host)
	_center_seen(host)

static func apply(host: Node) -> void:
	if host == null or host.get("map_rect") == null or host.get("data") == null:
		return
	var rect: TextureRect = host.map_rect
	var w: float = maxf(float(host.data.w), 1.0)
	var h: float = maxf(float(host.data.h), 1.0)
	var frame: Rect2 = _frame(host)
	_place_chrome(host, frame)
	var z: float = _z(host)
	var fit: float = minf(frame.size.x / w, frame.size.y / h)
	var cell: float = fit * z
	rect.stretch_mode = TextureRect.STRETCH_SCALE
	rect.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	rect.size = Vector2(w, h) * cell
	if z <= 1.001:
		rect.position = (frame.size - rect.size) * 0.5
	_clamp(host, frame)
	var alpha: float = MapView.full_alpha()
	rect.modulate.a = alpha
	var edge: ColorRect = host.get("map_border") as ColorRect
	if edge:
		edge.modulate.a = alpha

static func zoom_at(host: Node, gain: float, focus: Vector2) -> void:
	if not is_open(host) or host.get("map_rect") == null:
		return
	var rect: TextureRect = host.map_rect
	var frame: Rect2 = _frame(host)
	var z0: float = _z(host)
	var z1: float = clampf(z0 * gain, T.MAP_ZOOM_MIN, ZOOM_MAX)
	if absf(z1 - z0) < 0.0001:
		return
	var local_focus: Vector2 = focus - frame.position
	var u: Vector2 = Vector2.ZERO
	if rect.size.x > 0.001 and rect.size.y > 0.001:
		u = (local_focus - rect.position) / rect.size
	_set_z(host, z1)
	apply(host)
	rect = host.map_rect
	rect.position = local_focus - u * rect.size
	_clamp(host, _frame(host))

static func zoom_player(host: Node, delta_z: float) -> void:
	if not is_open(host):
		return
	var z0: float = _z(host)
	var z1: float = clampf(z0 + delta_z, T.MAP_ZOOM_MIN, ZOOM_MAX)
	if absf(z1 - z0) < 0.0001:
		return
	zoom_at(host, z1 / z0, _player_focus(host))

static func pan_by(host: Node, delta: Vector2) -> void:
	if not is_open(host) or host.get("map_rect") == null:
		return
	if _z(host) <= 1.001:
		apply(host)
		return
	var rect: TextureRect = host.map_rect
	rect.position = rect.position + delta
	_clamp(host, _frame(host))

static func handle_mouse(host: Node, event: InputEvent) -> bool:
	if not is_open(host):
		_drag = false
		return false
	if event is InputEventMouseButton:
		var b: InputEventMouseButton = event as InputEventMouseButton
		if b.button_index != MOUSE_BUTTON_LEFT:
			return false
		if b.pressed and _z(host) > 1.001:
			_drag = true
			_drag_at = _local_ptr(host, b)
			return true
		if _drag and not b.pressed:
			_drag = false
			return true
		return false
	if event is InputEventMouseMotion and _drag:
		var m: InputEventMouseMotion = event as InputEventMouseMotion
		var at: Vector2 = _local_ptr(host, m)
		pan_by(host, at - _drag_at)
		_drag_at = at
		return true
	return false

static func _z(host: Node) -> float:
	return float(host.get_meta("map_zoom", 1.0))

static func _set_z(host: Node, z: float) -> void:
	host.set_meta("map_zoom", clampf(z, T.MAP_ZOOM_MIN, ZOOM_MAX))

static func _frame(host: Node) -> Rect2:
	var vp: Vector2 = host.get_viewport().get_visible_rect().size
	var side: float = minf(FRAME_CAP, minf(vp.x, vp.y) - FRAME_PAD)
	side = maxf(side, 160.0)
	var pos: Vector2 = (vp - Vector2(side, side)) * 0.5
	return Rect2(pos, Vector2(side, side))

static func _place_chrome(host: Node, frame: Rect2) -> void:
	var border: float = T.MINI_BORDER
	var clip: Control = host.get("map_clip") as Control
	if clip:
		clip.position = frame.position
		clip.size = frame.size
	var edge: ColorRect = host.get("map_border") as ColorRect
	if edge:
		edge.position = frame.position - Vector2(border, border)
		edge.size = frame.size + Vector2(border, border) * 2.0
	var shade: Control = host.get("map_shade") as Control
	if shade == null or shade.get_child_count() < 4:
		return
	var vp: Vector2 = host.get_viewport().get_visible_rect().size
	var top: ColorRect = shade.get_child(0) as ColorRect
	var bottom: ColorRect = shade.get_child(1) as ColorRect
	var left: ColorRect = shade.get_child(2) as ColorRect
	var right: ColorRect = shade.get_child(3) as ColorRect
	top.position = Vector2.ZERO
	top.size = Vector2(vp.x, maxf(frame.position.y, 0.0))
	bottom.position = Vector2(0.0, frame.end.y)
	bottom.size = Vector2(vp.x, maxf(vp.y - frame.end.y, 0.0))
	left.position = Vector2(0.0, frame.position.y)
	left.size = Vector2(maxf(frame.position.x, 0.0), frame.size.y)
	right.position = Vector2(frame.end.x, frame.position.y)
	right.size = Vector2(maxf(vp.x - frame.end.x, 0.0), frame.size.y)

static func _clamp(host: Node, frame: Rect2) -> void:
	var rect: TextureRect = host.map_rect
	var pos: Vector2 = rect.position
	if rect.size.x <= frame.size.x:
		pos.x = (frame.size.x - rect.size.x) * 0.5
	else:
		pos.x = clampf(pos.x, frame.size.x - rect.size.x, 0.0)
	if rect.size.y <= frame.size.y:
		pos.y = (frame.size.y - rect.size.y) * 0.5
	else:
		pos.y = clampf(pos.y, frame.size.y - rect.size.y, 0.0)
	rect.position = pos

static func _center_seen(host: Node) -> void:
	var rect: TextureRect = host.get("map_rect") as TextureRect
	if rect == null or host.get("data") == null:
		return
	var frame: Rect2 = _frame(host)
	var seen: Vector2 = MapView.seen_center(host)
	if seen.x < 0.0:
		rect.position = (frame.size - rect.size) * 0.5
		_clamp(host, frame)
		return
	var w: float = maxf(float(host.data.w), 1.0)
	var h: float = maxf(float(host.data.h), 1.0)
	var cell_x: float = rect.size.x / w
	var cell_y: float = rect.size.y / h
	rect.position = frame.size * 0.5 - Vector2(seen.x * cell_x, seen.y * cell_y)
	_clamp(host, frame)

static func _player_focus(host: Node) -> Vector2:
	var frame: Rect2 = _frame(host)
	var mid: Vector2 = frame.position + frame.size * 0.5
	var p: Node3D = host.get("player") as Node3D
	var rect: TextureRect = host.get("map_rect") as TextureRect
	if p == null or rect == null or host.get("data") == null:
		return mid
	var w: float = maxf(float(host.data.w), 1.0)
	var h: float = maxf(float(host.data.h), 1.0)
	var u: Vector2 = Vector2((p.global_position.x + 0.5) / w, (p.global_position.z + 0.5) / h)
	return frame.position + rect.position + Vector2(u.x * rect.size.x, u.y * rect.size.y)

static func _local_ptr(host: Node, event: InputEvent) -> Vector2:
	var clip: Control = host.get("map_clip") as Control
	if clip == null:
		return event.position
	return event.global_position - clip.global_position
