extends Node3D

## Feet tint is a GPU tap of the light RT at the actor's feet (ground-shader uv).
## Marks come from a shared pool while the actor is inside a light. Hub sun counts as inside.
## The vendor and the training dummy are not lit.

const LightRt := preload("res://scripts/graphics/light_rt.gd")
const HubCast := preload("res://scripts/graphics/light_rt/hub_cast.gd")
const K := preload("res://scripts/graphics/actor_lit/lit_k.gd")
const Drive := preload("res://scripts/graphics/actor_lit/drive.gd")
const Place := preload("res://scripts/graphics/actor_lit/place.gd")
static var _shade: Shader
static var _sprite_sh: Shader
## Debug plant (hub_shadow_check/feet_px.gd): the higher standing foot treated as raised (the one-foot-off of 20611abf).
static var plant_flat := false
## Sweep only. Off leaves live frames untimed. mark_us is the sum of this frame's _process.
## The part counters split that sum. foot_us, quad_us, albedo_us, and contact_us sit inside sync_us.
## sole_us and pin_us sit inside geo_us. The feet uniform sits inside tint_us.
## _max_us is the slowest single actor this frame.
static var mark_on: bool = false
static var mark_us: int = 0
static var tint_us: int = 0
static var drive_us: int = 0
static var geo_us: int = 0
static var sync_us: int = 0
static var foot_us: int = 0
static var quad_us: int = 0
static var shade_us: int = 0
static var albedo_us: int = 0
static var contact_us: int = 0
static var sole_us: int = 0
static var pin_us: int = 0
static var _max_us: int = 0
static var _max_who: String = ""
static var _pool: Array[MeshInstance3D] = []
static var _pool_host: Node3D
static var _areas: Array[Area3D] = []
static var _cast_seen: int = -1

var spr: Sprite3D
var marks: Array[MeshInstance3D] = []
var _spr_mat: ShaderMaterial
var _key_at: Array[Array] = []
var _away_at: Array[Vector2] = []
var _stretch_at: Array[float] = []
var _alpha_at: Array[float] = []
var _src_at: Array[Vector2] = []
var _held: Array[bool] = []
var _rank_at: Array[int] = []
var _shade_at: Array[Color] = []
var _shade_set: Array[bool] = []
var _sun_at: Array[float] = []
var _grid_at: Array[float] = []
var _contact_on: Array[float] = []
var _albedo_id: Array[int] = []
var _contact_id: Array[int] = []
## Last hull count pushed to slot 0. -1 means bind has not run. Avoids a shader read every frame.
var _hull_n: int = -1
var _ink_budget: float = 0.0
var _flip: bool = false
## Deep yard prop (camp_build.mark_props): "profile" / "raised" casts Soles._solid of the sticker; "" the sticker.
var solid: String = ""
## Profile footprint depth (texels): the mark's contact tucks this far up-screen under the curved base.
var foot: int = 0
## Airborne mark (enemy move_kind fly / hop, or forced by the mark matrix): last altitude (m) above the floor.
var air_force: bool = false
var lift: float = 0.0
var _hub_sun: bool = false
var _in_light: bool = false
var _dirty: bool = true
var _posed: bool = false
var _pose: Array = []
var _easing: bool = false
var _wake_n: int = 0

static func bind(body: Node3D, sticker: Sprite3D) -> void:
	if body == null or sticker == null:
		return
	var script: GDScript = load("res://scripts/graphics/actor_lit.gd") as GDScript
	var lit: Node = script.new() as Node
	if lit == null:
		return
	lit.set("spr", sticker)
	lit.name = "ActorLit"
	body.add_child(lit)

func _ready() -> void:
	if name == "MarkPool":
		set_process(true)
		return
	set_process(false)
	set_notify_transform(true)
	marks.resize(K.MARK_N)
	for slot in K.MARK_N:
		_key_at.append([])
		_away_at.append(K.SUN_AWAY)
		_stretch_at.append(K.HUB_STRETCH)
		var start_a: float = 0.0
		if slot == 0:
			start_a = K.HUB_ALPHA
		_alpha_at.append(start_a)
		_src_at.append(Vector2.ZERO)
		_held.append(false)
		_rank_at.append(slot)
		_shade_at.append(Color(0.0, 0.0, 0.0, 0.0))
		_shade_set.append(false)
		_sun_at.append(-1.0)
		_grid_at.append(-1.0)
		_contact_on.append(-1.0)
		_albedo_id.append(-1)
		_contact_id.append(-1)
	_bind_sprite()
	add_to_group("actor_lit")
	tree_exiting.connect(_release_all)
	call_deferred("_wake")

