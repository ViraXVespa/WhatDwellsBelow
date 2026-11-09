extends Object

## Split from actor_lit.gd: _ensure_host, _new_mark, _take_node....

const K := preload("res://scripts/graphics/actor_lit/lit_k.gd")
const HubCast := preload("res://scripts/graphics/light_rt/hub_cast.gd")
const LightRt := preload("res://scripts/graphics/light_rt.gd")

static var _shade: Shader

static func _ensure_host(host: Node3D) -> Node3D:
	if host._pool_host != null and is_instance_valid(host._pool_host):
		return host._pool_host
	var tree: SceneTree = Engine.get_main_loop() as SceneTree
	if tree == null:
		return null
	var script: GDScript = load("res://scripts/graphics/actor_lit.gd") as GDScript
	var pool: Node3D = script.new() as Node3D
	pool.name = "MarkPool"
	host._pool_host = pool
	tree.root.add_child(pool)
	var made: int = 0
	while made < K.POOL_N:
		_park(host, _new_mark(host))
		made += 1
	return pool

static func _new_mark(host: Node3D) -> MeshInstance3D:
	var mesh_node: MeshInstance3D = MeshInstance3D.new()
	mesh_node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var mat: ShaderMaterial = _mat()
	mat.render_priority = -2
	mesh_node.sorting_offset = -30.0
	mesh_node.material_override = mat
	mesh_node.visible = false
	mesh_node.top_level = true
	if host._pool_host != null:
		host._pool_host.add_child(mesh_node)
	return mesh_node

static func _take_node(host: Node3D) -> MeshInstance3D:
	_ensure_host(host)
	while not host._pool.is_empty():
		var node: MeshInstance3D = host._pool.pop_back()
		if is_instance_valid(node):
			return node
	return _new_mark(host)

static func _park(host: Node3D, node: MeshInstance3D) -> void:
	if node == null or not is_instance_valid(node):
		return
	node.visible = false
	if host._pool_host != null and node.get_parent() != host._pool_host:
		# Keeping the global transform reads it, and that errors once the actor's children have left the tree.
		node.reparent(host._pool_host, false)
	host._pool.append(node)

static func _mat() -> ShaderMaterial:
	if _shade == null:
		var sh: Shader = Shader.new()
		sh.code = K.SHADE
		_shade = sh
	var mat: ShaderMaterial = ShaderMaterial.new()
	mat.shader = _shade
	mat.render_priority = 8
	mat.set_shader_parameter("floor_l", HubCast.SHADE_NEAR)
	LightRt.bind(mat)
	return mat

static func _claim(host: Node3D, slot: int) -> MeshInstance3D:
	var node: MeshInstance3D = _take_node(host)
	host.marks[slot] = node
	host._albedo_id[slot] = -1
	host._contact_id[slot] = -1
	host._shade_set[slot] = false
	host._sun_at[slot] = -1.0
	host._grid_at[slot] = -1.0
	host._contact_on[slot] = -1.0
	host._key_at[slot] = []
	if node.get_parent() != host:
		node.reparent(host)
	node.visible = true
	return node

static func _release(host: Node3D, slot: int) -> void:
	if slot < 0 or slot >= host.marks.size():
		return
	var node: MeshInstance3D = host.marks[slot]
	if node == null:
		return
	node.visible = false
	host.marks[slot] = null
	_park(host, node)

static func _release_all(host: Node3D) -> void:
	for slot in host.marks.size():
		_release(host, slot)
