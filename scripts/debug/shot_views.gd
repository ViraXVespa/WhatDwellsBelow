extends RefCounted

## Shot views normal play cannot show (target "script:debug/shot_views" in shot flows; catalog in tools/data/movies.json).
## Debug only: nothing here is reachable from a player build path.

## Game APIs are looked up at runtime so an older ref (shots.py movie --refs) still parses this file.
const HIT_PATH := "res://scripts/combat/enemy/enemy_hit.gd"

static func _tree() -> SceneTree:
	return Engine.get_main_loop() as SceneTree

static func _rig() -> Node:
	var cam: Camera3D = _tree().root.get_viewport().get_camera_3d()
	return cam.get_parent() if cam != null and cam.get_parent().has_method("frame_hub") else null

## Camera pitch in degrees (-90 = straight down; play is about -58), applied now.
func pitch(deg: float) -> void:
	App.get("bal").set("cam_pitch", deg)
	var rig: Node = _rig()
	if rig != null:
		rig.call("_place_local")
		rig.call("_look")

## The whole hub yard in frame from above (size 0 = the camp warm-up framing x `scale`).
func hub_overhead(scale: float, deg: float) -> void:
	var scene: Node = _tree().current_scene
	var warm: GDScript = load("res://scripts/world/camp/warm.gd") as GDScript
	var rig: Node = _rig()
	if rig == null or warm == null:
		printerr("SHOT: fail op=call why=hub_overhead needs the camp and its camera rig")
		return
	App.get("bal").set("cam_pitch", deg)
	rig.call("frame_hub", warm.call("yard_center_of", scene), float(warm.call("yard_size_of", scene)) * scale)

## Viewport debug draw: overdraw (layer cost heat), lighting (light only) or off. Wireframe and unshaded draw nothing
## different on the gl_compatibility renderer, so they are not offered.
func debug_draw(mode: String) -> void:
	var modes: Dictionary = {"off": Viewport.DEBUG_DRAW_DISABLED, "overdraw": Viewport.DEBUG_DRAW_OVERDRAW, "lighting": Viewport.DEBUG_DRAW_LIGHTING}
	_tree().root.get_viewport().debug_draw = modes.get(mode, Viewport.DEBUG_DRAW_DISABLED)

## Build every dungeon chunk now (fly-throughs and wide shots see the whole floor).
func stream_all() -> void:
	var host: Node = _tree().current_scene
	(load("res://scripts/world/dungeon_stream.gd") as GDScript).call("force_all", host)

## Fly the camera from the arrival spawn through the nearest unvisited room each hop (`hops` hops, 0 = every room), `ms`
## per hop, camera size `size` (0 keeps it). The timeline waits about hops x ms; SHOT: log prints hops and seconds.
func fly_rooms(ms: int, size: float, hops: int) -> void:
	var host: Node = _tree().current_scene
	var rig: Node = _rig()
	var data: Variant = host.get("data")
	if rig == null or not (data is Dictionary):
		printerr("SHOT: fail op=call why=fly_rooms needs a dungeon floor")
		return
	var left: Array = []
	for r: Variant in (data as Dictionary).get("rooms", []):
		if r is Dictionary:
			left.append(Vector3(float(r.x) + float(r.w) * 0.5, 0.0, float(r.y) + float(r.h) * 0.5))
	var sp: Vector2i = (data as Dictionary).get("spawn", Vector2i.ZERO)
	var path: Array = [Vector3(sp.x + 0.5, 0.0, sp.y + 0.5)]
	while not left.is_empty() and (hops <= 0 or path.size() <= hops):
		left.sort_custom(func(a: Vector3, b: Vector3) -> bool: return a.distance_to(path[-1]) < b.distance_to(path[-1]))
		path.append(left.pop_front())
	var s: float = size if size > 0.0 else float((rig.get("cam") as Camera3D).size)
	var tw: Tween = host.create_tween()
	for i: int in range(1, path.size()):
		var a: Vector3 = path[i - 1]
		var b: Vector3 = path[i]
		tw.tween_method(func(t: float) -> void: rig.call("frame_hub", a.lerp(b, t), s), 0.0, 1.0, float(ms) / 1000.0).set_trans(Tween.TRANS_SINE)
	printerr("SHOT: log fly_rooms hops=%d sec=%.1f" % [path.size() - 1, float(ms * (path.size() - 1)) / 1000.0])

## Seeded kill-drop roll laid out as pickups below the player: one cell per kill (6 per row), its drops stacked.
func drop_grid(seed_n: int, n: int) -> void:
	var pl: Node3D = _tree().get_first_node_in_group("player") as Node3D
	if pl == null:
		return
	var hit: GDScript = load(HIT_PATH) as GDScript
	if not hit.get_script_method_list().any(func(m: Dictionary) -> bool: return m.name == "roll_drops"):
		printerr("SHOT: log drop_grid unsupported (no roll_drops at this ref)")
		return
	var bal: Object = App.get("bal")
	seed(seed_n)
	var gear: int = 0
	for i: int in n:
		var d: PackedStringArray = hit.call("roll_drops", false)
		if randf() < float(bal.get("enemy_gear_chance")) + float(bal.get("enemy_gear_floor")) * float(App.get("floor_n")):
			gear += 1
		var row: int = 0
		for k: String in d:
			var p: Node3D = (load("res://scripts/world/pickup.gd") as GDScript).new()
			_tree().current_scene.add_child(p)
			p.call("setup", k, pl.global_position + Vector3(float(i % 6) * 0.7 - 1.75, 0.0, 1.2 + float(floori(i / 6.0)) * 1.4 + row * 0.45), 3 if k == "gold" else 0)
			p.set("life", 0.0)
			p.set("_block_t", 9999.0)
			row += 1
	printerr("SHOT: log drop_grid seed=%d kills=%d gear=%d" % [seed_n, n, gear])

## Pin wall-clock HUD pulses (the danger gem alpha) after every frame's HUD refresh, so stills compare equal across refs
## and runs; ref-compare views call this before their shot. Older refs work too: it only touches the hud's `gem` if any.
func still_hud() -> void:
	var hud: Node = _tree().current_scene.get("hud") as Node if _tree().current_scene != null else null
	if hud == null:
		return
	var pin := GemPin.new()
	pin.process_priority = 1000
	hud.add_child(pin)
	printerr("SHOT: log still_hud")

class GemPin extends Node:
	func _process(_d: float) -> void:
		var g: CanvasItem = get_parent().get("gem") as CanvasItem
		if g != null:
			g.modulate.a = 1.0
