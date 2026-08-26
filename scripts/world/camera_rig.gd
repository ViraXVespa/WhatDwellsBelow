extends Node3D

const T := preload("res://scripts/data/tunables.gd")

var cam: Camera3D


func _ready() -> void:
	cam = Camera3D.new()
	cam.name = "Cam"
	add_child(cam)
	cam.projection = Camera3D.PROJECTION_ORTHOGONAL
	cam.keep_aspect = Camera3D.KEEP_HEIGHT
	cam.near = 0.05
	cam.far = 140.0
	cam.current = true
	_place_local()
	apply_zoom(App.cam_zoom)
	var look := global_position + Vector3(0.0, T.LOOK_LIFT, 0.0)
	if cam.global_position.distance_squared_to(look) > 0.0001:
		cam.look_at(look, Vector3.UP)


func _place_local() -> void:
	var back := T.CAM_HEIGHT / tan(deg_to_rad(absf(T.CAM_PITCH)))
	cam.position = Vector3(0.0, T.CAM_HEIGHT, back)


func apply_zoom(z: float) -> void:
	if cam == null:
		return
	var zoom := clampf(z, T.ZOOM_MIN, T.ZOOM_MAX)
	cam.size = 1080.0 / T.PX / zoom


func follow(target: Vector3) -> void:
	global_position = target
	var look := target + Vector3(0.0, T.LOOK_LIFT, 0.0)
	if cam and cam.global_position.distance_squared_to(look) > 0.0001:
		cam.look_at(look, Vector3.UP)


func mouse_aim(origin: Vector3) -> Vector2:
	if cam == null:
		return Vector2.ZERO
	var mouse: Vector2 = cam.get_viewport().get_mouse_position()
	var from := cam.project_ray_origin(mouse)
	var dir := cam.project_ray_normal(mouse)
	if absf(dir.y) < 0.0001:
		return Vector2.ZERO
	var t: float = -from.y / dir.y
	if t < 0.0:
		return Vector2.ZERO
	var hit := from + dir * t
	var d := Vector2(hit.x - origin.x, hit.z - origin.z)
	if d.length_squared() < 0.0004:
		return Vector2.ZERO
	return d.normalized()
