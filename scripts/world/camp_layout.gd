@tool
extends Node3D

const GROUND_W: int = 36
const GROUND_D: int = 32
const GROUND_OX: int = -2
const GROUND_OZ: int = -2
const GRASS_PAD: int = 16
const PATH_X: float = 16.5
const PATH_Z: float = 15.0
const TILE_W_DEFAULT: float = 3.2
const ROOF_EAVE_DEFAULT: float = 0.42
const AWNING_DEPTH_DEFAULT: float = 0.48
const AWNING_SLOPE_DEFAULT: float = 0.10
const AWNING_VALANCE_DEFAULT: float = 0.16
const HALL_SIZE_DEFAULT := Vector3(5.6, 3.4, 4.2)
const WING_SIZE_DEFAULT := Vector3(3.8, 2.7, 3.2)
const HALL_POS_DEFAULT := Vector3(8.2, 1.7, 6.0)
const STALL_POS_DEFAULT := Vector3(25.0, 1.2, 8.0)
const STALL_SIZE_DEFAULT := Vector3(4.6, 2.4, 3.4)
const CRYSTAL_POS_DEFAULT := Vector3(16.475, 0.0, 10.2)
const ANVIL_POS_DEFAULT := Vector3(21.2, 0.0, 11.4)
const BOARD_POS_DEFAULT := Vector3(16.1, 0.0, 6.2)
const VENDOR_POS_DEFAULT := Vector3(25.0, 0.0, 10.2)
const DUMPSTER_POS_DEFAULT := Vector3(5.2, 0.0, 9.4)
const BILLBOARD_POS_DEFAULT := Vector3(20.5, 0.0, 16.5)
const DUMMY_POS_DEFAULT := Vector3(8.5, 0.0, 15.5)
const SPAWN_POS_DEFAULT := Vector3(16.5, 0.0, 16.0)
const BANNER_POS_DEFAULT := Vector3(16.5, 0.0, 22.0)

@export var ground_w: int = GROUND_W
@export var ground_d: int = GROUND_D
@export var ground_ox: int = GROUND_OX
@export var ground_oz: int = GROUND_OZ
@export var grass_pad: int = GRASS_PAD
@export var path_x: float = PATH_X
@export var path_z: float = PATH_Z
@export var tile_w: float = TILE_W_DEFAULT

@export var hall_box: Vector3 = HALL_SIZE_DEFAULT
@export var wing_box: Vector3 = WING_SIZE_DEFAULT
@export var stall_box: Vector3 = STALL_SIZE_DEFAULT
@export var hall_eave: float = ROOF_EAVE_DEFAULT
@export var wing_eave: float = ROOF_EAVE_DEFAULT
@export var stall_eave: float = ROOF_EAVE_DEFAULT
@export var hall_tile_w: float = 0.0
@export var wing_tile_w: float = 0.0
@export var stall_tile_w: float = 0.0
@export var hall_uv_off := Vector2.ZERO
@export var wing_uv_off := Vector2.ZERO
@export var stall_uv_off := Vector2.ZERO
@export var hall_awning_depth: float = AWNING_DEPTH_DEFAULT
@export var hall_awning_slope: float = AWNING_SLOPE_DEFAULT
@export var hall_awning_valance: float = AWNING_VALANCE_DEFAULT
@export var wing_awning_depth: float = AWNING_DEPTH_DEFAULT
@export var wing_awning_slope: float = AWNING_SLOPE_DEFAULT
@export var wing_awning_valance: float = AWNING_VALANCE_DEFAULT


static func on_camp(host: Node3D) -> Node3D:
	var existing: Node = host.get_node_or_null("Layout")
	if existing is Node3D:
		return existing as Node3D
	var layout: Node3D = new()
	layout.name = "Layout"
	host.add_child(layout)
	if Engine.is_editor_hint():
		layout.owner = host
	layout.ensure_tree()
	return layout


func ensure_tree() -> void:
	_ensure_body("Hall", HALL_POS_DEFAULT)
	_ensure_body("Wing", _default_wing_pos())
	_ensure_body("Stall", STALL_POS_DEFAULT)
	_ensure_child("RoofHall", _default_roof_pos(HALL_POS_DEFAULT, hall_box, hall_eave, 0.0))
	_ensure_child("RoofWing", _default_roof_pos(_default_wing_pos(), wing_box, wing_eave, 0.01))
	_ensure_child("AwningHall", HALL_POS_DEFAULT)
	_ensure_child("AwningWing", _default_wing_pos())
	var spots: Node3D = _ensure_child("Spots", Vector3.ZERO)
	_ensure_named(spots, "Crystal", CRYSTAL_POS_DEFAULT)
	_ensure_named(spots, "Anvil", ANVIL_POS_DEFAULT)
	_ensure_named(spots, "Board", BOARD_POS_DEFAULT)
	_ensure_named(spots, "Vendor", VENDOR_POS_DEFAULT)
	_ensure_named(spots, "Dumpster", DUMPSTER_POS_DEFAULT)
	_ensure_named(spots, "Billboard", BILLBOARD_POS_DEFAULT)
	_ensure_named(spots, "Dummy", DUMMY_POS_DEFAULT)
	_ensure_named(spots, "Spawn", SPAWN_POS_DEFAULT)
	_ensure_named(spots, "Banner", BANNER_POS_DEFAULT)


