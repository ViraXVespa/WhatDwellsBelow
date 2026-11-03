extends Node

## Feet tint from the light RT. Hub keeps one sun mark plus the crystal mark.
## Player uses the live sticker after flip_h. Dummy and enemies use their still.
## Sole pixels pin to the sticker's feet. The head shears away from the light.
## Dungeon alpha is split across the live marks so they do not smear black.

const T := preload("res://scripts/data/tunables.gd")
const LightRt := preload("res://scripts/graphics/light_rt.gd")
const HubCast := preload("res://scripts/graphics/light_rt/hub_cast.gd")

const Hulls := preload("res://scripts/graphics/light_rt/hub_hulls.gd")
const K := preload("res://scripts/graphics/actor_lit/lit_k.gd")
const Soles := preload("res://scripts/graphics/actor_lit/soles.gd")
const Geo := preload("res://scripts/graphics/actor_lit/lit_geo.gd")
const Emis := preload("res://scripts/graphics/actor_lit/lit_emis.gd")
const Contact := preload("res://scripts/graphics/actor_lit/lit_contact.gd")
const Drive := preload("res://scripts/graphics/actor_lit/drive.gd")

static var _shade: Shader
## Debug plant (hub_shadow_check/feet_px.gd): the higher standing foot treated as raised (the one-foot-off of 20611abf).
static var plant_flat := false
## Sweep only. Off leaves live frames untimed. mark_us is the sum of this frame's _process.
## The part counters split that sum. foot_us, quad_us, albedo_us, and contact_us sit inside sync_us.
## sole_us and pin_us sit inside geo_us. sample_xz sits inside tint_us.
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

var spr: Sprite3D
var marks: Array[MeshInstance3D] = []
var _game: Color = Color.WHITE
var _sent: Color = Color(-1.0, -1.0, -1.0, -1.0)
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
	for slot in K.MARK_N:
		var mesh_node: MeshInstance3D = MeshInstance3D.new()
		mesh_node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		var mat: ShaderMaterial = _mat()
		mat.render_priority = -2
		mesh_node.sorting_offset = -30.0
		mesh_node.material_override = mat
		mesh_node.visible = false
		mesh_node.top_level = true
		marks.append(mesh_node)
		add_child(mesh_node)
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

func _process(delta: float) -> void:
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
		queue_free()
		return
	var body: Node = get_parent()
	if body != null and body.get("dead") == true:
		_hide_all()
		return
	var host: Node3D = body as Node3D
	if host == null:
		return
	var t0: int = _mark_t()
	_tint(host)
	_mark_us(0, t0)
	_lay(host, delta)

func _hide_all() -> void:
	for slot in marks.size():
		marks[slot].visible = false

func _tint(host: Node3D) -> void:
	var cur: Color = spr.modulate
	if cur != _sent:
		_game = cur
	var feet: Vector2 = Vector2(host.global_position.x, host.global_position.z)
	var sample: Color = LightRt.sample_xz(feet)
	_sent = _mix(sample)
	spr.modulate = _sent

func _lay(host: Node3D, delta: float) -> void:
	if spr.texture == null or not spr.visible:
		_hide_all()
		return
	var feet: Vector2 = Vector2(host.global_position.x, host.global_position.z)
	if App.in_dungeon and not LightRt.floor_open(feet):
		_hide_all()
		return
	var tex: Texture2D = spr.texture
	if not _usable(tex):
		_hide_all()
		return
	_flip = spr.flip_h
	var t0: int = _mark_t()
	if App.in_dungeon:
		Drive._drive_many(self, feet, delta)
	else:
		Drive._drive_hub(self, host, feet)
	_mark_us(1, t0)
	_place(tex, feet)

func _mix(sample: Color) -> Color:
	return Color(_game.r * sample.r, _game.g * sample.g, _game.b * sample.b, _game.a)

func _usable(tex: Texture2D) -> bool:
	return tex != null and tex.get_width() > 8 and tex.get_height() > 8

