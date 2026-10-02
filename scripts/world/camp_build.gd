extends Object

const T := preload("res://scripts/data/tunables.gd")
const MeshS := preload("res://scripts/world/camp_build_mesh.gd")
const EnvKit := preload("res://scripts/graphics/env_kit.gd")
const LayoutS := preload("res://scripts/world/camp_layout.gd")
const Util := preload("res://scripts/world/camp_build_util.gd")
const Parts := preload("res://scripts/world/camp_build_parts.gd")

const GROUND_W := 36
const GROUND_D := 32
const GROUND_OX := -2
const GROUND_OZ := -2
const GRASS_PAD := 16
const PATH_X := 16.5
const PATH_Z := 15.0
const STALL_SIZE := Vector3(4.6, 2.4, 3.4)

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

static func realize_editor(host: Node3D, layout: Node3D) -> void:
	host.set_meta("wdb_layout", layout)
	var bucket: Node3D = clear_generated(host)
	bucket.set_meta("wdb_layout", layout)
	ground(bucket)
	buildings(bucket)
	strip_building_cubes(host)
	dump_meshes(host)
	var ViewS: GDScript = load("res://scripts/world/camp_view.gd") as GDScript
	ViewS.fence(bucket)
static func world(host: Node3D) -> void:
	EnvKit.apply(host, Color(0.45, 0.58, 0.62), Color(0.95, 0.86, 0.7), 1.15, Vector3(-18.0, 34.0, -42.0), 0.9)

static func ground(host: Node3D) -> void:
	MeshS.ground(host)

static func outer_grass(host: Node3D) -> void:
	var lay: Node3D = _layout_from_build_host(host)
	var x0: float = float(lay.ground_ox - lay.grass_pad) if lay else float(GROUND_OX - GRASS_PAD)
	var z0: float = float(lay.ground_oz - lay.grass_pad) if lay else float(GROUND_OZ - GRASS_PAD)
	var x1: float = float(lay.ground_ox + lay.ground_w + lay.grass_pad) if lay else float(GROUND_OX + GROUND_W + GRASS_PAD)
	var z1: float = float(lay.ground_oz + lay.ground_d + lay.grass_pad) if lay else float(GROUND_OZ + GROUND_D + GRASS_PAD)
	var ix0: float = float(lay.ground_ox) if lay else float(GROUND_OX)
	var iz0: float = float(lay.ground_oz) if lay else float(GROUND_OZ)
	var ix1: float = float(lay.ground_ox + lay.ground_w) if lay else float(GROUND_OX + GROUND_W)
	var iz1: float = float(lay.ground_oz + lay.ground_d) if lay else float(GROUND_OZ + GROUND_D)
	var y: float = T.FLOOR_Y
	var tex := "res://assets/tiles/grass_field.png"
	var fb := Color(0.34, 0.46, 0.24)
	MeshS.grass_pad(host, Vector3((x0 + x1) * 0.5, y, (z0 + iz0) * 0.5), Vector2(x1 - x0, iz0 - z0), tex, fb)
	MeshS.grass_pad(host, Vector3((x0 + x1) * 0.5, y, (iz1 + z1) * 0.5), Vector2(x1 - x0, z1 - iz1), tex, fb)
	MeshS.grass_pad(host, Vector3((x0 + ix0) * 0.5, y, (iz0 + iz1) * 0.5), Vector2(ix0 - x0, iz1 - iz0), tex, fb)
	MeshS.grass_pad(host, Vector3((ix1 + x1) * 0.5, y, (iz0 + iz1) * 0.5), Vector2(x1 - ix1, iz1 - iz0), tex, fb)

static func tile_layer(host: Node3D, tex_path: String, points: Array, fallback: Color) -> void:
	MeshS.tile_layer(host, tex_path, points, fallback)

static func buildings(host: Node3D) -> void:
	Parts.guild(host)
	var lay: Node3D = _layout_from_build_host(host)
	var stall_at: Vector3 = lay.stall_pos() if lay else Vector3(25.0, 1.2, 8.0)
	var stall_box: Vector3 = lay.stall_box if lay else STALL_SIZE
	Parts.solid(host, stall_at, stall_box, Color(0.55, 0.35, 0.2), "res://assets/sprites/buildings/stall.png", true)

static func guild_roofs(host: Node3D) -> void:
	MeshS.guild_roofs(host)

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
			"CAMP_MESH box parent=",
			n.get_parent().name if n.get_parent() else "?",
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
			print("CAMP_MESH sprite parent=", n.get_parent().name if n.get_parent() else "?", " pos=", spr.position, " px=", spr.pixel_size)
			continue
		var mi := n as MeshInstance3D
		if mi == null:
			continue
		if mi.mesh is BoxMesh:
			boxes += 1
			print("CAMP_MESH keep_box parent=", n.get_parent().name if n.get_parent() else "?", " size=", (mi.mesh as BoxMesh).size)
		else:
			other += 1
			print("CAMP_MESH other name=", n.name, " mesh=", mi.mesh.get_class() if mi.mesh else "null")
	print("CAMP_MESH totals boxes=", boxes, " sprites=", sprites, " other=", other)

static func sweep(root: Node) -> void:
	if root == null:
		return
	var nodes: Array = root.find_children("*", "MeshInstance3D", true, false)
	var i: int = 0
	while i < nodes.size():
		var node: MeshInstance3D = nodes[i]
		i += 1
		if node == null or not is_instance_valid(node):
			continue
		var at: Vector3 = node.global_position
		var outside: bool = at.x < 1.0 or at.x > 33.0 or at.z < -2.0 or at.z > 26.0
		var near_origin: bool = at.length() < 1.5
		if not outside and not near_origin:
			continue
		var path: String = str(node.get_path())
		var low: String = path.to_lower()
		if low.contains("fence") or low.contains("ground") or low.contains("grass") or low.contains("yard"):
			continue
		printerr("sweep drop %s at=%s" % [path, at])
		node.queue_free()

static func stamp_actor_blobs(host: Node3D) -> void:
	if host == null:
		return
	var lay: Node3D = _layout_from_build_host(host)
	var names: Array = ["Vendor", "Anvil", "Dummy"]
	var i: int = 0
	while i < names.size():
		var key: String = str(names[i])
		if lay != null and lay.has_method("spot_pos"):
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

static func _layout_from_build_host(host: Node3D) -> Node3D:
	return Util._layout_from_build_host(host)
