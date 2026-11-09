extends Node3D

## Feet tint is a GPU tap of the light RT at the actor's feet (ground-shader uv).
## Marks come from a shared pool while the actor is inside a light. Hub sun counts as inside.
## The vendor and the training dummy are not lit.

const LightRt := preload("res://scripts/graphics/light_rt.gd")
const HubCast := preload("res://scripts/graphics/light_rt/hub_cast.gd")
const K := preload("res://scripts/graphics/actor_lit/lit_k.gd")
const Drive := preload("res://scripts/graphics/actor_lit/drive.gd")
const Place := preload("res://scripts/graphics/actor_lit/place.gd")
const Pool := preload("res://scripts/graphics/actor_lit/lit_pool.gd")
const Tick := preload("res://scripts/graphics/actor_lit/lit_tick.gd")
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
	Tick._wake(self)

func _notification(what: int) -> void:
	if what != NOTIFICATION_TRANSFORM_CHANGED or name == "MarkPool":
		return
	Tick._push_feet(self)
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
		n = Tick._near_casts(self, host)
	var was: bool = _in_light
	_in_light = n > 0
	if _in_light or was:
		_dirty = true
		set_process(true)

func _process(delta: float) -> void:
	if name == "MarkPool":
		_watch_casts()
		return
	if not mark_on:
		Tick._tick(self, delta)
		return
	var t0: int = Time.get_ticks_usec()
	Tick._tick(self, delta)
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

func _release_all() -> void:
	Pool._release_all(self)

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
	Tick._push_albedo(self)
	Tick._push_feet(self)
	spr.material_override = mat
	if not spr.texture_changed.is_connected(_on_tex):
		spr.texture_changed.connect(_on_tex)

func _on_tex() -> void:
	Tick._push_albedo(self)
	Place.warm(self)
	if _in_light or _hub_sun:
		_dirty = true
		set_process(true)

func _biased(away: Vector2) -> Vector2:
	return Place._biased(self, away)

func _watch_casts() -> void:
	if LightRt._casts_ver == _cast_seen:
		return
	_cast_seen = LightRt._casts_ver
	_rebuild_areas()

func _rebuild_areas() -> void:
	var pool: Node3D = _pool_host
	if pool == null:
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
			pool.add_child(area)
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