func _place(tex: Texture2D, feet: Vector2) -> void:
	var t0: int = _mark_t()
	var t_sole: int = _mark_t()
	var soles: Vector4 = Soles._soles(tex)
	_mark_us(9, t_sole)
	var tw: float = float(maxi(1, tex.get_width()))
	var th: float = float(maxi(1, tex.get_height()))
	var px: float = spr.pixel_size
	# Both pins on the grounded (lowest) sole row: a raised foot keeps its x but not its lift, so it shows a gap
	# above the mark in proportion to the lift (hub_shadow_check/mark_matrix.gd).
	var sole_y: float = maxf(soles.y, soles.w)
	var up: float = K.RAISED_M / maxf(spr.pixel_size, 1e-5)
	var gl: bool = sole_y - soles.y < up and not (plant_flat and soles.y < sole_y)
	var gr: bool = sole_y - soles.w < up and not (plant_flat and soles.w < sole_y)
	# A grounded foot pins at its own sole (contact) row; the shader (lit_k feet) casts its rows from there.
	var t_pin: int = _mark_t()
	var fl: Vector2 = Geo._sole_xz(self, soles.x, soles.y if gl else sole_y, tw, th, gl) - feet
	var fr: Vector2 = Geo._sole_xz(self, soles.z, soles.w if gr else sole_y, tw, th, gr) - feet
	lift = 0.0
	var kind: Variant = get_parent().get("move_kind")
	if air_force or kind == "fly" or kind == "hop":
		# Straight-down pins (no camera drop, no tuck): the mark stays under the body, detached by the altitude.
		var wl: Vector3 = Geo._sole_world(self, soles.x, sole_y, tw, th)
		var wr: Vector3 = Geo._sole_world(self, soles.z, sole_y, tw, th)
		if minf(wl.y, wr.y) - T.FLOOR_Y > K.AIR_MIN:
			lift = minf(wl.y, wr.y) - T.FLOOR_Y
			fl = Vector2(wl.x, wl.z) - feet
			fr = Vector2(wr.x, wr.z) - feet
	_mark_us(10, t_pin)
	var s_air: float = clampf(1.0 - lift / K.AIR_S_M, K.AIR_S_MIN, 1.0)
	var a_air: float = clampf(1.0 - lift / K.AIR_A_M, K.AIR_A_MIN, 1.0)
	var origin: Vector3 = Vector3(feet.x, T.FLOOR_Y, feet.y)
	var ink: float = 0.0
	if App.in_dungeon:
		for slot in K.MARK_N:
			if _alpha_at[slot] >= K.HIDE_A:
				ink += _alpha_at[slot]
	var scale: float = 1.0
	if App.in_dungeon and _ink_budget > 0.001 and ink > _ink_budget:
		scale = _ink_budget / ink
	var glow: bool = Emis.rule_of(get_parent()) == "glow"
	_mark_us(2, t0)
	for slot in K.MARK_N:
		var node: MeshInstance3D = marks[slot]
		var live: bool = _alpha_at[slot] >= K.HIDE_A and not glow
		if not live:
			node.visible = false
			continue
		var dir: Vector2 = _biased(_away_at[slot])
		_sync_slot(slot, tex, soles, fl, fr, dir, px, feet)
		var ts: int = _mark_t()
		var at: Vector3 = origin
		if lift > 0.0:
			var run: Vector2 = dir * Geo._reach(lift, _stretch_at[slot], _src_at[slot])
			at += Vector3(run.x, 0.0, run.y)
		node.global_transform = Transform3D(Basis.IDENTITY.scaled(Vector3(s_air, 1.0, s_air)), at)
		var shade_mat: ShaderMaterial = node.material_override as ShaderMaterial
		if shade_mat != null:
			var shown: float = _alpha_at[slot] * scale * a_air
			var shade: Color = Color(0.02, 0.02, 0.02, shown)
			if not _shade_set[slot] or shade != _shade_at[slot]:
				shade_mat.set_shader_parameter("shade", shade)
				_shade_at[slot] = shade
				_shade_set[slot] = true
			var sun_c: float = 1.0 if slot == 0 and not App.in_dungeon else 0.0
			if sun_c != _sun_at[slot]:
				shade_mat.set_shader_parameter("sun_cancel", sun_c)
				_sun_at[slot] = sun_c
			if slot == 0 and _hull_n != Hulls._n:
				Hulls.bind(shade_mat)
				_hull_n = Hulls._n
			var grid_v: float = K.HUB_GRID if K.on_grid() else 0.0
			if grid_v != _grid_at[slot]:
				shade_mat.set_shader_parameter("grid", grid_v)
				_grid_at[slot] = grid_v
		node.visible = true
		_mark_us(6, ts)

