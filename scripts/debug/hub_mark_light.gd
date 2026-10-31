extends RefCounted

## Player marks against the hub lights (camp-prop-shadows flow), checked after the flow moves the player:
## .lantern (player just in front of a guild face lantern): a live point-light mark whose source is that lantern
## (actor_lit/drive.gd hub_points) and which points away from it (dot >= MIN_DOT). .plant_lantern flips the mark's
## direction toward the lamp and must FAIL. The point marks' summed alpha must reach MIN_INK (dungeon torch strength at
## that distance, same Drive._plan); .plant_weak scales it to the old faint 0.3x and must FAIL weak.
## .shade (player in full building shade): the sun mark (slot 0) is bound to cancel (sun_cancel 1) and what is left
## of it there (lit_k.sun_left of the baked light at the mark) is under LEFT_MAX. .plant_shade ignores the cancel and
## must FAIL double. Both getters return "" when fine, else the numbers.

const K := preload("res://scripts/graphics/actor_lit/lit_k.gd")
const Drive := preload("res://scripts/graphics/actor_lit/drive.gd")
const LightRt := preload("res://scripts/graphics/light_rt.gd")
const HubCast := preload("res://scripts/graphics/light_rt/hub_cast.gd")
const MIN_DOT := 0.9
const LEFT_MAX := 0.08
const MIN_INK := 0.25

var lantern: String:
	get:
		return lantern_fault(false)
var plant_lantern: String:
	get:
		return "caught" if lantern_fault(true) != "" else "missed"
var plant_weak: String:
	get:
		return "caught" if lantern_fault(false, 0.3).contains("weak") else "missed"
var shade: String:
	get:
		return shade_fault(false)
var plant_shade: String:
	get:
		return "caught" if shade_fault(true).contains("double") else "missed"

static func _lit() -> Node:
	var p: Node = (Engine.get_main_loop() as SceneTree).get_first_node_in_group("player")
	return null if p == null else p.get_node_or_null("ActorLit")

static func lantern_fault(flip: bool, k: float = 1.0) -> String:
	var lit: Node = _lit()
	if lit == null:
		return "no ActorLit"
	var host: Node3D = lit.get_parent() as Node3D
	var feet := Vector2(host.global_position.x, host.global_position.z)
	var best := Vector2.INF
	for n: Node in host.get_tree().get_nodes_in_group("hub_lamp"):
		var xz := Vector2((n as Node3D).global_position.x, (n as Node3D).global_position.z)
		if feet.distance_to(xz) < feet.distance_to(best):
			best = xz
	if best == Vector2.INF:
		return "no hub_lamp"
	var want: Vector2 = (feet - best).normalized()
	var ink: float = 0.0
	for slot in range(1, K.MARK_N):
		if (lit.get("marks")[slot] as MeshInstance3D).visible:
			ink += float(lit.get("_alpha_at")[slot]) * k
	if ink < MIN_INK:
		return "weak: point ink %.2f < %.2f" % [ink, MIN_INK]
	for slot in range(1, K.MARK_N):
		var src: Vector2 = lit.get("_src_at")[slot]
		if src.distance_to(best) > 0.01:
			continue
		var away: Vector2 = lit.get("_away_at")[slot]
		if flip:
			away = -away
		var live: bool = float(lit.get("_alpha_at")[slot]) >= K.HIDE_A and (lit.get("marks")[slot] as MeshInstance3D).visible
		var dot: float = away.dot(want)
		return "" if live and dot >= MIN_DOT else "slot%d live=%s dot=%.2f" % [slot, live, dot]
	return "no mark from lamp at %s (feet %s)" % [best, feet]

static func shade_fault(ignore_cancel: bool) -> String:
	var lit: Node = _lit()
	if lit == null:
		return "no ActorLit"
	var node: MeshInstance3D = lit.get("marks")[0]
	if not node.visible or node.mesh == null:
		return "sun mark hidden"
	var c: Vector3 = node.global_transform * node.mesh.get_aabb().get_center()
	var s: Color = LightRt.sample_xz(Vector2(c.x, c.z))
	var l: float = (s.r + s.g + s.b) / 3.0
	var mat: ShaderMaterial = node.material_override as ShaderMaterial
	var on: bool = mat != null and float(mat.get_shader_parameter("sun_cancel")) > 0.5 and not ignore_cancel
	var left: float = K.sun_left(l, HubCast.SHADE_NEAR) if on else 1.0
	return "" if left <= LEFT_MAX else "double: l=%.2f left=%.2f cancel=%s" % [l, left, on]
