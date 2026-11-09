extends Object

## Split from actor_lit.gd: _tick, _lay, _usable....

const K := preload("res://scripts/graphics/actor_lit/lit_k.gd")
const Drive := preload("res://scripts/graphics/actor_lit/drive.gd")
const LightRt := preload("res://scripts/graphics/light_rt.gd")
const Place := preload("res://scripts/graphics/actor_lit/place.gd")
const Pool := preload("res://scripts/graphics/actor_lit/lit_pool.gd")

static func _tick(host: Node3D, delta: float) -> void:
	if host.spr == null or not is_instance_valid(host.spr):
		Pool._release_all(host)
		host.queue_free()
		return
	var body: Node = host.get_parent()
	if body != null and body.get("dead") == true:
		Pool._release_all(host)
		host.set_process(false)
		return
	var actor: Node3D = body as Node3D
	if actor == null:
		return
	if not App.in_dungeon:
		host._hub_sun = true
		host._in_light = true
	# An explicit lit._process from a debug check runs with processing off.
	var manual: bool = not host.is_processing()
	var t0: int = host._mark_t()
	_push_feet(host)
	host._mark_us(0, t0)
	if host.spr.flip_h != host._flip:
		host._flip = host.spr.flip_h
		host._dirty = true
	var tex_id: int = 0
	if host.spr.texture != null:
		tex_id = host.spr.texture.get_instance_id()
	var pose: Array = [host.spr.flip_h, host.plant_flat, K.plant_ungrid, actor.global_position, host.air_force, host.solid, host.foot, host.spr.pixel_size, tex_id]
	if not manual and not host._in_light:
		Pool._release_all(host)
		host.set_process(false)
		return
	if not manual and host._posed and not host._dirty and not host._easing and pose == host._pose:
		host.set_process(false)
		return
	host._pose = pose
	host._dirty = false
	host._posed = true
	var before_a: PackedFloat32Array = PackedFloat32Array()
	var before_d: Array[Vector2] = []
	for slot in K.MARK_N:
		before_a.append(host._alpha_at[slot])
		before_d.append(host._away_at[slot])
	_lay(host, actor, delta)
	host._easing = false
	for slot in K.MARK_N:
		if absf(host._alpha_at[slot] - before_a[slot]) > 0.001:
			host._easing = true
		if host._away_at[slot].distance_squared_to(before_d[slot]) > 0.0004:
			host._easing = true
	if host._easing or host._dirty:
		host.set_process(true)
	elif not manual:
		host.set_process(false)

static func _lay(host: Node3D, body: Node3D, delta: float) -> void:
	if host.spr.texture == null or not host.spr.visible:
		Pool._release_all(host)
		return
	var feet: Vector2 = Vector2(body.global_position.x, body.global_position.z)
	if App.in_dungeon and not LightRt.floor_open(feet):
		Pool._release_all(host)
		return
	var tex: Texture2D = host.spr.texture
	if not _usable(host, tex):
		Pool._release_all(host)
		return
	host._flip = host.spr.flip_h
	var t0: int = host._mark_t()
	if App.in_dungeon:
		Drive._drive_many(host, feet, delta)
	else:
		Drive._drive_hub(host, body, feet)
	host._mark_us(1, t0)
	Place._place(host, tex, feet)

static func _usable(_host: Node3D, tex: Texture2D) -> bool:
	return tex != null and tex.get_width() > 8 and tex.get_height() > 8

static func _wake(host: Node3D) -> void:
	if host.name == "MarkPool" or host.spr == null:
		return
	Pool._ensure_host(host)
	host._wake_n += 1
	var cam_ready: bool = host.get_viewport() != null and host.get_viewport().get_camera_3d() != null
	if not cam_ready and host._wake_n < 8:
		host.call_deferred("_wake")
		return
	if not App.in_dungeon:
		host._hub_sun = true
		host._in_light = true
	_push_feet(host)
	_push_albedo(host)
	Place.warm(host)
	host._dirty = true
	host.set_process(true)
	if App.in_dungeon:
		host.call_deferred("retouch")

static func _near_casts(_host: Node3D, body: Node3D) -> int:
	var feet: Vector2 = Vector2(body.global_position.x, body.global_position.z)
	var n: int = 0
	for item in LightRt._casts:
		var xz: Vector2 = item["xz"]
		var reach: float = float(item["reach"])
		if feet.distance_to(xz) <= maxf(reach, 0.25):
			n += 1
	return n

static func _push_feet(host: Node3D) -> void:
	if host._spr_mat == null or host.spr == null:
		return
	var body: Node3D = host.get_parent() as Node3D
	if body == null:
		return
	host._spr_mat.set_shader_parameter("feet_xz", Vector2(body.global_position.x, body.global_position.z))

static func _push_albedo(host: Node3D) -> void:
	if host._spr_mat == null or host.spr == null:
		return
	host._spr_mat.set_shader_parameter("albedo_tex", host.spr.texture)
