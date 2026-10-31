extends RefCounted

## Shot flow ops that play the game for movies and motion proofs. They drive the player through the
## playtest hooks (App.playtest.ai_on / move / aim / attack / just, read by player_lock.gd), the same path
## the hub bench walks with, so the player moves, swings and opens things exactly like a pad would.
##   walk_to {x, z, look?, max_ms}   steer on the ground plane until within `near` (0.45) m, then stop
##   drive {move [x,z], aim [x,z], attack, ms | frames}   hold a world-space stick (and attack) for a time
##   tap {action}   one-frame press of interact / attack / dash / special
##   mark {name}    print `SHOT: mark name=N frame=F` (movie trims cut at marks)
##   camera {at [x,z] | target REF, offset [dx,dz], zoom, ms, ease linear|inout, wait, follow}   frame a ground point or
##       node (step_ref path) at a zoom; ms > 0 glides there while the timeline goes on (wait: true blocks). Holds the
##       player's camera rig like the camp warm-up (frame_hub); follow: true glides back and hands the rig back.

const Ops := preload("res://scripts/debug/shot_tool/step_ops.gd")
const Ref := preload("res://scripts/debug/shot_tool/step_ref.gd")
const T := preload("res://scripts/data/tunables.gd")
static var _cam_gen: int = 0

static func _pt(st: Dictionary) -> Object:
	var pt: Object = App.playtest
	if pt == null:
		Ops.fail(st, "play", "no App.playtest (debug hooks off)")
	else:
		pt.set("ai_on", true)
	return pt

static func _vec(v: Variant, fallback: Vector2) -> Vector2:
	if v is Array and (v as Array).size() >= 2:
		return Vector2(float(v[0]), float(v[1]))
	return fallback

static func _frames_of(step: Dictionary) -> int:
	if step.has("frames"):
		return maxi(1, int(step.frames))
	return maxi(1, int(round(float(step.get("ms", 500)) / 1000.0 * float(Engine.physics_ticks_per_second))))

static func walk_to(st: Dictionary, step: Dictionary) -> void:
	var pt: Object = _pt(st)
	var who: Node3D = (st.host as Node).get("player") as Node3D
	if pt == null or who == null:
		Ops.fail(st, "walk_to", "no player")
		return
	var at := Vector2(float(step.get("x", 0.0)), float(step.get("z", 0.0)))
	var near: float = float(step.get("near", 0.45))
	var left: int = _frames_of({"ms": step.get("max_ms", 8000)})
	var tree: SceneTree = who.get_tree()
	var d: Vector2 = at - Vector2(who.global_position.x, who.global_position.z)
	while d.length() > near and left > 0:
		pt.set("move", d.normalized())
		pt.set("aim", _vec(step.get("look", null), d.normalized()))
		await tree.physics_frame
		left -= 1
		d = at - Vector2(who.global_position.x, who.global_position.z)
	pt.set("move", Vector2.ZERO)
	printerr("SHOT: walk_to x=%.2f z=%.2f left=%.2f ok=%s" % [at.x, at.y, d.length(), str(d.length() <= near).to_lower()])
	if d.length() > near and bool(step.get("must", true)):
		Ops.fail(st, "walk_to", "stopped %.2f m short" % d.length())

static func drive(st: Dictionary, step: Dictionary) -> void:
	var pt: Object = _pt(st)
	if pt == null:
		return
	pt.set("move", _vec(step.get("move", null), Vector2.ZERO))
	if step.has("aim"):
		pt.set("aim", _vec(step.aim, Vector2.DOWN))
	pt.set("attack", bool(step.get("attack", false)))
	var tree: SceneTree = (st.host as Node).get_tree()
	for i: int in _frames_of(step):
		await tree.physics_frame
	pt.set("move", Vector2.ZERO)
	pt.set("attack", false)

static func tap(st: Dictionary, step: Dictionary) -> void:
	var pt: Object = _pt(st)
	if pt == null:
		return
	var tree: SceneTree = (st.host as Node).get_tree()
	pt.set("just", {str(step.get("action", "interact")): true})
	await tree.physics_frame
	await tree.physics_frame
	pt.set("just", {})
	printerr("SHOT: tap action=%s" % str(step.get("action", "interact")))

