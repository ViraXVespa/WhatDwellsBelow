extends RefCounted

## Shot flow ops that play the game for movies and motion proofs. They drive the player through the
## playtest hooks (App.playtest.ai_on / move / aim / attack / just, read by player_lock.gd), the same path
## the hub bench walks with, so the player moves, swings and opens things exactly like a pad would.
##   walk_to {x, z, look?, max_ms}   steer on the ground plane until within `near` (0.45) m, then stop
##   drive {move [x,z], aim [x,z], attack, ms | frames}   hold a world-space stick (and attack) for a time
##   tap {action}   one-frame press of interact / attack / dash / special
##   mark {name}    print `SHOT: mark name=N frame=F` (movie trims cut at marks)

const Ops := preload("res://scripts/debug/shot_tool/step_ops.gd")

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
