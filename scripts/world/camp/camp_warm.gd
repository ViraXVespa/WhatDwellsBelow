extends Object

const T := preload("res://scripts/data/tunables.gd")
const Build := preload("res://scripts/world/camp_build/camp_build.gd")

const WARM_SPAN_PAD := 1.25

static func _layout(scene: Node) -> Node3D:
    if scene == null:
        return null
    var n: Node = scene.get_node_or_null("Layout")
    if n is Node3D:
        return n as Node3D
    return null

static func yard_center_of(scene: Node) -> Vector3:
    var lay: Node3D = _layout(scene)
    if lay:
        return Vector3((lay.aabb_x0() + lay.aabb_x1()) * 0.5, 0.0, (lay.aabb_z0() + lay.aabb_z1()) * 0.5)
    var x0: float = float(Build.GROUND_OX - Build.GRASS_PAD)
    var z0: float = float(Build.GROUND_OZ - Build.GRASS_PAD)
    var x1: float = float(Build.GROUND_OX + Build.GROUND_W + Build.GRASS_PAD)
    var z1: float = float(Build.GROUND_OZ + Build.GROUND_D + Build.GRASS_PAD)
    return Vector3((x0 + x1) * 0.5, 0.0, (z0 + z1) * 0.5)

static func yard_size() -> float:
    var span_x: float = float(Build.GROUND_W + Build.GRASS_PAD * 2)
    var span_z: float = float(Build.GROUND_D + Build.GRASS_PAD * 2)
    return maxf(span_x, span_z) * WARM_SPAN_PAD

static func yard_size_of(scene: Node) -> float:
    var lay: Node3D = _layout(scene)
    if lay:
        var span_x: float = float(lay.ground_w + lay.grass_pad * 2)
        var span_z: float = float(lay.ground_d + lay.grass_pad * 2)
        return maxf(span_x, span_z) * WARM_SPAN_PAD
    return yard_size()

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
    rig.frame_hub(yard_center_of(scene), yard_size_of(scene))
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