func _sync_slot(slot: int, tex: Texture2D, soles: Vector4, fl: Vector2, fr: Vector2, dir: Vector2, px: float, feet: Vector2) -> void:
	var t0: int = _mark_t()
	var node: MeshInstance3D = marks[slot]
	var src: Vector2 = Vector2.ZERO
	if _src_at[slot].length_squared() > 0.0004:
		src = _src_at[slot] - feet
	var reach: Vector2 = dir * _stretch_at[slot]
	var key: Array = [
		tex.get_instance_id(), px, _flip,
		snappedf(fl.x, 0.01), snappedf(fl.y, 0.01),
		snappedf(fr.x, 0.01), snappedf(fr.y, 0.01),
		snappedf(reach.x, 0.01), snappedf(reach.y, 0.01),
		snappedf(src.x, 0.05), snappedf(src.y, 0.05),
	]
	var mat: ShaderMaterial = node.material_override as ShaderMaterial
	if mat != null:
		var t_albedo: int = _mark_t()
		var albedo: Texture2D = Soles._solid(tex, solid) if solid != "" else Emis.mask(tex, Emis.rule_of(get_parent()))
		_mark_us(7, t_albedo)
		var aid: int = albedo.get_instance_id() if albedo != null else 0
		if aid != _albedo_id[slot]:
			mat.set_shader_parameter("albedo_tex", albedo)
			_albedo_id[slot] = aid
		if solid == "profile":
			var tf: int = _mark_t()
			foot = Soles._foot(tex)
			_mark_us(4, tf)
		else:
			foot = 0
		var t_contact: int = _mark_t()
		var per_col: bool = solid == "" and K.on_grid()
		var contact_flag: float = 1.0 if per_col else 0.0
		if contact_flag != _contact_on[slot]:
			mat.set_shader_parameter("contact_on", contact_flag)
			_contact_on[slot] = contact_flag
		if per_col:
			var ctex: Texture2D = Contact.tex(tex, Soles._soles(tex), px, plant_flat)
			var cid: int = ctex.get_instance_id() if ctex != null else 0
			if cid != _contact_id[slot]:
				mat.set_shader_parameter("contact_tex", ctex)
				_contact_id[slot] = cid
		_mark_us(8, t_contact)
	if key == _key_at[slot] and node.mesh != null:
		_mark_us(3, t0)
		return
	_key_at[slot] = key
	var tq: int = _mark_t()
	node.mesh = Geo._quad(self, tex, Soles._span(tex), soles, fl, fr, dir, px, _stretch_at[slot], src)
	_mark_us(5, tq)
	_mark_us(3, t0)

func _biased(away: Vector2) -> Vector2:
	# Keep a little Z so a side-on light does not flatten the quad.
	# Sign follows the light so a source toward the camera can cast up-screen.
	var dir: Vector2 = away
	if dir.length_squared() < 0.0004:
		dir = K.SUN_AWAY
	else:
		dir = dir.normalized()
	if absf(dir.y) < K.MIN_DOWN:
		dir.y = K.MIN_DOWN if dir.y >= 0.0 else -K.MIN_DOWN
	return dir.normalized()

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
