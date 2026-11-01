extends RefCounted

## Lantern pools (light_rt/pools.gd, camp/lamp_pools.gd), CPU twin of the shader: every hub_lamp lights the yard
## 0.6 m ahead of its face (warm core), nothing past the range cap, nothing behind its own wall.
## pools: "" or the failing lamps; report: per lamp numbers; plant_pools: every facing flipped (light behind the
## wall), must be "caught".

const Pools := preload("res://scripts/graphics/light_rt/pools.gd")
const LampPools := preload("res://scripts/world/camp/lamp_pools.gd")
const MIN_CORE := 0.08

var pools: String:
	get:
		return _run(false)[0]
var report: String:
	get:
		return _run(false)[1]
var plant_pools: String:
	get:
		var r: String = _run(true)[0]
		return "caught" if r != "" else "missed"

static func _run(plant: bool) -> Array:
	var root: Node = (Engine.get_main_loop() as SceneTree).current_scene
	Pools.plant_flip = plant
	LampPools.apply(root, [])
	Pools.plant_flip = false
	var bad := PackedStringArray()
	var rows := PackedStringArray()
	var lamps: Array = root.get_tree().get_nodes_in_group("hub_lamp")
	if lamps.is_empty():
		bad.append("no hub_lamp")
	for lamp: Node in lamps:
		var n := lamp as Node3D
		var flame: Node3D = n.get_meta("flame", n) as Node3D
		var p: Vector3 = flame.global_position
		var f3: Vector3 = n.global_basis.z
		var f := Vector2(f3.x, f3.z).normalized()
		var ahead := Vector3(p.x + f.x * 0.6, 0.0, p.z + f.y * 0.6)
		var behind := Vector3(p.x - f.x * 0.6, 0.0, p.z - f.y * 0.6)
		var far := Vector3(p.x + f.x * (float(Pools.LANTERN["range"]) + 0.2), 0.0, p.z + f.y * (float(Pools.LANTERN["range"]) + 0.2))
		var up := Vector3.UP
		var a: float = Pools.light_at(ahead, up, 0.0).get_luminance()
		var b: float = Pools.light_at(behind, up, 0.0).get_luminance()
		var c: float = Pools.light_at(far, up, 0.0).get_luminance()
		rows.append("%s ahead=%.3f behind=%.3f past_cap=%.3f" % [n.get_path(), a, b, c])
		if a < MIN_CORE or b > 0.001 or c > 0.001:
			bad.append("%s a=%.3f b=%.3f c=%.3f" % [n.name, a, b, c])
	LampPools.apply(root, [])
	return [", ".join(bad), " | ".join(rows)]
