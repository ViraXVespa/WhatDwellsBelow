extends Object

const T := preload("res://scripts/data/tunables.gd")
const Build := preload("res://scripts/world/camp_build.gd")

const WARM_SPAN_PAD := 1.25


static func yard_center() -> Vector3:
	var x0: float = float(Build.GROUND_OX - Build.GRASS_PAD)
	var z0: float = float(Build.GROUND_OZ - Build.GRASS_PAD)
	var x1: float = float(Build.GROUND_OX + Build.GROUND_W + Build.GRASS_PAD)
	var z1: float = float(Build.GROUND_OZ + Build.GROUND_D + Build.GRASS_PAD)
	return Vector3((x0 + x1) * 0.5, 0.0, (z0 + z1) * 0.5)


static func yard_size() -> float:
	var span_x: float = float(Build.GROUND_W + Build.GRASS_PAD * 2)
	var span_z: float = float(Build.GROUND_D + Build.GRASS_PAD * 2)
	return maxf(span_x, span_z) * WARM_SPAN_PAD


static func _rig(scene: Node) -> Node:
	if scene == null:
		return null
	if not ("player" in scene) or scene.player == null:
		return null
	var p: Node = scene.player
	if not ("rig" in p) or p.rig == null:
		return null
	return p.rig


static func frame(scene: Node) -> void:
	var rig: Node = _rig(scene)
	if rig == null or not rig.has_method("frame_hub"):
		return
	rig.frame_hub(yard_center(), yard_size())
	pulse()


static func restore(scene: Node) -> void:
	var rig: Node = _rig(scene)
	if rig and rig.has_method("restore_user"):
		rig.restore_user()
	var p: Node = null
	if scene and ("player" in scene):
		p = scene.player
	if p and rig and rig.has_method("follow"):
		rig.follow(p.global_position)
	pulse()


static func pulse() -> void:
	RenderingServer.force_draw()
