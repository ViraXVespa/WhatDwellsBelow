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
	_look()


func _pitch() -> float:
	if App.bal:
		return App.bal.cam_pitch
	return T.CAM_PITCH


func _height() -> float:
	if App.bal:
		return App.bal.cam_height
	return T.CAM_HEIGHT


func _lift() -> float:
	if App.bal:
		return App.bal.look_lift
	return T.LOOK_LIFT


func _look() -> void:
	var look := global_position + Vector3(0.0, _lift(), 0.0)
	if cam and cam.global_position.distance_squared_to(look) > 0.0001:
		cam.look_at(look, Vector3.UP)


func _place_local() -> void:
	var h := _height()
	var back := h / tan(deg_to_rad(absf(_pitch())))
	cam.position = Vector3(0.0, h, back)


func apply_zoom(z: float) -> void:
	if cam == null:
		return
	var zoom := clampf(z, T.ZOOM_MIN, T.ZOOM_MAX)
	cam.size = 1080.0 / T.PX / zoom


func follow(target: Vector3) -> void:
	global_position = target
	_place_local()
	_look()