func _wake() -> void:
	if name == "MarkPool" or spr == null:
		return
	_ensure_host()
	_wake_n += 1
	var cam_ready: bool = get_viewport() != null and get_viewport().get_camera_3d() != null
	if not cam_ready and _wake_n < 8:
		call_deferred("_wake")
		return
	if not App.in_dungeon:
		_hub_sun = true
		_in_light = true
	_push_feet()
	_push_albedo()
	Place.warm(self)
	_dirty = true
	set_process(true)
	if App.in_dungeon:
		call_deferred("retouch")

func _notification(what: int) -> void:
	if what != NOTIFICATION_TRANSFORM_CHANGED or name == "MarkPool":
		return
	_push_feet()
	if _in_light or _hub_sun:
		_dirty = true
		set_process(true)

## Standing turn: flip_h does not emit a signal, so the presenter notes it.
func note_flip() -> void:
	_dirty = true
	set_process(true)

## Absolute overlap count. Enter and exit both land here, so a double signal cannot stack.
## Gather nodes and breakables are plain Node3D, so they use the cast reach instead of the area.
func retouch() -> void:
	if name == "MarkPool" or _hub_sun:
		return
	var host: Node3D = get_parent() as Node3D
	var n: int = 0
	var phys: CollisionObject3D = host as CollisionObject3D
	if phys != null:
		for area in _areas:
			if is_instance_valid(area) and area.overlaps_body(phys):
				n += 1
	elif host != null:
		n = _near_casts(host)
	var was: bool = _in_light
	_in_light = n > 0
	if _in_light or was:
		_dirty = true
		set_process(true)

func _near_casts(host: Node3D) -> int:
	var feet: Vector2 = Vector2(host.global_position.x, host.global_position.z)
	var n: int = 0
	for item in LightRt._casts:
		var xz: Vector2 = item["xz"]
		var reach: float = float(item["reach"])
		if feet.distance_to(xz) <= maxf(reach, 0.25):
			n += 1
	return n

func _process(delta: float) -> void:
	if name == "MarkPool":
		_watch_casts()
		return
	if not mark_on:
		_tick(delta)
		return
	var t0: int = Time.get_ticks_usec()
	_tick(delta)
	var dt: int = Time.get_ticks_usec() - t0
	mark_us += dt
	if dt > _max_us:
		_max_us = dt
		var body: Node = get_parent()
		var who: String = ""
		while body != null and who == "":
			var nm: String = str(body.name)
			if not nm.begins_with("@"):
				who = nm
			body = body.get_parent()
		_max_who = who

func _tick(delta: float) -> void:
	if spr == null or not is_instance_valid(spr):
		_release_all()
		queue_free()
		return
	var body: Node = get_parent()
	if body != null and body.get("dead") == true:
		_release_all()
		set_process(false)
		return
	var host: Node3D = body as Node3D
	if host == null:
		return
	if not App.in_dungeon:
		_hub_sun = true
		_in_light = true
	# An explicit lit._process from a debug check runs with processing off.
	var manual: bool = not is_processing()
	var t0: int = _mark_t()
	_push_feet()
	_mark_us(0, t0)
	if spr.flip_h != _flip:
		_flip = spr.flip_h
		_dirty = true
	var tex_id: int = 0
	if spr.texture != null:
		tex_id = spr.texture.get_instance_id()
	var pose: Array = [spr.flip_h, plant_flat, K.plant_ungrid, host.global_position, air_force, solid, foot, spr.pixel_size, tex_id]
	if not manual and not _in_light:
		_release_all()
		set_process(false)
		return
	if not manual and _posed and not _dirty and not _easing and pose == _pose:
		set_process(false)
		return
	_pose = pose
	_dirty = false
	_posed = true
	var before_a: PackedFloat32Array = PackedFloat32Array()
	var before_d: Array[Vector2] = []
	for slot in K.MARK_N:
		before_a.append(_alpha_at[slot])
		before_d.append(_away_at[slot])
	_lay(host, delta)
	_easing = false
	for slot in K.MARK_N:
		if absf(_alpha_at[slot] - before_a[slot]) > 0.001:
			_easing = true
		if _away_at[slot].distance_squared_to(before_d[slot]) > 0.0004:
			_easing = true
	if _easing or _dirty:
		set_process(true)
	elif not manual:
		set_process(false)

