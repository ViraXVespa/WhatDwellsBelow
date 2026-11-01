extends RefCounted

## Stall front: the tarp's front eave must cover the front posts and the face art on their plane, so the hem hangs in
## front of them (else the face top sits in front of the hem and the art's black edge shows above the post tops).
## cover: "" when the built StallPitch reaches past every front post's outer face; plant_cover: the old eave at
## box depth / 2 (behind the posts), which must fail.

const Spec := preload("res://scripts/world/camp/layout_spec.gd")

var cover: String:
	get:
		return _run(false)
var plant_cover: String:
	get:
		return "caught" if _run(true) != "" else "missed"

static func _run(plant: bool) -> String:
	var root: Node = (Engine.get_main_loop() as SceneTree).current_scene
	var pitch := root.find_child("StallPitch", true, false) as MeshInstance3D
	if pitch == null:
		return "no_stall"
	var body := pitch.get_parent() as Node3D
	var eave: float = pitch.get_aabb().end.z
	if plant:
		eave = float(Spec.STALL["box"].z) * 0.5
	var lay: Node = root.find_child("Layout", true, false)
	var front: float = float(Spec.STALL["posts"].y) * float(Spec.STALL["box"].z) if lay == null else lay.stall_posts().y
	front += float(Spec.STALL["post_half"])
	return "" if eave >= front - 0.001 else "eave %.3f behind post front %.3f" % [eave, front]
