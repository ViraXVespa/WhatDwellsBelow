extends Node

## Feet tint from the light RT, plus one floor squash of the current frame.

const T := preload("res://scripts/data/tunables.gd")
const LightRt := preload("res://scripts/graphics/light_rt.gd")
const SpriteFilt := preload("res://scripts/world/sprite_filter.gd")

var spr: Sprite3D
var quad: Sprite3D
var _game: Color = Color.WHITE
var _sent: Color = Color(-1.0, -1.0, -1.0, -1.0)


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
	var q: Sprite3D = Sprite3D.new()
	q.centered = true
	q.shaded = false
	q.double_sided = true
	q.billboard = BaseMaterial3D.BILLBOARD_DISABLED
	q.axis = Vector3.AXIS_Y
	q.alpha_cut = SpriteBase3D.ALPHA_CUT_OPAQUE_PREPASS
	q.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	q.render_priority = 0
	q.visible = false
	quad = SpriteFilt.decorate(q)
	add_child(quad)


func _process(_delta: float) -> void:
	if spr == null or not is_instance_valid(spr):
		queue_free()
		return
	var body: Node = get_parent()
	if body != null and bool(body.get("dead")):
		quad.visible = false
		return
	var host: Node3D = body as Node3D
	if host == null:
		return
	_tint(host)
	_lay(host)


func _tint(host: Node3D) -> void:
	var cur: Color = spr.modulate
	if cur != _sent:
		_game = cur
	var feet: Vector2 = Vector2(host.global_position.x, host.global_position.z)
	var sample: Color = LightRt.sample_xz(feet)
	var out: Color = _mix(sample)
	_sent = out
	spr.modulate = out


func _lay(host: Node3D) -> void:
	if spr.texture == null or not spr.visible:
		quad.visible = false
		return
	var feet: Vector2 = Vector2(host.global_position.x, host.global_position.z)
	var hit: Dictionary = LightRt.nearest_cast(feet)
	if not bool(hit["ok"]):
		quad.visible = false
		return
	var src: Vector2 = hit["xz"]
	var dist: float = float(hit["dist"])
	var reach: float = float(hit["reach"])
	var off: Vector2 = _offset(feet, src, dist, reach)
	var place: Vector2 = feet + off
	if not LightRt.floor_open(place):
		if not LightRt.floor_open(feet):
			quad.visible = false
			return
		off = Vector2.ZERO
		place = feet
	_copy_frame()
	quad.global_position = Vector3(place.x, T.FLOOR_Y + T.FEET_LIFT, place.y)
	quad.modulate = _mix(LightRt.sample_xz(place))
	quad.visible = true


func _offset(feet: Vector2, src: Vector2, dist: float, reach: float) -> Vector2:
	# One tile away at the rim of the source, none when standing on it.
	if dist <= 0.001 or reach <= 0.001:
		return Vector2.ZERO
	var away: Vector2 = (feet - src) / dist
	return away * ((dist / reach) * T.TILE)


func _mix(sample: Color) -> Color:
	return Color(_game.r * sample.r, _game.g * sample.g, _game.b * sample.b, _game.a)


func _copy_frame() -> void:
	if _same_frame():
		return
	quad.texture = spr.texture
	quad.hframes = maxi(1, spr.hframes)
	quad.vframes = maxi(1, spr.vframes)
	var max_frame: int = quad.hframes * quad.vframes - 1
	quad.frame = clampi(spr.frame, 0, max_frame)
	quad.region_enabled = spr.region_enabled
	quad.region_rect = spr.region_rect
	quad.flip_h = spr.flip_h
	quad.flip_v = spr.flip_v
	quad.pixel_size = spr.pixel_size
	quad.alpha_cut = spr.alpha_cut
	quad.alpha_scissor_threshold = spr.alpha_scissor_threshold


func _same_frame() -> bool:
	if quad.texture != spr.texture:
		return false
	if quad.frame != spr.frame or quad.hframes != spr.hframes or quad.vframes != spr.vframes:
		return false
	if quad.flip_h != spr.flip_h or quad.flip_v != spr.flip_v:
		return false
	if quad.pixel_size != spr.pixel_size:
		return false
	if quad.region_enabled != spr.region_enabled or quad.region_rect != spr.region_rect:
		return false
	if quad.alpha_cut != spr.alpha_cut:
		return false
	return quad.alpha_scissor_threshold == spr.alpha_scissor_threshold