static func mark(_st: Dictionary, step: Dictionary) -> void:
	printerr("SHOT: mark name=%s frame=%d" % [str(step.get("name", "mark")), Engine.get_frames_drawn()])

static func camera(st: Dictionary, step: Dictionary) -> void:
	var host: Node = st.host
	var player: Node3D = host.get("player") as Node3D
	var rig: Node3D = (player.get("rig") if player != null else null) as Node3D
	if rig == null:
		rig = host.get_tree().get_first_node_in_group("camera_rig") as Node3D
	if rig == null or rig.get("cam") == null:
		Ops.fail(st, "camera", "no camera rig")
		return
	var from_c: Vector3 = rig.global_position
	var to_c: Vector3 = from_c
	if step.has("at"):
		var a: Vector2 = _vec(step.at, Vector2(from_c.x, from_c.z))
		to_c = Vector3(a.x, from_c.y, a.y)
	elif step.has("target"):
		var n: Variant = Ref.get_value(host, str(step.target))
		if not (n is Node3D):
			Ops.fail(st, "camera", "target %s is not a Node3D" % str(step.target))
			return
		to_c = Vector3((n as Node3D).global_position.x, from_c.y, (n as Node3D).global_position.z)
	var off: Vector2 = _vec(step.get("offset", null), Vector2.ZERO)
	to_c += Vector3(off.x, 0.0, off.y)
	var from_s: float = (rig.get("cam") as Camera3D).size
	# follow hands back: without its own zoom it eases to the size the rig returns to (its pin, else the user zoom)
	var pin: float = float(rig.get("size_pin"))
	var home: float = pin if pin > 0.0 else T.base_size().y / float(T.PX) / clampf(App.cam_zoom, T.ZOOM_MIN, T.ZOOM_MAX)
	var to_s: float = from_s
	if step.has("zoom"):
		to_s = T.base_size().y / float(T.PX) / maxf(0.01, float(step.zoom))
	elif bool(step.get("follow", false)):
		to_s = home
	_cam_gen += 1
	rig.set("warm_hold", true)
	printerr("SHOT: camera at=%.2f,%.2f size=%.2f ms=%d follow=%s" % [to_c.x, to_c.z, to_s, int(step.get("ms", 0)), str(step.get("follow", false))])
	var job: Array = [rig, player, from_c, to_c, from_s, to_s, float(step.get("ms", 0)) / 1000.0, str(step.get("ease", "inout")), bool(step.get("follow", false)), _cam_gen, pin if not step.has("zoom") else to_s]
	_glide(host, job)
	var left: float = float(job[6]) if bool(step.get("wait", false)) else 0.0
	await host.get_tree().process_frame
	while left > 0.0:
		left -= host.get_process_delta_time()
		await host.get_tree().process_frame

## One camera move, then (unless it hands back) a hold: the rig is the player's child, so it is re-placed every frame.
static func _glide(host: Node, job: Array) -> void:
	var rig: Node3D = job[0]
	var player: Node3D = job[1]
	var dur: float = job[6]
	var t: float = 0.0
	while job[9] == _cam_gen and is_instance_valid(rig):
		var k: float = 1.0 if dur <= 0.0 else clampf(t / dur, 0.0, 1.0)
		var e: float = k if job[7] == "linear" else k * k * (3.0 - 2.0 * k)
		var goal: Vector3 = job[3]
		if job[8] and is_instance_valid(player):
			goal = Vector3(player.global_position.x, (job[2] as Vector3).y, player.global_position.z)
		rig.global_position = (job[2] as Vector3).lerp(goal, e)
		rig.call("apply_size", lerpf(job[4], job[5], e))
		if k >= 1.0 and job[8]:
			rig.position = Vector3.ZERO
			# job[10]: the rig's old pin, or the step's own zoom (was job[5] always: a zoomless follow pinned the glide size)
			rig.set("size_pin", job[10])
			rig.call("restore_user")
			return
		await host.get_tree().process_frame
		t += host.get_process_delta_time()

static func run(st: Dictionary, op: String, step: Dictionary) -> void:
	match op:
		"walk_to":
			await walk_to(st, step)
		"drive":
			await drive(st, step)
		"tap":
			await tap(st, step)
		"mark":
			mark(st, step)
		"camera":
			await camera(st, step)
