@tool
extends Node3D

## The hub's one layout: serves layout_spec.gd (every placement, size, asset, light and draw-order number) to the camp
## build, the props, the hub bake and the bake overlay. camp.tscn holds only this node; ensure_tree() makes the
## Hall/Wing/Stall/Spots nodes from the spec at run time (never saved). design/hub.md.

signal editor_redraw

const Spec := preload("res://scripts/world/camp/layout_spec.gd")

var ground_w: int = Spec.GROUND.size.x
var ground_d: int = Spec.GROUND.size.y
var ground_ox: int = Spec.GROUND.position.x
var ground_oz: int = Spec.GROUND.position.y
var grass_pad: int = Spec.GRASS_PAD
var tile_w: float = Spec.TILE_W
var hall_box: Vector3 = Spec.HALL["box"]
var wing_box: Vector3 = Spec.WING["box"]
var stall_box: Vector3 = Spec.STALL["box"]
var hall_tile_w: float = 0.0
var wing_tile_w: float = 0.0
var stall_tile_w: float = 0.0
var hall_uv_off := Vector2.ZERO
var wing_uv_off := Vector2.ZERO
var stall_uv_off := Vector2.ZERO

## Editor: rebuild the preview after editing layout_spec.gd.
@export var rebuild_preview: bool = false:
	set(v):
		rebuild_preview = false
		if Engine.is_editor_hint():
			editor_redraw.emit()

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
	_ensure(self, "Hall", Spec.HALL["pos"])
	_ensure(self, "Wing", _default_wing_pos())
	_ensure(self, "Stall", Spec.STALL["pos"])
	var spots: Node3D = _ensure(self, "Spots", Vector3.ZERO)
	for id: String in Spec.SPOTS:
		_ensure(spots, id, Spec.SPOTS[id])

## The spec row of a building: "Hall", "Wing" or "Stall".
static func body(which: String) -> Dictionary:
	return Spec.WING if which == "Wing" else (Spec.STALL if which == "Stall" else Spec.HALL)

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
## A ground spot; "Vendor" stands VENDOR_GAP in front of the stall.
func spot_pos(spot_id: String) -> Vector3:
	if spot_id == "Vendor":
		return vendor_pos()
	return _pose_of(spot(spot_id))
func vendor_pos() -> Vector3:
	var at: Vector3 = stall_pos()
	return Vector3(at.x, 0.0, at.z + stall_box.z * 0.5 + Spec.VENDOR_GAP)
## Every interact or actor spot by name (overlay, bench).
func spot_ids() -> Array:
	var ids: Array = Spec.SPOTS.keys()
	ids.append("Vendor")
	return ids

func tile_for(which: String) -> float:
	var override_w: float = tile_w
	if which == "Hall" and hall_tile_w > 0.0:
		override_w = hall_tile_w
	elif which == "Wing" and wing_tile_w > 0.0:
		override_w = wing_tile_w
	elif which == "Stall" and stall_tile_w > 0.0:
		override_w = stall_tile_w
	if override_w <= 0.05:
		return Spec.TILE_W
	return override_w

func awning_depth(which: String) -> float:
	return (body(which)["awning"] as Vector2).x
## Valance height as a fraction of the wall height (not metres).
func awning_valance(which: String) -> float:
	return (body(which)["awning"] as Vector2).y

## Stall post centres, body-local: (half width x, front z, rear z); posts reach post_half beyond. Walls, collision,
## tarp posts and the bake lid all use it.
func stall_posts() -> Vector3:
	var f: Vector3 = Spec.STALL["posts"]
	return Vector3(stall_box.x * f.x, stall_box.z * f.y, -stall_box.z * f.z)
## Bake lid over the stall, world XZ centre and half sizes: the tarp and the post outer faces together; h = ridge.
func stall_lid() -> Dictionary:
	var at: Vector3 = stall_pos()
	var p: Vector3 = stall_posts()
	var ph: float = Spec.STALL["post_half"]
	var hx: float = maxf(stall_box.x * 0.5, p.x + ph)
	var z0: float = minf(-stall_box.z * 0.5, p.z - ph)
	var z1: float = maxf(stall_box.z * 0.5, p.y + ph)
	return {"x": at.x, "z": at.z + (z0 + z1) * 0.5, "hx": hx, "hz": (z1 - z0) * 0.5, "h": stall_ridge_y()}
## Top the bake projects the fence from (rails and posts).
func fence_shadow_top() -> float:
	return Spec.FENCE["shadow_top"]
## Banner pole collision boxes, world: [centre, size] per pole.
func banner_poles() -> Array:
	var at: Vector3 = spot_pos("Banner")
	var pole: Vector3 = Spec.BANNER["pole"]
	var px: float = Spec.BANNER["pole_x"]
	return [[at + Vector3(-px, pole.y * 0.5, 0.0), pole], [at + Vector3(px, pole.y * 0.5, 0.0), pole]]
func stall_eave_y() -> float:
	return stall_box.y * float(Spec.STALL["eave"])
func stall_ridge_y() -> float:
	return stall_eave_y() + float(Spec.STALL["rise"])

func pad() -> int:
	return grass_pad
func wing_face_z() -> float:
	return wing_pos().z + wing_box.z * 0.5
func reception_pos() -> Vector3:
	return Vector3(wing_pos().x + Spec.RECEPTION.x, Spec.RECEPTION.y, wing_face_z() + Spec.RECEPTION.z)
## Path crossing centre (shot default look): x of the north-south arm, z of the east-west arm.
static func path_cross() -> Vector2:
	var ns: Rect2i = Spec.PATHS[1]
	var ew: Rect2i = Spec.PATHS[0]
	return Vector2(ns.position.x + ns.size.x * 0.5, ew.position.y + ew.size.y * 0.5)
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
	return _ensure(self, rel, Vector3.ZERO)

## Run-time child at the spec pose; no owner, so the editor never saves a pose into camp.tscn.
func _ensure(parent_node: Node3D, doc_name: String, pos: Vector3) -> Node3D:
	var n: Node = parent_node.get_node_or_null(doc_name)
	if n is Node3D:
		return n as Node3D
	var node: Node3D = Node3D.new()
	node.name = doc_name
	node.position = pos
	parent_node.add_child(node)
	return node

func _default_wing_pos() -> Vector3:
	var hp: Vector3 = Spec.HALL["pos"]
	var hb: Vector3 = Spec.HALL["box"]
	var wb: Vector3 = Spec.WING["box"]
	return Vector3(hp.x + hb.x * 0.5 + wb.x * 0.5 - float(Spec.WING["overlap"]), wb.y * 0.5, hp.z - hb.z * 0.5 + wb.z * 0.5)

func _ready() -> void:
	ensure_tree()
