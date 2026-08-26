extends Node3D

var mesh_i: MeshInstance3D
var life := 0.0
var active := false


func _ready() -> void:
	mesh_i = MeshInstance3D.new()
	add_child(mesh_i)
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	m.no_depth_test = true
	m.albedo_color = Color(1.0, 0.82, 0.28, 0.42)
	mesh_i.material_override = m


func set_color(c: Color) -> void:
	if mesh_i and mesh_i.material_override:
		(mesh_i.material_override as StandardMaterial3D).albedo_color = c


func show_arc(origin: Vector3, dir: Vector2, dist: float, arc_deg: float, col: Color) -> void:
	global_position = Vector3(origin.x, 0.04, origin.z)
	set_color(col)
	mesh_i.mesh = _fan(dir, dist, arc_deg, 18)
	visible = true


func show_circle(origin: Vector3, radius: float, col: Color) -> void:
	global_position = Vector3(origin.x, 0.04, origin.z)
	set_color(col)
	mesh_i.mesh = _fan(Vector2.RIGHT, radius, 360.0, 28)
	visible = true


func show_cone(origin: Vector3, dir: Vector2, dist: float, cone_deg: float, col: Color) -> void:
	show_arc(origin, dir, dist, cone_deg, col)


func hide_now() -> void:
	visible = false


func _fan(dir: Vector2, dist: float, arc_deg: float, segs: int) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var base := 0.0
	if dir.length_squared() > 0.0001:
		base = atan2(dir.y, dir.x)
	var half := deg_to_rad(arc_deg * 0.5)
	var n := maxi(3, segs)
	for i in n:
		var a0 := base - half + (float(i) / float(n)) * half * 2.0
		var a1 := base - half + (float(i + 1) / float(n)) * half * 2.0
		st.add_vertex(Vector3.ZERO)
		st.add_vertex(Vector3(cos(a0) * dist, 0.0, sin(a0) * dist))
		st.add_vertex(Vector3(cos(a1) * dist, 0.0, sin(a1) * dist))
	return st.commit()