func hall() -> Node3D:
	return _leaf("Hall")


func wing() -> Node3D:
	return _leaf("Wing")


func stall() -> Node3D:
	return _leaf("Stall")


func roof_hall() -> Node3D:
	return _leaf("RoofHall")


func roof_wing() -> Node3D:
	return _leaf("RoofWing")


func awning_hall() -> Node3D:
	return _leaf("AwningHall")


func awning_wing() -> Node3D:
	return _leaf("AwningWing")


func spot(spot_id: String) -> Node3D:
	return _leaf("Spots/" + spot_id)


func hall_pos() -> Vector3:
	return hall().global_position


func wing_pos() -> Vector3:
	return wing().global_position


func stall_pos() -> Vector3:
	return stall().global_position


func spot_pos(spot_id: String) -> Vector3:
	return spot(spot_id).global_position


func roof_origin(which: String) -> Vector3:
	return _leaf(which).global_position


func roof_uv(which: String) -> Vector2:
	var n: Node3D = _leaf(which)
	var authored: Vector2 = hall_uv_off
	if which == "RoofWing":
		authored = wing_uv_off
	elif which == "RoofStall":
		authored = stall_uv_off
	return authored + Vector2(n.position.x, n.position.z)


func tile_for(which: String) -> float:
	var override_w: float = tile_w
	if which == "Hall" and hall_tile_w > 0.0:
		override_w = hall_tile_w
	elif which == "Wing" and wing_tile_w > 0.0:
		override_w = wing_tile_w
	elif which == "Stall" and stall_tile_w > 0.0:
		override_w = stall_tile_w
	if override_w <= 0.05:
		return TILE_W_DEFAULT
	return override_w


func eave_for(which: String) -> float:
	if which == "Wing":
		return wing_eave
	if which == "Stall":
		return stall_eave
	return hall_eave


func awning_depth(which: String) -> float:
	if which == "Wing":
		return wing_awning_depth
	return hall_awning_depth


func awning_slope(which: String) -> float:
	if which == "Wing":
		return wing_awning_slope
	return hall_awning_slope


func awning_valance(which: String) -> float:
	if which == "Wing":
		return wing_awning_valance
	return hall_awning_valance


func ground_x0() -> int:
	return ground_ox


func ground_z0() -> int:
	return ground_oz


func slab_w() -> int:
	return ground_w


func slab_d() -> int:
	return ground_d


func pad() -> int:
	return grass_pad


func path_origin() -> Vector2:
	return Vector2(path_x, path_z)


func wing_face_z() -> float:
	return wing_pos().z + wing_box.z * 0.5


func reception_pos() -> Vector3:
	return Vector3(wing_pos().x + 0.027, 0.785, wing_face_z() + 0.07)


func aabb_x0() -> float:
	return float(ground_ox - grass_pad)


func aabb_z0() -> float:
	return float(ground_oz - grass_pad)


func aabb_x1() -> float:
	return float(ground_ox + ground_w + grass_pad)


func aabb_z1() -> float:
	return float(ground_oz + ground_d + grass_pad)


func _leaf(rel: String) -> Node3D:
	ensure_tree()
	var n: Node = get_node_or_null(rel)
	if n is Node3D:
		return n as Node3D
	return _ensure_child(rel, Vector3.ZERO)


func _ensure_body(doc_name: String, pos: Vector3) -> Node3D:
	return _ensure_child(doc_name, pos)


func _ensure_child(doc_name: String, pos: Vector3) -> Node3D:
	var n: Node = get_node_or_null(doc_name)
	if n is Node3D:
		return n as Node3D
	var node: Node3D = Node3D.new()
	node.name = doc_name
	node.position = pos
	add_child(node)
	if Engine.is_editor_hint() and owner != null:
		node.owner = owner
	return node


func _ensure_named(parent_node: Node3D, doc_name: String, pos: Vector3) -> Node3D:
	var n: Node = parent_node.get_node_or_null(doc_name)
	if n is Node3D:
		return n as Node3D
	var node: Node3D = Node3D.new()
	node.name = doc_name
	node.position = pos
	parent_node.add_child(node)
	if Engine.is_editor_hint() and owner != null:
		node.owner = owner
	return node


func _default_wing_pos() -> Vector3:
	var back: float = HALL_POS_DEFAULT.z - HALL_SIZE_DEFAULT.z * 0.5
	return Vector3(
		HALL_POS_DEFAULT.x + HALL_SIZE_DEFAULT.x * 0.5 + WING_SIZE_DEFAULT.x * 0.5 - 0.12,
		WING_SIZE_DEFAULT.y * 0.5,
		back + WING_SIZE_DEFAULT.z * 0.5
	)


func _default_roof_pos(body_pos: Vector3, body_box: Vector3, eave: float, y_bias: float) -> Vector3:
	var y: float = body_pos.y + body_box.y * 0.5 + 0.03 + y_bias
	var z0: float = body_pos.z - body_box.z * 0.5
	return Vector3(body_pos.x, y, z0 + (body_box.z + eave) * 0.5)