func _lay(host: Node3D, delta: float) -> void:
	if spr.texture == null or not spr.visible:
		_release_all()
		return
	var feet: Vector2 = Vector2(host.global_position.x, host.global_position.z)
	if App.in_dungeon and not LightRt.floor_open(feet):
		_release_all()
		return
	var tex: Texture2D = spr.texture
	if not _usable(tex):
		_release_all()
		return
	_flip = spr.flip_h
	var t0: int = _mark_t()
	if App.in_dungeon:
		Drive._drive_many(self, feet, delta)
	else:
		Drive._drive_hub(self, host, feet)
	_mark_us(1, t0)
	Place._place(self, tex, feet)

func _claim(slot: int) -> MeshInstance3D:
	var node: MeshInstance3D = _take_node()
	marks[slot] = node
	_albedo_id[slot] = -1
	_contact_id[slot] = -1
	_shade_set[slot] = false
	_sun_at[slot] = -1.0
	_grid_at[slot] = -1.0
	_contact_on[slot] = -1.0
	_key_at[slot] = []
	if node.get_parent() != self:
		node.reparent(self)
	node.visible = true
	return node

func _release(slot: int) -> void:
	if slot < 0 or slot >= marks.size():
		return
	var node: MeshInstance3D = marks[slot]
	if node == null:
		return
	node.visible = false
	marks[slot] = null
	_park(node)

func _release_all() -> void:
	for slot in marks.size():
		_release(slot)

func _bind_sprite() -> void:
	if spr == null:
		return
	if _sprite_sh == null:
		var sh: Shader = Shader.new()
		sh.code = K.SPRITE
		_sprite_sh = sh
	var mat: ShaderMaterial = ShaderMaterial.new()
	mat.shader = _sprite_sh
	mat.render_priority = spr.render_priority
	mat.set_shader_parameter("cut", spr.alpha_scissor_threshold)
	_spr_mat = mat
	LightRt.bind(mat)
	_push_albedo()
	_push_feet()
	spr.material_override = mat
	if not spr.texture_changed.is_connected(_on_tex):
		spr.texture_changed.connect(_on_tex)

func _on_tex() -> void:
	_push_albedo()
	Place.warm(self)
	if _in_light or _hub_sun:
		_dirty = true
		set_process(true)

func _push_feet() -> void:
	if _spr_mat == null or spr == null:
		return
	var body: Node3D = get_parent() as Node3D
	if body == null:
		return
	_spr_mat.set_shader_parameter("feet_xz", Vector2(body.global_position.x, body.global_position.z))

func _push_albedo() -> void:
	if _spr_mat == null or spr == null:
		return
	_spr_mat.set_shader_parameter("albedo_tex", spr.texture)

func _biased(away: Vector2) -> Vector2:
	return Place._biased(self, away)

func _usable(tex: Texture2D) -> bool:
	return tex != null and tex.get_width() > 8 and tex.get_height() > 8

func _watch_casts() -> void:
	if LightRt._casts_ver == _cast_seen:
		return
	_cast_seen = LightRt._casts_ver
	_rebuild_areas()

func _rebuild_areas() -> void:
	var host: Node3D = _pool_host
	if host == null:
		return
	for area in _areas:
		if is_instance_valid(area):
			area.queue_free()
	_areas.clear()
	if App.in_dungeon:
		for item in LightRt._casts:
			var xz: Vector2 = item["xz"]
			var reach: float = float(item["reach"])
			var area: Area3D = Area3D.new()
			area.monitoring = true
			area.monitorable = false
			area.collision_layer = 0
			area.collision_mask = 6
			area.top_level = true
			var shape_node: CollisionShape3D = CollisionShape3D.new()
			var sphere: SphereShape3D = SphereShape3D.new()
			sphere.radius = maxf(reach, 0.25)
			shape_node.shape = sphere
			area.add_child(shape_node)
			host.add_child(area)
			area.global_position = Vector3(xz.x, 0.4, xz.y)
			area.body_entered.connect(_body_in)
			area.body_exited.connect(_body_out)
			_areas.append(area)
	var tree: SceneTree = Engine.get_main_loop() as SceneTree
	if tree != null and not tree.physics_frame.is_connected(_retouch_all):
		tree.physics_frame.connect(_retouch_all, CONNECT_ONE_SHOT)

func _body_in(body: Node) -> void:
	_retouch_one(body)

func _body_out(body: Node) -> void:
	_retouch_one(body)

