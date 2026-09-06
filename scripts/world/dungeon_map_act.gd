extends RefCounted

## Large floor-map zoom / pan. World camera is LookCtrl; this only moves map_rect.

const ZOOM_MAX := 10.0
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
	_set_z(host, 1.0)
	apply(host)


static func apply(host: Node) -> void:
	if host == null or host.get("map_rect") == null or host.get("data") == null:
		return
	var rect: TextureRect = host.map_rect
	var w := maxf(float(host.data.w), 1.0)
	var h := maxf(float(host.data.h), 1.0)
	var frame := _frame(host)
	var z := _z(host)
	var fit := minf(frame.size.x / w, frame.size.y / h)
	var cell := fit * z
	rect.stretch_mode = TextureRect.STRETCH_SCALE
	rect.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	rect.size = Vector2(w, h) * cell
	if z <= 1.001:
		rect.position = frame.position + (frame.size - rect.size) * 0.5
	_clamp(host, frame)


static func zoom_at(host: Node, gain: float, focus: Vector2) -> void:
	if not is_open(host) or host.get("map_rect") == null:
		return
	var rect: TextureRect = host.map_rect
	var z0 := _z(host)
	var z1 := clampf(z0 * gain, 1.0, ZOOM_MAX)
	if absf(z1 - z0) < 0.0001:
		return
	var u := Vector2.ZERO
	if rect.size.x > 0.001 and rect.size.y > 0.001:
		u = (focus - rect.position) / rect.size
	_set_z(host, z1)
	apply(host)
	rect = host.map_rect
	rect.position = focus - u * rect.size
	_clamp(host, _frame(host))


static func zoom_player(host: Node, delta_z: float) -> void:
	if not is_open(host):
		return
	var z0 := _z(host)
	var z1 := clampf(z0 + delta_z, 1.0, ZOOM_MAX)
	if absf(z1 - z0) < 0.0001:
		return
	zoom_at(host, z1 / z0, _player_focus(host))


static func pan_by(host: Node, delta: Vector2) -> void:
	if not is_open(host) or host.get("map_rect") == null:
		return
	if _z(host) <= 1.001:
		apply(host)
		return
	host.map_rect.position += delta
	_clamp(host, _frame(host))


static func handle_mouse(host: Node, event: InputEvent) -> bool:
	if not is_open(host):
		_drag = false
		return false
	if event is InputEventMouseButton:
		var b := event as InputEventMouseButton
		if b.button_index != MOUSE_BUTTON_LEFT:
			return false
		if b.pressed and _z(host) > 1.001:
			_drag = true
			_drag_at = b.position
			return true
		if _drag and not b.pressed:
			_drag = false
			return true
		return false
	if event is InputEventMouseMotion and _drag:
		var m := event as InputEventMouseMotion
		pan_by(host, m.position - _drag_at)
		_drag_at = m.position
		return true
	return false


static func _z(host: Node) -> float:
	return float(host.get_meta("map_zoom", 1.0))


static func _set_z(host: Node, z: float) -> void:
	host.set_meta("map_zoom", clampf(z, 1.0, ZOOM_MAX))


static func _frame(host: Node) -> Rect2:
	var vp := host.get_viewport().get_visible_rect().size
	var side := minf(FRAME_CAP, minf(vp.x, vp.y) - FRAME_PAD)
	side = maxf(side, 160.0)
	var pos := (vp - Vector2(side, side)) * 0.5
	return Rect2(pos, Vector2(side, side))


static func _clamp(host: Node, frame: Rect2) -> void:
	var rect: TextureRect = host.map_rect
	if rect.size.x <= frame.size.x:
		rect.position.x = frame.position.x + (frame.size.x - rect.size.x) * 0.5
	else:
		rect.position.x = clampf(rect.position.x, frame.end.x - rect.size.x, frame.position.x)
	if rect.size.y <= frame.size.y:
		rect.position.y = frame.position.y + (frame.size.y - rect.size.y) * 0.5
	else:
		rect.position.y = clampf(rect.position.y, frame.end.y - rect.size.y, frame.position.y)


static func _player_focus(host: Node) -> Vector2:
	var frame := _frame(host)
	var mid := frame.position + frame.size * 0.5
	var p: Node3D = host.get("player") as Node3D
	var rect: TextureRect = host.get("map_rect") as TextureRect
	if p == null or rect == null or host.get("data") == null:
		return mid
	var w := maxf(float(host.data.w), 1.0)
	var h := maxf(float(host.data.h), 1.0)
	var u := Vector2((p.global_position.x + 0.5) / w, (p.global_position.z + 0.5) / h)
	return rect.position + Vector2(u.x * rect.size.x, u.y * rect.size.y)
