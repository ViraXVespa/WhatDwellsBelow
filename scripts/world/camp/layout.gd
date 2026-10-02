@tool
extends Node3D

signal editor_redraw

const GROUND_W: int = 36
const GROUND_D: int = 32
const GROUND_OX: int = -2
const GROUND_OZ: int = -2
const GRASS_PAD: int = 16
const PATH_X: float = 16.5
const PATH_Z: float = 15.0
const TILE_W_DEFAULT: float = 3.2
const ROOF_EAVE_DEFAULT: float = 0.42
const HALL_AWNING_DEPTH_DEFAULT: float = 0.42
const WING_AWNING_DEPTH_DEFAULT: float = 0.36
const AWNING_SLOPE_DEFAULT: float = 0.10
const AWNING_VALANCE_DEFAULT: float = 0.16
const HALL_SIZE_DEFAULT := Vector3(5.6, 3.4, 4.2)
const WING_SIZE_DEFAULT := Vector3(3.8, 3.8, 3.2)
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
@export var hall_awning_depth: float = HALL_AWNING_DEPTH_DEFAULT
@export var hall_awning_slope: float = AWNING_SLOPE_DEFAULT
@export var hall_awning_valance: float = AWNING_VALANCE_DEFAULT
@export var wing_awning_depth: float = WING_AWNING_DEPTH_DEFAULT
@export var wing_awning_slope: float = AWNING_SLOPE_DEFAULT
@export var wing_awning_valance: float = AWNING_VALANCE_DEFAULT

@export var rebuild_preview: bool = false:
	set(v):
		rebuild_preview = false
		_kick_redraw()

func _kick_redraw() -> void:
	if Engine.is_editor_hint():
		editor_redraw.emit()

func _set(property: StringName, value: Variant) -> bool:
	var key: String = String(property)
	var dress: PackedStringArray = PackedStringArray([
		"tile_w", "hall_box", "wing_box", "stall_box",
		"hall_eave", "wing_eave", "stall_eave",
		"hall_tile_w", "wing_tile_w", "stall_tile_w",
		"hall_uv_off", "wing_uv_off", "stall_uv_off",
		"hall_awning_depth", "hall_awning_slope", "hall_awning_valance",
		"wing_awning_depth", "wing_awning_slope", "wing_awning_valance"
	])
	if key not in dress:
		return false
	match key:
		"tile_w":
			tile_w = float(value)
		"hall_box":
			hall_box = value
		"wing_box":
			wing_box = value
		"stall_box":
			stall_box = value
		"hall_eave":
			hall_eave = float(value)
		"wing_eave":
			wing_eave = float(value)
		"stall_eave":
			stall_eave = float(value)
		"hall_tile_w":
			hall_tile_w = float(value)
		"wing_tile_w":
			wing_tile_w = float(value)
		"stall_tile_w":
			stall_tile_w = float(value)
		"hall_uv_off":
			hall_uv_off = value
		"wing_uv_off":
			wing_uv_off = value
		"stall_uv_off":
			stall_uv_off = value
		"hall_awning_depth":
			hall_awning_depth = float(value)
		"hall_awning_slope":
			hall_awning_slope = float(value)
		"hall_awning_valance":
			hall_awning_valance = float(value)
		"wing_awning_depth":
			wing_awning_depth = float(value)
		"wing_awning_slope":
			wing_awning_slope = float(value)
		"wing_awning_valance":
			wing_awning_valance = float(value)
	notify_property_list_changed()
	_kick_redraw()
	return true

## The one layout lookup: nearest `Layout` child on `n` or an ancestor, else a default one on `n`.
static func of(n: Node) -> Node3D:
	var at: Node = n
	while at != null:
		var found: Node = at.get_node_or_null("Layout")
		if found is Node3D:
			return found as Node3D
		at = at.get_parent()
	return on_camp(n as Node3D)

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

func spot(spot_id: String) -> Node3D:
	return _leaf("Spots/" + spot_id)

func _pose_of(n: Node3D) -> Vector3:
	if n == null:
		return Vector3.ZERO
	if is_inside_tree() and n.is_inside_tree():
		return n.global_position
	var xf: Transform3D = n.transform
	var p: Node = n.get_parent()
	while p is Node3D:
		if p == self:
			break
		xf = (p as Node3D).transform * xf
		p = p.get_parent()
	return xf.origin
func hall_pos() -> Vector3:
	return _pose_of(hall())
func wing_pos() -> Vector3:
	return _pose_of(wing())
func stall_pos() -> Vector3:
	return _pose_of(stall())
func spot_pos(spot_id: String) -> Vector3:
	return _pose_of(spot(spot_id))

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

func awning_depth(which: String) -> float:
	if which == "Wing":
		return wing_awning_depth
	return hall_awning_depth

func awning_slope(which: String) -> float:
	if which == "Wing":
		return wing_awning_slope
	return hall_awning_slope

## Valance height as a fraction of the wall height (not metres).
func awning_valance(which: String) -> float:
	if which == "Wing":
		return wing_awning_valance
	return hall_awning_valance

func pad() -> int:
	return grass_pad

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

func _ready() -> void:
	ensure_tree()
