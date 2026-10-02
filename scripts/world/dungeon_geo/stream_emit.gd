extends Object

## Dungeon stream mesh emit: wall mesh, floors, floor lip, ribbon boxes. Owns the shared floor plane.

const T := preload("res://scripts/data/tunables.gd")
const WallMesh: GDScript = preload("res://scripts/graphics/wall_mesh.gd")
const Commit := preload("res://scripts/graphics/mesh_commit.gd")

static var _floor_mesh: PlaneMesh

static func ensure_meshes() -> void:
	if _floor_mesh == null:
		_floor_mesh = PlaneMesh.new()
		_floor_mesh.size = Vector2(T.TILE, T.TILE)

static func _ensure_wall_mesh(host: Node, runs: Array = [], fine_m: float = 1.0) -> MeshInstance3D:
	if runs.is_empty():
		return null
	var typed: Array[Dictionary] = []
	for item in runs:
		if item is Dictionary:
			typed.append(item)
	if typed.is_empty():
		return null
	var wall_inst: MeshInstance3D = MeshInstance3D.new()
	wall_inst.name = "WallRibbons"
	wall_inst.mesh = WallMesh.from_faces(typed)
	var scale_m: float = fine_m
	if scale_m < 0.2:
		scale_m = 1.0
	wall_inst.scale = Vector3(scale_m, 1.0, scale_m)
	wall_inst.material_override = host.wall_mat
	wall_inst.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return wall_inst
static func _mask(host: Node) -> Dictionary:
	var w: int = int(host.data.w)
	var h: int = int(host.data.h)
	if host.data.has("solid") and host.data["solid"] is PackedByteArray:
		var fine: float = float(host.data.get("outline_fine_m", 0.25))
		if fine < 0.2:
			fine = 0.25
		return {
			"solid": host.data["solid"],
			"sw": int(host.data["solid_w"]),
			"sh": int(host.data["solid_h"]),
			"n": maxi(1, int(host.data["solid_n"])),
			"fine": fine,
		}
	return {"solid": host.data.grid, "sw": w, "sh": h, "n": 1, "fine": 1.0}

static func _emit_floors(rects: Array[Rect2i], fine_m: float, mat: Material) -> MultiMeshInstance3D:
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.mesh = _floor_mesh
	mm.instance_count = rects.size()
	for i in rects.size():
		var r: Rect2i = rects[i]
		var sx: float = float(r.size.x) * fine_m
		var sz: float = float(r.size.y) * fine_m
		var basis := Basis(Vector3(sx, 0.0, 0.0), Vector3(0.0, 1.0, 0.0), Vector3(0.0, 0.0, sz))
		var at := Vector3((float(r.position.x) + float(r.size.x) * 0.5) * fine_m, T.FLOOR_Y, (float(r.position.y) + float(r.size.y) * 0.5) * fine_m)
		mm.set_instance_transform(i, Transform3D(basis, at))
	var inst := MultiMeshInstance3D.new()
	inst.multimesh = mm
	if mat:
		inst.material_override = mat
	return inst

static func _first_mm(node: Node) -> MultiMeshInstance3D:
	for child in node.get_children():
		if child is MultiMeshInstance3D:
			return child as MultiMeshInstance3D
	return null

static func _emit_floor_lip(spans: Array, x0: int, y0: int, x1: int, y1: int, fine_m: float, mat: Material) -> Node3D:
	var holder: Node3D = Node3D.new()
	holder.name = "Floors"
	var loops: Array = spans
	var box: PackedVector2Array = PackedVector2Array()
	var grow: float = 1.0
	box.append(Vector2(float(x0) - grow, float(y0) - grow))
	box.append(Vector2(float(x1) + grow, float(y0) - grow))
	box.append(Vector2(float(x1) + grow, float(y1) + grow))
	box.append(Vector2(float(x0) - grow, float(y1) + grow))
	var pieces: Array = []
	for loop_v in loops:
		var loop: PackedVector2Array = loop_v
		if loop.size() < 3:
			continue
		var clipped: Array = Geometry2D.intersect_polygons(loop, box)
		for poly_v in clipped:
			var poly: PackedVector2Array = poly_v
			if poly.size() >= 3:
				pieces.append(poly)
	if not pieces.is_empty():
		var inst: MeshInstance3D = MeshInstance3D.new()
		inst.mesh = _loop_mesh(pieces, fine_m)
		inst.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		if mat:
			inst.material_override = mat
		holder.add_child(inst)
	return holder

static func _loop_mesh(pieces: Array, fine_m: float) -> ArrayMesh:
	var verts: PackedVector3Array = PackedVector3Array()
	var norms: PackedVector3Array = PackedVector3Array()
	var uvs: PackedVector2Array = PackedVector2Array()
	var indices: PackedInt32Array = PackedInt32Array()
	for piece in pieces:
		var poly: PackedVector2Array = piece as PackedVector2Array
		if poly.size() < 3:
			continue
		var tris: PackedInt32Array = Geometry2D.triangulate_polygon(poly)
		if tris.is_empty():
			poly.reverse()
			tris = Geometry2D.triangulate_polygon(poly)
		if tris.is_empty():
			continue
		var base: int = verts.size()
		for i in poly.size():
			var p: Vector2 = poly[i]
			var x: float = p.x * fine_m
			var z: float = p.y * fine_m
			verts.append(Vector3(x, T.FLOOR_Y, z))
			norms.append(Vector3.UP)
			uvs.append(Vector2(x, z))
		for k in tris.size():
			indices.append(base + int(tris[k]))
	return Commit.commit(verts, norms, uvs, indices)

static func _seg_dist(p: Vector2, o: Vector2, d: Vector2) -> float:
	var l2: float = d.length_squared()
	if l2 < 0.0001:
		return p.distance_to(o)
	var t: float = clampf((p - o).dot(d) / l2, 0.0, 1.0)
	return p.distance_to(o + d * t)

static func _add_ribbon_boxes(root: Node3D, spans: Array, fine_m: float) -> void:
	if spans.is_empty():
		return
	var body: StaticBody3D = StaticBody3D.new()
	body.collision_layer = 1
	body.collision_mask = 0
	root.add_child(body)
	for item in spans:
		if not (item is Dictionary):
			continue
		var run: Dictionary = item
		if not run.has("delta"):
			continue
		var o: Vector2 = run["origin"] as Vector2
		var d: Vector2 = run["delta"] as Vector2
		var span_l: float = d.length()
		if span_l < 0.2:
			continue
		var tangent: Vector2 = d / span_l
		var left: Vector2 = Vector2(-tangent.y, tangent.x)
		var inward: Vector2 = left
		var nrm: Vector2 = run["normal"] as Vector2
		if nrm.length_squared() < 0.0001:
			nrm = left
		else:
			nrm = nrm.normalized()
		if inward.dot(nrm) < 0.0:
			inward = -inward
		var thick: float = float(run.get("thick", 0.25))
		if thick <= 0.0 or thick > 0.3:
			thick = 0.25
		var mid: Vector2 = o + d * 0.5 - inward * (thick * 0.5)
		var basis: Basis = Basis(Vector3(tangent.x, 0.0, tangent.y), Vector3.UP, Vector3(left.x, 0.0, left.y))
		var box: BoxShape3D = BoxShape3D.new()
		box.size = Vector3(span_l * fine_m, T.WALL_H, thick * fine_m)
		var cs: CollisionShape3D = CollisionShape3D.new()
		cs.shape = box
		cs.transform = Transform3D(basis, Vector3(mid.x * fine_m, T.WALL_H * 0.5, mid.y * fine_m))
		body.add_child(cs)
