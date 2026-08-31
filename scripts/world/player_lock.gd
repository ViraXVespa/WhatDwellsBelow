extends Object

const Combat := preload("res://scripts/combat/combat.gd")


static func ai_on() -> bool:
	return App.playtest != null and bool(App.playtest.get("ai_on"))


static func ai_or_vec(host: Node, which: String) -> Vector2:
	if ai_on():
		var raw: Variant = App.playtest.aim if which == "aim" else App.playtest.move
		if raw is Vector2:
			var v: Vector2 = raw
			if which != "aim" or v.length() > 0.1:
				return v
	if which == "aim":
		return App.pad_aim()
	return App.pad_move()


static func ai_just(host: Node, action: String) -> bool:
	if not ai_on():
		return false
	var raw: Variant = App.playtest.just
	if raw is Dictionary:
		return bool((raw as Dictionary).get(action, false))
	return false


static func ai_held(host: Node, action: String) -> bool:
	if not ai_on():
		return false
	if action == "attack":
		return bool(App.playtest.attack)
	if action == "special":
		return bool(App.playtest.special)
	return false


static func lock_and_aim(host: Node, move: Vector2, delta: float) -> void:
	if Input.is_action_just_pressed("target_lock") or App.pad_just("target_lock"):
		if host.lock_armed:
			host.lock_armed = false
			host.lock_target = null
		else:
			host.lock_armed = true
			acquire_lock(host)
	if host.lock_armed:
		if not valid_lock(host, host.lock_target):
			acquire_lock(host)
		if valid_lock(host, host.lock_target):
			var tp: Vector3 = (host.lock_target as Node3D).global_position
			var d := Vector2(tp.x - host.global_position.x, tp.z - host.global_position.z)
			if d.length() > 0.001:
				host.aim_dir = d.normalized()
		var stick := ai_or_vec(host, "aim")
		if stick.length() > App.bal.lock_stick_deadzone:
			host.stick_hold += delta
			if host.stick_hold >= App.bal.lock_stick_delay:
				cycle_lock(host, stick.normalized())
				host.stick_hold = 0.0
		else:
			host.stick_hold = 0.0
		return
	update_aim(host, move)


static func valid_lock(host: Node, n: Node) -> bool:
	if n == null or not is_instance_valid(n):
		return false
	if n.has_method("is_alive") and not n.is_alive():
		return false
	var cam: Camera3D = host.get_viewport().get_camera_3d()
	if not Combat.on_screen(n as Node3D, cam):
		return false
	return Combat.los(host.global_position, (n as Node3D).global_position, host.get_world_3d())


static func acquire_lock(host: Node) -> void:
	host.lock_target = nearest(host, null, Vector2.ZERO)
	if host.lock_target == null:
		host.lock_armed = true


static func cycle_lock(host: Node, dir: Vector2) -> void:
	var n := nearest(host, host.lock_target, dir)
	if n:
		host.lock_target = n


static func nearest(host: Node, exclude: Node, dir: Vector2) -> Node:
	var best: Node = null
	var best_s := 1.0e9
	for e in Combat.enemies():
		if e == exclude or not valid_lock(host, e):
			continue
		var d := Combat.xz(e) - Vector2(host.global_position.x, host.global_position.z)
		var score := d.length()
		if dir.length_squared() > 0.0001:
			score = 2.5 - d.normalized().dot(dir) + d.length() * 0.05
		if score < best_s:
			best_s = score
			best = e
	return best


static func mouse_aim_dir(host: Node) -> Vector2:
	var cam := host.get_viewport().get_camera_3d()
	if cam == null:
		return Vector2.ZERO
	var mouse := host.get_viewport().get_mouse_position()
	var from := cam.project_ray_origin(mouse)
	var dir := cam.project_ray_normal(mouse)
	var hit: Variant = Plane(Vector3.UP, 0.0).intersects_ray(from, dir)
	if hit == null:
		return Vector2.ZERO
	var p: Vector3 = hit
	var d := Vector2(p.x - host.global_position.x, p.z - host.global_position.z)
	if d.length_squared() < 0.0004:
		return Vector2.ZERO
	return d.normalized()


static func update_aim(host: Node, move: Vector2) -> void:
	var stick := ai_or_vec(host, "aim")
	if stick.length() >= 0.24:
		host.aim_dir = stick.normalized()
		return
	if App.using_pad():
		if move.length() >= 0.12:
			host.aim_dir = move.normalized()
		return
	var mouse_dir := mouse_aim_dir(host)
	if mouse_dir.length_squared() > 0.0001:
		host.aim_dir = mouse_dir
		return
	if move.length() >= 0.12:
		host.aim_dir = move.normalized()
