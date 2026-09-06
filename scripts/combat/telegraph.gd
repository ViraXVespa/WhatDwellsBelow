extends Node3D

var mesh_i: MeshInstance3D
var mat: StandardMaterial3D


func _ready() -> void:
	mesh_i = MeshInstance3D.new()
	mat = StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	mat.no_depth_test = true
	mat.albedo_color = Color(1.0, 0.45, 0.2, 0.45)
	mesh_i.material_override = mat
	mesh_i.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mesh_i)


func set_color(c: Color) -> void:
	if mat:
		mat.albedo_color = c


func show_arc(origin: Vector3, dir: Vector2, dist: float, arc_deg: float, col: Color) -> void:
	global_position = Vector3(origin.x, 0.04, origin.z)
	set_color(col)
	mesh_i.mesh = _fan(dir, dist, arc_deg, 14)
	visible = true


func show_circle(origin: Vector3, radius: float, col: Color) -> void:
	show_arc(origin, Vector2.DOWN, radius, 360.0, col)


func show_cone(origin: Vector3, dir: Vector2, dist: float, cone_deg: float, col: Color) -> void:
	show_arc(origin, dir, dist, cone_deg, col)


func show_line(origin: Vector3, dir: Vector2, dist: float, width: float, col: Color) -> void:
	global_position = Vector3(origin.x, 0.04, origin.z)
	set_color(col)
	mesh_i.mesh = _strip(dir, dist, width)
	visible = true


func show_spread(origin: Vector3, dir: Vector2, dist: float, cone_deg: float, count: int, width: float, col: Color) -> void:
	global_position = Vector3(origin.x, 0.04, origin.z)
	set_color(col)
	var n := maxi(1, count)
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var base := dir.normalized() if dir.length_squared() > 0.0001 else Vector2.DOWN
	var cone := deg_to_rad(maxf(1.0, cone_deg))
	var yaw := atan2(base.y, base.x)
	for i in n:
		var t := 0.0 if n <= 1 else (float(i) / float(n - 1)) - 0.5
		var a := yaw + t * cone
		var d := Vector2(cos(a), sin(a))
		_strip_into(st, d, dist, width)
	st.set_material(mat)
	mesh_i.mesh = st.commit()
	visible = true


func hide_now() -> void:
	visible = false


func _fan(dir: Vector2, dist: float, arc_deg: float, segs: int) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var d := dir.normalized() if dir.length_squared() > 0.0001 else Vector2.DOWN
	var base := atan2(d.y, d.x)
	var half := deg_to_rad(arc_deg * 0.5)
	var n := maxi(3, segs)
	for i in n:
		var a0 := base - half + (float(i) / float(n)) * half * 2.0
		var a1 := base - half + (float(i + 1) / float(n)) * half * 2.0
		st.set_color(mat.albedo_color)
		st.add_vertex(Vector3.ZERO)
		st.add_vertex(Vector3(cos(a0) * dist, 0.0, sin(a0) * dist))
		st.add_vertex(Vector3(cos(a1) * dist, 0.0, sin(a1) * dist))
	return st.commit()


func _strip(dir: Vector2, dist: float, width: float) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	_strip_into(st, dir, dist, width)
	return st.commit()


func _strip_into(st: SurfaceTool, dir: Vector2, dist: float, width: float) -> void:
	var d := dir.normalized() if dir.length_squared() > 0.0001 else Vector2.DOWN
	var n := Vector2(-d.y, d.x) * (maxf(0.04, width) * 0.5)
	var a := Vector3(-n.x, 0.0, -n.y)
	var b := Vector3(n.x, 0.0, n.y)
	var c := Vector3(d.x * dist + n.x, 0.0, d.y * dist + n.y)
	var e := Vector3(d.x * dist - n.x, 0.0, d.y * dist - n.y)
	st.set_color(mat.albedo_color)
	st.add_vertex(a)
	st.add_vertex(b)
	st.add_vertex(c)
	st.add_vertex(a)
	st.add_vertex(c)
	st.add_vertex(e)
