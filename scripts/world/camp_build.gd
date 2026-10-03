extends Object

const T := preload("res://scripts/data/tunables.gd")
const MeshS := preload("res://scripts/world/camp_build/mesh.gd")
const EnvKit := preload("res://scripts/graphics/env_kit.gd")
const LayoutS := preload("res://scripts/world/camp/layout.gd")
const Util := preload("res://scripts/world/camp_build/build_util.gd")
const Parts := preload("res://scripts/world/camp_build/build_parts.gd")

static func generated(host: Node3D) -> Node3D:
	var n: Node = host.get_node_or_null("Generated")
	if n is Node3D:
		return n as Node3D
	var node: Node3D = Node3D.new()
	node.name = "Generated"
	host.add_child(node)
	return node

static func clear_generated(host: Node3D) -> Node3D:
	var node: Node3D = generated(host)
	for child in node.get_children():
		node.remove_child(child)
		child.free()
	return node

static func realize_editor(host: Node3D, _layout: Node3D) -> void:
	var bucket: Node3D = clear_generated(host)
	ground(bucket)
	buildings(bucket)
	strip_building_cubes(host)
	dump_meshes(host)
	var ViewS: GDScript = load("res://scripts/world/camp/camp_view.gd") as GDScript
	ViewS.fence(bucket)
static func world(host: Node3D) -> void:
	EnvKit.apply(host, Color(0.45, 0.58, 0.62), Color(0.95, 0.86, 0.7), 1.15, Vector3(-18.0, 34.0, -42.0), 0.9)

static func ground(host: Node3D) -> void:
	MeshS.ground(host)

static func outer_grass(host: Node3D) -> void:
	var lay: Node3D = LayoutS.of(host)
	var x0: float = float(lay.ground_ox - lay.grass_pad)
	var z0: float = float(lay.ground_oz - lay.grass_pad)
	var x1: float = float(lay.ground_ox + lay.ground_w + lay.grass_pad)
	var z1: float = float(lay.ground_oz + lay.ground_d + lay.grass_pad)
	var ix0: float = float(lay.ground_ox)
	var iz0: float = float(lay.ground_oz)
	var ix1: float = float(lay.ground_ox + lay.ground_w)
	var iz1: float = float(lay.ground_oz + lay.ground_d)
	var y: float = T.FLOOR_Y
	var tex := "res://assets/tiles/grass_field.png"
	var fb := Color(0.34, 0.46, 0.24)
	MeshS.grass_pad(host, Vector3((x0 + x1) * 0.5, y, (z0 + iz0) * 0.5), Vector2(x1 - x0, iz0 - z0), tex, fb)
	MeshS.grass_pad(host, Vector3((x0 + x1) * 0.5, y, (iz1 + z1) * 0.5), Vector2(x1 - x0, z1 - iz1), tex, fb)
	MeshS.grass_pad(host, Vector3((x0 + ix0) * 0.5, y, (iz0 + iz1) * 0.5), Vector2(ix0 - x0, iz1 - iz0), tex, fb)
	MeshS.grass_pad(host, Vector3((ix1 + x1) * 0.5, y, (iz0 + iz1) * 0.5), Vector2(x1 - ix1, iz1 - iz0), tex, fb)

static func buildings(host: Node3D) -> void:
	Parts.guild(host)
	var lay: Node3D = LayoutS.of(host)
	var stall_at: Vector3 = lay.stall_pos()
	var stall_box: Vector3 = lay.stall_box
	Parts.solid(host, stall_at, stall_box, Color(0.55, 0.35, 0.2), "res://assets/sprites/buildings/stall.png", true)

static func quiet_shadows(host: Node3D) -> void:
	var stack: Array[Node] = [host]
	while stack.size() > 0:
		var n: Node = stack.pop_back()
		if n is DirectionalLight3D:
			var sun := n as DirectionalLight3D
			sun.shadow_enabled = false
		if n is GeometryInstance3D:
			var geo := n as GeometryInstance3D
			geo.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		for c in n.get_children():
			stack.append(c)

static func strip_building_cubes(root: Node) -> int:
	var cut: int = 0
	var stack: Array[Node] = [root]
	while not stack.is_empty():
		var n: Node = stack.pop_back()
		for child in n.get_children():
			stack.append(child)
		var mi := n as MeshInstance3D
		if mi == null or not (mi.mesh is BoxMesh):
			continue
		var sz: Vector3 = (mi.mesh as BoxMesh).size
		print(
			App.tr("camp_build.camp_mesh_box_parent"),
			String(n.get_parent().name) if n.get_parent() else "?",
			" size=",
			sz
		)
		if sz.x < 2.0 or sz.z < 2.0 or sz.y < 1.0:
			continue
		var parent: Node = n.get_parent()
		if parent == null:
			continue
		parent.remove_child(n)
		n.free()
		cut += 1
	print("CAMP_MESH stripped_building_cubes=", cut)
	return cut

static func dump_meshes(root: Node) -> void:
	var stack: Array[Node] = [root]
	var boxes: int = 0
	var sprites: int = 0
	var other: int = 0
	while not stack.is_empty():
		var n: Node = stack.pop_back()
		for child in n.get_children():
			stack.append(child)
		if n is Sprite3D:
			sprites += 1
			var spr := n as Sprite3D
			print("CAMP_MESH sprite parent=", String(n.get_parent().name) if n.get_parent() else "?", " pos=", spr.position, " px=", spr.pixel_size)
			continue
		var mi := n as MeshInstance3D
		if mi == null:
			continue
		if mi.mesh is BoxMesh:
			boxes += 1
			print("CAMP_MESH keep_box parent=", String(n.get_parent().name) if n.get_parent() else "?", " size=", (mi.mesh as BoxMesh).size)
		else:
			other += 1
			print("CAMP_MESH other name=", n.name, " mesh=", mi.mesh.get_class() if mi.mesh else "null")
	print("CAMP_MESH totals boxes=", boxes, " sprites=", sprites, " other=", other)

static func stamp_actor_blobs(host: Node3D) -> void:
	if host == null:
		return
	var lay: Node3D = LayoutS.of(host)
	var names: Array = ["Vendor", "Anvil", "Dummy"]
	var i: int = 0
	while i < names.size():
		var key: String = str(names[i])
		var p: Vector3 = lay.spot_pos(key)
		Util._blob(host, Vector3(p.x, 0.0, p.z))
		i += 1
	var goods: Array = host.find_children("*", "Sprite3D", true, false)
	var g: int = 0
	while g < goods.size():
		var spr: Sprite3D = goods[g]
		g += 1
		if spr == null or spr.get_parent() == null:
			continue
		var parent_name: String = str(spr.get_parent().name).to_lower()
		var spr_name: String = str(spr.name).to_lower()
		if parent_name.find("stall") < 0 and spr_name.find("good") < 0 and spr_name.find("ware") < 0:
			continue
		var at: Vector3 = spr.global_position
		Util._blob(host, Vector3(at.x, 0.0, at.z))
