extends Node

## Feet tint from the light RT. Hub keeps one sun mark plus the crystal mark.
## Player uses the live sticker after flip_h. Dummy and enemies use their still.
## Sole pixels pin to the sticker's feet. The head shears away from the light.
## Dungeon alpha is split across the live marks so they do not smear black.

const T := preload("res://scripts/data/tunables.gd")
const LightRt := preload("res://scripts/graphics/light_rt.gd")

const K := preload("res://scripts/graphics/actor_lit/lit_k.gd")
const Soles := preload("res://scripts/graphics/actor_lit/soles.gd")
const Geo := preload("res://scripts/graphics/actor_lit/lit_geo.gd")
const Drive := preload("res://scripts/graphics/actor_lit/drive.gd")

static var _shade: Shader

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
var _ink_budget: float = 0.0
var _flip: bool = false

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
		mat.render_priority = 8 - slot
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

func _process(delta: float) -> void:
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
	_tint(host)
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
	if App.in_dungeon:
		Drive._drive_many(self, feet, delta)
	else:
		Drive._drive_hub(self, host, feet)
	_place(tex, feet)

func _mix(sample: Color) -> Color:
	return Color(_game.r * sample.r, _game.g * sample.g, _game.b * sample.b, _game.a)

func _usable(tex: Texture2D) -> bool:
	return tex != null and tex.get_width() > 8 and tex.get_height() > 8

func _place(tex: Texture2D, feet: Vector2) -> void:
	var soles: Vector4 = Soles._soles(tex)
	var tw: float = float(maxi(1, tex.get_width()))
	var th: float = float(maxi(1, tex.get_height()))
	var px: float = spr.pixel_size
	var fl: Vector2 = Geo._sole_xz(self, soles.x, soles.y, tw, th) - feet
	var fr: Vector2 = Geo._sole_xz(self, soles.z, soles.w, tw, th) - feet
	var origin: Vector3 = Vector3(feet.x, T.FLOOR_Y, feet.y)
	var ink: float = 0.0
	if App.in_dungeon:
		for slot in K.MARK_N:
			if _alpha_at[slot] >= K.HIDE_A:
				ink += _alpha_at[slot]
	var scale: float = 1.0
	if App.in_dungeon and _ink_budget > 0.001 and ink > _ink_budget:
		scale = _ink_budget / ink
	for slot in K.MARK_N:
		var node: MeshInstance3D = marks[slot]
		var live: bool = _alpha_at[slot] >= K.HIDE_A
		if not App.in_dungeon and slot > 1:
			live = false
		if not live:
			node.visible = false
			continue
		var dir: Vector2 = _biased(_away_at[slot])
		_sync_slot(slot, tex, soles, fl, fr, dir, px, feet)
		node.global_transform = Transform3D(Basis.IDENTITY, origin)
		var shade_mat: ShaderMaterial = node.material_override as ShaderMaterial
		if shade_mat != null:
			shade_mat.render_priority = 8 - _rank_at[slot]
			var shown: float = _alpha_at[slot] * scale
			shade_mat.set_shader_parameter("shade", Color(0.02, 0.02, 0.02, shown))
		node.visible = true

func _sync_slot(slot: int, tex: Texture2D, soles: Vector4, fl: Vector2, fr: Vector2, dir: Vector2, px: float, feet: Vector2) -> void:
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
		mat.set_shader_parameter("albedo_tex", tex)
	if key == _key_at[slot] and node.mesh != null:
		return
	_key_at[slot] = key
	node.mesh = Geo._quad(self, tex, Soles._span(tex), soles, fl, fr, dir, px, _stretch_at[slot], src)
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
	return mat