func _retouch_one(body: Node) -> void:
	if body == null:
		return
	var lit: Node = body.get_node_or_null("ActorLit")
	if lit != null and lit.has_method("retouch"):
		lit.retouch()

func _retouch_all() -> void:
	var tree: SceneTree = Engine.get_main_loop() as SceneTree
	if tree == null:
		return
	for lit in tree.get_nodes_in_group("actor_lit"):
		if lit.has_method("retouch"):
			lit.retouch()

func _ensure_host() -> Node3D:
	if _pool_host != null and is_instance_valid(_pool_host):
		return _pool_host
	var tree: SceneTree = Engine.get_main_loop() as SceneTree
	if tree == null:
		return null
	var script: GDScript = load("res://scripts/graphics/actor_lit.gd") as GDScript
	var host: Node3D = script.new() as Node3D
	host.name = "MarkPool"
	_pool_host = host
	tree.root.add_child(host)
	var made: int = 0
	while made < K.POOL_N:
		_park(_new_mark())
		made += 1
	return host

func _new_mark() -> MeshInstance3D:
	var mesh_node: MeshInstance3D = MeshInstance3D.new()
	mesh_node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var mat: ShaderMaterial = _mat()
	mat.render_priority = -2
	mesh_node.sorting_offset = -30.0
	mesh_node.material_override = mat
	mesh_node.visible = false
	mesh_node.top_level = true
	if _pool_host != null:
		_pool_host.add_child(mesh_node)
	return mesh_node

func _take_node() -> MeshInstance3D:
	_ensure_host()
	while not _pool.is_empty():
		var node: MeshInstance3D = _pool.pop_back()
		if is_instance_valid(node):
			return node
	return _new_mark()

func _park(node: MeshInstance3D) -> void:
	if node == null or not is_instance_valid(node):
		return
	node.visible = false
	if _pool_host != null and node.get_parent() != _pool_host:
		node.reparent(_pool_host)
	_pool.append(node)

static func arm_mark() -> void:
	mark_on = true
	mark_us = 0
	tint_us = 0
	drive_us = 0
	geo_us = 0
	sync_us = 0
	foot_us = 0
	quad_us = 0
	shade_us = 0
	albedo_us = 0
	contact_us = 0
	sole_us = 0
	pin_us = 0
	_max_us = 0
	_max_who = ""

static func max_ms() -> float:
	return float(_max_us) / 1000.0

static func max_who() -> String:
	return _max_who

static func mark_off() -> void:
	mark_on = false

static func mark_ms() -> float:
	return float(mark_us) / 1000.0

## Order: tint, drive, geo, sync, foot, quad, shade, albedo, contact, sole, pin.
## foot, quad, albedo, and contact are inside sync. sole and pin are inside geo.
static func parts_ms() -> PackedFloat32Array:
	return PackedFloat32Array([
		float(tint_us) / 1000.0,
		float(drive_us) / 1000.0,
		float(geo_us) / 1000.0,
		float(sync_us) / 1000.0,
		float(foot_us) / 1000.0,
		float(quad_us) / 1000.0,
		float(shade_us) / 1000.0,
		float(albedo_us) / 1000.0,
		float(contact_us) / 1000.0,
		float(sole_us) / 1000.0,
		float(pin_us) / 1000.0,
	])

func _mark_t() -> int:
	if not mark_on:
		return 0
	return Time.get_ticks_usec()

func _mark_us(bucket: int, t0: int) -> void:
	if not mark_on or t0 == 0:
		return
	var dt: int = Time.get_ticks_usec() - t0
	if bucket == 0:
		tint_us += dt
	elif bucket == 1:
		drive_us += dt
	elif bucket == 2:
		geo_us += dt
	elif bucket == 3:
		sync_us += dt
	elif bucket == 4:
		foot_us += dt
	elif bucket == 5:
		quad_us += dt
	elif bucket == 6:
		shade_us += dt
	elif bucket == 7:
		albedo_us += dt
	elif bucket == 8:
		contact_us += dt
	elif bucket == 9:
		sole_us += dt
	elif bucket == 10:
		pin_us += dt

static func _mat() -> ShaderMaterial:
	if _shade == null:
		var sh: Shader = Shader.new()
		sh.code = K.SHADE
		_shade = sh
	var mat: ShaderMaterial = ShaderMaterial.new()
	mat.shader = _shade
	mat.render_priority = 8
	mat.set_shader_parameter("floor_l", HubCast.SHADE_NEAR)
	LightRt.bind(mat)
	return mat
