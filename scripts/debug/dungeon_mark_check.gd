extends RefCounted

## Dungeon character marks on the hub's shared mark path (dungeon-marks flow): every live mark of the player and the
## enemies is per-cell on the ground grid (lit_k HUB_GRID) and, for a sticker mark, reads per-column contact.
## .grid: "" when fine, else the first bad body. .plant_on sets lit_k.plant_ungrid (the old dungeon path: no grid,
## no contact); after a wait .plant_caught must read "caught" (it clears the plant).

const K := preload("res://scripts/graphics/actor_lit/lit_k.gd")
const LightRt := preload("res://scripts/graphics/light_rt.gd")
const NEAR := 12.0
const PROPS := ["gather", "breakables"]

## Prop marks on the hub path, live from the torches/crystals (drive.gd _drive_many; no bake, no sun slot).
## .props: every gather/breakable prop within NEAR has the hub prop mark (prop_mark.gd: ActorLit, no engine shadow),
## at least one mark is live, and every live mark is on the grid and sourced at a light cast;
## .plant_props_old puts the old path back on them (engine shadow, no mark) and must FAIL.
## .to_prop spawns an ore node (gather_node.gd, the real spawn path) 1 m east of the player by the torch, since
## seed 42's own props stand in unlit rooms far from any cast.
var to_prop: String:
	get:
		var tree: SceneTree = Engine.get_main_loop() as SceneTree
		var p: Node3D = tree.get_first_node_in_group("player") as Node3D
		var n: Node3D = load("res://scripts/world/gather/gather_node.gd").new()
		tree.current_scene.add_child(n)
		n.setup("mine", p.global_position + Vector3(1.0, 0.0, 0.0))
		return "ok"
var props: String:
	get:
		return props_fault()
var plant_props_old: String:
	get:
		for b in _near_props():
			var lit: Node = b.get_node_or_null("ActorLit")
			if lit != null:
				b.remove_child(lit)
				lit.free()
			(b.get("spr") as Sprite3D).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
		return "caught" if props_fault() != "" else "missed"

static func _near_props() -> Array[Node3D]:
	var tree: SceneTree = Engine.get_main_loop() as SceneTree
	var at: Vector3 = (tree.get_first_node_in_group("player") as Node3D).global_position
	var out: Array[Node3D] = []
	for g in PROPS:
		for b: Node in tree.get_nodes_in_group(g):
			if b is Node3D and b.get("spr") != null and (b as Node3D).global_position.distance_to(at) <= NEAR:
				out.append(b as Node3D)
	return out

static func props_fault() -> String:
	var ps: Array[Node3D] = _near_props()
	if ps.is_empty():
		var tree: SceneTree = Engine.get_main_loop() as SceneTree
		var n: int = 0
		var d: float = INF
		var at: Vector3 = (tree.get_first_node_in_group("player") as Node3D).global_position
		for g in PROPS:
			for b: Node in tree.get_nodes_in_group(g):
				n += 1
				if b is Node3D:
					d = minf(d, (b as Node3D).global_position.distance_to(at))
		return "no props within %.0f m (props=%d nearest=%.1f at %s)" % [NEAR, n, d, at]
	var live: int = 0
	for b in ps:
		var lit: Node = b.get_node_or_null("ActorLit")
		if lit == null or (b.get("spr") as Sprite3D).cast_shadow != GeometryInstance3D.SHADOW_CASTING_SETTING_OFF:
			return "%s off the hub prop mark (lit=%s)" % [b.name, lit != null]
		for slot in K.MARK_N:
			var m: MeshInstance3D = lit.get("marks")[slot] as MeshInstance3D
			if m == null:
				continue
			var mat: ShaderMaterial = m.material_override as ShaderMaterial
			if not m.visible or mat == null:
				continue
			live += 1
			if absf(float(mat.get_shader_parameter("grid")) - K.HUB_GRID) > 0.001:
				return "%s off grid" % b.name
			var src: Vector2 = lit.get("_src_at")[slot]
			if not LightRt._casts.any(func(c: Dictionary) -> bool: return src.distance_to(c["xz"]) < 0.05):
				return "%s slot%d not sourced at a torch/crystal (src %s)" % [b.name, slot, src]
	return "" if live > 0 else "no live prop marks"
const MIN_DOT := 0.9

