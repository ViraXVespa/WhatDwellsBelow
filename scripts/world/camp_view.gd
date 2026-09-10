extends Object

const FENCE_TEX := "res://assets/sprites/props/fence.png"
const GROUND_W := 36
const GROUND_D := 32
const GROUND_OX := -2
const GROUND_OZ := -2


static func fence(host: Node3D) -> void:
	var y: float = 0.58
	var h: float = 1.05
	var t: float = 0.22
	fence_run(host, Vector3(16.0, y, float(GROUND_OZ) + 0.08), Vector3(float(GROUND_W), h, t), true)
	fence_run(host, Vector3(16.0, y, float(GROUND_OZ + GROUND_D) - 0.08), Vector3(float(GROUND_W), h, t), true)
	fence_run(host, Vector3(float(GROUND_OX) + 0.08, y, 14.0), Vector3(t, h, float(GROUND_D)), false)
	fence_run(host, Vector3(float(GROUND_OX + GROUND_W) - 0.08, y, 14.0), Vector3(t, h, float(GROUND_D)), false)


static func fence_run(host: Node3D, pos: Vector3, size: Vector3, along_x: bool) -> void:
	var body := StaticBody3D.new()
	body.collision_layer = 1
	body.position = pos
	host.add_child(body)
	var cs := CollisionShape3D.new()
	var sh := BoxShape3D.new()
	sh.size = size
	cs.shape = sh
	body.add_child(cs)
	var span: float = size.x if along_x else size.z
	var n: int = maxi(2, int(round(span / 2.0)) + 1)
	var wood: StandardMaterial3D = fence_mat()
	var rail_len: float = span - 0.2
	fence_box(body, fence_rail_size(along_x, rail_len, 0.1, 0.12), Vector3(0.0, -0.12, 0.0), wood)
	fence_box(body, fence_rail_size(along_x, rail_len, 0.1, 0.12), Vector3(0.0, 0.22, 0.0), wood)
	for i in n:
		var u: float = 0.0 if n <= 1 else (float(i) / float(n - 1)) - 0.5
		var off: float = u * (span - 0.2)
		var ppos: Vector3 = Vector3(off, 0.02, 0.0) if along_x else Vector3(0.0, 0.02, off)
		fence_box(body, Vector3(0.18, size.y, 0.18), ppos, wood)


static func fence_rail_size(along_x: bool, length: float, thick: float, tall: float) -> Vector3:
	if along_x:
		return Vector3(length, tall, thick)
	return Vector3(thick, tall, length)


static func fence_box(host: Node3D, size: Vector3, local: Vector3, mat: StandardMaterial3D) -> void:
	var vis := MeshInstance3D.new()
	var box_mesh := BoxMesh.new()
	box_mesh.size = size
	vis.mesh = box_mesh
	vis.position = local
	vis.material_override = mat
	vis.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	host.add_child(vis)


static func fence_mat() -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	mat.albedo_color = Color(0.45, 0.32, 0.2)
	if ResourceLoader.exists(FENCE_TEX):
		mat.albedo_texture = load(FENCE_TEX)
		mat.albedo_color = Color.WHITE
	return mat
