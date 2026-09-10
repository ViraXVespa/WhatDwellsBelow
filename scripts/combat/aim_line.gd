extends Node3D

const BOW_Y := 1.08
const GROUND_Y := 0.06
const CLIP := 0.52
const FADE := 0.22

var mesh_i: MeshInstance3D
var mat: ShaderMaterial
var col: Color = Color(1.0, 0.92, 0.55, 0.85)


func _ready() -> void:
	mesh_i = MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = Vector3(1.0, 0.02, 1.0)
	mesh_i.mesh = box
	mat = ShaderMaterial.new()
	mat.shader = _shader()
	mat.set_shader_parameter("col", col)
	mat.set_shader_parameter("fade", FADE)
	mesh_i.material_override = mat
	mesh_i.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mesh_i.sorting_offset = 256.0
	add_child(mesh_i)


func _shader() -> Shader:
	var sh := Shader.new()
	sh.code = """
shader_type spatial;
render_mode unshaded, cull_disabled, depth_test_disabled;
uniform vec4 col : source_color = vec4(1.0, 0.92, 0.55, 0.85);
uniform float fade = 0.22;
varying float along;
void vertex() {
	along = VERTEX.x + 0.5;
}
void fragment() {
	float a = smoothstep(0.0, max(fade, 0.001), along) * col.a;
	ALBEDO = col.rgb;
	ALPHA = a;
}
"""
	return sh


func update_line(origin: Vector3, dir: Vector2, length: float, width: float, opacity: float, on: bool) -> void:
	var usable: float = length - CLIP
	visible = on and usable > 0.05
	if not visible:
		return
	var d: Vector2 = dir
	if d.length_squared() < 0.0001:
		d = Vector2.DOWN
	d = d.normalized()
	var start: Vector3 = origin + Vector3(d.x, 0.0, d.y) * CLIP
	var mid: Vector3 = start + Vector3(d.x, 0.0, d.y) * (usable * 0.5)
	var y: float = BOW_Y if App.weapon == "longbow" else GROUND_Y
	global_position = Vector3(mid.x, y, mid.z)
	rotation = Vector3(0.0, -atan2(d.y, d.x), 0.0)
	scale = Vector3(usable, 1.0, width)
	col.a = clampf(opacity, 0.05, 1.0)
	if mat:
		mat.set_shader_parameter("col", col)
		mat.set_shader_parameter("fade", FADE)
