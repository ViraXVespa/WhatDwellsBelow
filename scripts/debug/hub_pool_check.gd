extends RefCounted

## Lantern pools (light_rt/pools.gd, camp/lamp_pools.gd), CPU twin of the shader: every hub_lamp lights the yard
## 0.6 m ahead of its face (warm core), nothing past the range cap, nothing behind its own wall.
## pools: "" or the failing lamps; report: per lamp numbers; plant_pools: every facing flipped (light behind the
## wall), must be "caught". mask: "" or the lit points pool_mask would skip (the shader returns 0 there);
## plant_mask: the mask shifted 1 m, must be "caught".

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

var mask: String:
	get:
		return _mask_run(false)
var plant_mask: String:
	get:
		return "caught" if _mask_run(true) != "" else "missed"

static func _mask_run(plant: bool) -> String:
	LampPools.apply(App.Touch.scene_host(), [])
	if plant:
		Pools._mask_rect.x += 1.0
	var bad := PackedStringArray()
	var lit := 0
	for i in Pools._n:
		var v: Vector4 = Pools._p[i]
		var x: float = v.x - v.w - 0.3
		while x <= v.x + v.w + 0.3:
			var z: float = v.z - v.w - 0.3
			while z <= v.z + v.w + 0.3:
				if Pools.light_at(Vector3(x, 0.0, z), Vector3.UP, 0.0).get_luminance() > 0.0:
					lit += 1
					if not Pools.mask_at(Vector2(x, z)) and bad.size() < 4:
						bad.append("%.2f,%.2f" % [x, z])
				z += 0.07
			x += 0.07
	LampPools.apply(App.Touch.scene_host(), [])
	return "no lit points" if lit == 0 else ", ".join(bad)

static func _run(plant: bool) -> Array:
	var root: Node = App.Touch.scene_host()
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