## .light (player by a torch/crystal after .to_torch): a live mark whose source is that cast (drive.gd _drive_many) and
## which points away from it (dot >= MIN_DOT), as the hub lantern check. .plant_light flips the mark toward the light
## and must FAIL. .kind names the cast (torch/crystal).
var light: String:
	get:
		return light_fault(false)
var plant_light: String:
	get:
		return "caught" if light_fault(true) != "" else "missed"

static func _nearest(feet: Vector2) -> Dictionary:
	var best: Dictionary = {}
	for c: Dictionary in LightRt._casts:
		if best.is_empty() or feet.distance_to(c["xz"]) < feet.distance_to(best["xz"]):
			best = c
	return best

static func light_fault(flip: bool) -> String:
	var p: Node3D = (Engine.get_main_loop() as SceneTree).get_first_node_in_group("player") as Node3D
	var lit: Node = p.get_node_or_null("ActorLit")
	if lit == null:
		return "no ActorLit"
	var feet := Vector2(p.global_position.x, p.global_position.z)
	var c: Dictionary = _nearest(feet)
	if c.is_empty():
		return "no light casts"
	var want: Vector2 = (feet - (c["xz"] as Vector2)).normalized()
	for slot in K.MARK_N:
		var src: Vector2 = lit.get("_src_at")[slot]
		if src.distance_to(c["xz"]) > 0.05:
			continue
		var away: Vector2 = lit.get("_away_at")[slot]
		if flip:
			away = -away
		var node: MeshInstance3D = lit.get("marks")[slot] as MeshInstance3D
		var live: bool = float(lit.get("_alpha_at")[slot]) >= K.HIDE_A and node != null and node.visible
		var dot: float = away.dot(want)
		return "" if live and dot >= MIN_DOT else "%s slot%d live=%s dot=%.2f" % [c["kind"], slot, live, dot]
	return "no mark from %s at %s (feet %s)" % [c["kind"], c["xz"], feet]

## .to_torch moves the player onto open floor 1-1.5 m from the light cast (torch/crystal, LightRt._casts) nearest it (so a torch mark is live).
var to_torch: String:
	get:
		var tree: SceneTree = Engine.get_main_loop() as SceneTree
		var p: Node3D = tree.get_first_node_in_group("player") as Node3D
		var feet := Vector2(p.global_position.x, p.global_position.z)
		var best := Vector2.INF
		for c: Dictionary in LightRt._casts:
			if feet.distance_to(c["xz"]) < feet.distance_to(best):
				best = c["xz"]
		if best == Vector2.INF:
			return "no light casts"
		for r in [1.0, 1.25, 1.5]:
			for k in 8:
				var at: Vector2 = best + Vector2.from_angle(k * TAU / 8.0) * r
				if LightRt.floor_open(at):
					p.global_position = Vector3(at.x, p.global_position.y, at.y)
					return "ok"
		return "no open floor by torch"

var grid: String:
	get:
		return fault()
var plant_on: String:
	get:
		K.plant_ungrid = true
		return "set"
var plant_caught: String:
	get:
		var r: String = fault()
		K.plant_ungrid = false
		return "caught" if r != "" else "missed"

static func fault() -> String:
	var tree: SceneTree = Engine.get_main_loop() as SceneTree
	var live: int = 0
	var bodies: int = 0
	var marks: int = 0
	for g in ["player", "enemies"]:
		for b: Node in tree.get_nodes_in_group(g):
			var lit: Node = b.get_node_or_null("ActorLit")
			if lit == null or (b as Node3D).global_position.distance_to(tree.get_first_node_in_group("player").global_position) > NEAR:
				continue
			bodies += 1
			for m: MeshInstance3D in lit.get("marks"):
				if m == null:
					continue
				marks += 1
				var mat: ShaderMaterial = m.material_override as ShaderMaterial
				if not m.visible or mat == null:
					continue
				live += 1
				if absf(float(mat.get_shader_parameter("grid")) - K.HUB_GRID) > 0.001:
					return "%s off grid (grid=%s)" % [b.name, mat.get_shader_parameter("grid")]
				if String(lit.get("solid")) == "" and float(mat.get_shader_parameter("contact_on")) < 0.5:
					return "%s no per-column contact" % b.name
	return "" if live > 0 else "no live marks (bodies=%d marks=%d)" % [bodies, marks]
