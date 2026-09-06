extends MeshInstance3D

const T := preload("res://scripts/data/tunables.gd")
const BOW_Y := 1.08
const GROUND_Y := 0.06

var mat: StandardMaterial3D


func _ready() -> void:
	var box := BoxMesh.new()
	box.size = Vector3(1.0, 0.02, 1.0)
	mesh = box
	mat = StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	mat.no_depth_test = true
	mat.albedo_color = Color(1.0, 0.92, 0.55, 0.85)
	material_override = mat
	cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF


func update_line(origin: Vector3, dir: Vector2, length: float, width: float, opacity: float, on: bool) -> void:
	visible = on and length > 0.05
	if not visible:
		return
	var d := dir
	if d.length_squared() < 0.0001:
		d = Vector2.DOWN
	d = d.normalized()
	var mid := origin + Vector3(d.x, 0.0, d.y) * (length * 0.5)
	var y := BOW_Y if App.weapon == "longbow" else GROUND_Y
	global_position = Vector3(mid.x, y, mid.z)
	rotation = Vector3(0.0, -atan2(d.y, d.x), 0.0)
	scale = Vector3(length, 1.0, width)
	if mat:
		mat.albedo_color.a = clampf(opacity, 0.05, 1.0)
