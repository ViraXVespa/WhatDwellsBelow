extends Node

## Feet tint from the light RT. One floor mark per caster.
## Player uses the live sticker after flip_h. Dummy and enemies use their still.
## Sole pixels pin to the sticker. The head shears with a screen-down bias.
## Hub is the sun, one length. Dungeon uses the nearest torch, crystal, or campfire.

const T := preload("res://scripts/data/tunables.gd")
const LightRt := preload("res://scripts/graphics/light_rt.gd")

const SUN_AWAY := Vector2(0.406138, 0.913811)
const HUB_STRETCH := 0.72
const HUB_ALPHA := 0.55
const D_NEAR := 0.64
const D_FAR := 0.80
const A_NEAR := 0.50
const A_FAR := 0.38
const MIN_DOWN := 0.28
const TURN_RATE := 6.0
const EASE_RATE := 5.0

const SHADE := """
shader_type spatial;
render_mode unshaded, cull_disabled, blend_mix, depth_draw_opaque;
uniform sampler2D albedo_tex : source_color, filter_nearest;
uniform vec4 shade = vec4(0.02, 0.02, 0.02, 0.55);

void vertex() {
	vec4 clip = PROJECTION_MATRIX * MODELVIEW_MATRIX * vec4(VERTEX, 1.0);
	clip.z += 0.003 * clip.w;
	POSITION = clip;
}

void fragment() {
	vec4 tex = texture(albedo_tex, UV);
	if (tex.a < 0.2) {
		discard;
	}
	ALBEDO = shade.rgb;
	ALPHA = shade.a;
}
"""

static var _shade: Shader
static var _spans: Dictionary = {}
static var _sole_at: Dictionary = {}

var spr: Sprite3D
var mark: MeshInstance3D
var _game: Color = Color.WHITE
var _sent: Color = Color(-1.0, -1.0, -1.0, -1.0)
var _key: String = ""
var _away: Vector2 = SUN_AWAY
var _stretch: float = HUB_STRETCH
var _alpha: float = HUB_ALPHA
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
	var mesh_node: MeshInstance3D = MeshInstance3D.new()
	mesh_node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mesh_node.material_override = _mat()
	mesh_node.visible = false
	mark = mesh_node
	mark.top_level = true
	add_child(mark)


func _process(delta: float) -> void:
	if spr == null or not is_instance_valid(spr):
		queue_free()
		return
	var body: Node = get_parent()
	if body != null and body.get("dead") == true:
		mark.visible = false
		return
	var host: Node3D = body as Node3D
	if host == null:
		return
	_tint(host)
	_lay(host, delta)


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
		mark.visible = false
		return
	var feet: Vector2 = Vector2(host.global_position.x, host.global_position.z)
	if App.in_dungeon and not LightRt.floor_open(feet):
		mark.visible = false
		return
	var tex: Texture2D = spr.texture
	if not _usable(tex):
		mark.visible = false
		return
	_flip = spr.flip_h
	_drive(feet, delta)
	var dir: Vector2 = _biased()
	_sync(tex, dir, feet)
	mark.global_transform = Transform3D(Basis.IDENTITY, Vector3(feet.x, T.FLOOR_Y, feet.y))
	var shade_mat: ShaderMaterial = mark.material_override as ShaderMaterial
	if shade_mat != null:
		shade_mat.set_shader_parameter("shade", Color(0.02, 0.02, 0.02, _alpha))
	mark.visible = true


func _drive(feet: Vector2, delta: float) -> void:
	if not App.in_dungeon:
		_away = SUN_AWAY
		_stretch = HUB_STRETCH
		_alpha = HUB_ALPHA
		return
	var hit: Dictionary = LightRt.nearest_cast(feet)
	var aim: Vector2 = _away
	var goal_s: float = _stretch
	var goal_a: float = _alpha
	if hit.get("ok", false) == true:
		var src: Vector2 = hit["xz"]
		var step: Vector2 = feet - src
		if step.length_squared() > 0.0004:
			aim = step.normalized()
		var reach: float = maxf(float(hit["reach"]), 0.001)
		var along: float = clampf(float(hit["dist"]) / reach, 0.0, 1.0)
		goal_s = lerpf(D_NEAR, D_FAR, along)
		goal_a = lerpf(A_NEAR, A_FAR, along)
	_turn(aim, delta)
	var k: float = clampf(delta * EASE_RATE, 0.0, 1.0)
	_stretch = lerpf(_stretch, goal_s, k)
	_alpha = lerpf(_alpha, goal_a, k)


func _turn(aim: Vector2, delta: float) -> void:
	var dest: Vector2 = SUN_AWAY
	if aim.length_squared() > 0.0004:
		dest = aim.normalized()
	if _away.length_squared() < 0.0004:
		_away = dest
		return
	var src: Vector2 = _away.normalized()
	var ang: float = src.angle_to(dest)
	var step: float = TURN_RATE * delta
	if absf(ang) <= step:
		_away = dest
		return
	_away = src.rotated(step if ang > 0.0 else -step)


func _biased() -> Vector2:
	# +Z is screen-down. Hold a little so the head cannot flip up-screen or flatten.
	var dir: Vector2 = _away
	if dir.length_squared() < 0.0004:
		dir = SUN_AWAY
	else:
		dir = dir.normalized()
	if dir.y < MIN_DOWN:
		dir.y = MIN_DOWN
	return dir.normalized()


func _mix(sample: Color) -> Color:
	return Color(_game.r * sample.r, _game.g * sample.g, _game.b * sample.b, _game.a)


func _usable(tex: Texture2D) -> bool:
	return tex != null and tex.get_width() > 8 and tex.get_height() > 8


func _sync(tex: Texture2D, dir: Vector2, host_xz: Vector2) -> void:
	var soles: Vector4 = _soles(tex)
	var tw: float = float(maxi(1, tex.get_width()))
	var th: float = float(maxi(1, tex.get_height()))
	var px: float = spr.pixel_size
	var fl: Vector2 = _sole_xz(soles.x, soles.y, tw, th) - host_xz
	var fr: Vector2 = _sole_xz(soles.z, soles.w, tw, th) - host_xz
	var reach: Vector2 = dir * _stretch
	var key: String = "%s|%s|%s|%s|%s|%s|%s|%s|%s|%s" % [
		tex.get_rid().get_id(), px, _flip,
		snappedf(fl.x, 0.01), snappedf(fl.y, 0.01),
		snappedf(fr.x, 0.01), snappedf(fr.y, 0.01),
		snappedf(reach.x, 0.01), snappedf(reach.y, 0.01),
	]
	if key == _key and mark.mesh != null:
		return
	_key = key
	var mat: ShaderMaterial = mark.material_override as ShaderMaterial
	if mat != null:
		mat.set_shader_parameter("albedo_tex", tex)
	mark.mesh = _quad(tex, _span(tex), soles, fl, fr, dir, px)


func _sole_xz(tx: float, ty: float, tw: float, th: float) -> Vector2:
	var ox: float = spr.offset.x
	var oy: float = spr.offset.y
	if spr.centered:
		ox -= tw * 0.5
		oy -= th * 0.5
	var g: float = tx / tw
	if _flip:
		g = 1.0 - g
	var lx: float = (ox + g * tw) * spr.pixel_size
	var ly: float = (oy + (th - ty)) * spr.pixel_size
	var axis: Vector3 = _bill_x()
	var world: Vector3 = spr.global_position + axis * lx + Vector3(0.0, ly, 0.0)
	return _drop_floor(world)


func _bill_x() -> Vector3:
	var cam: Camera3D = get_viewport().get_camera_3d()
	if cam == null:
		return Vector3.RIGHT
	var side: Vector3 = Vector3.UP.cross(cam.global_transform.basis.z)
	if side.length_squared() < 0.0004:
		return Vector3.RIGHT
	return side.normalized()


func _drop_floor(world: Vector3) -> Vector2:
	var cam: Camera3D = get_viewport().get_camera_3d()
	if cam == null:
		return Vector2(world.x, world.z)
	var view: Vector3 = -cam.global_transform.basis.z
	if absf(view.y) < 0.05:
		return Vector2(world.x, world.z)
	var t: float = (T.FLOOR_Y - world.y) / view.y
	if absf(t) > 3.0:
		return Vector2(world.x, world.z)
	var hit: Vector3 = world + view * t
	return Vector2(hit.x, hit.z)


func _quad(tex: Texture2D, span: Vector4, soles: Vector4, fl: Vector2, fr: Vector2, dir: Vector2, px: float) -> ArrayMesh:
	var tw: float = float(maxi(1, tex.get_width()))
	var th: float = float(maxi(1, tex.get_height()))
	var x0: float = span.x * tw
	var x1: float = span.z * tw
	var y0: float = span.y * th
	var y1: float = span.w * th
	var verts: PackedVector3Array = PackedVector3Array()
	var uvs: PackedVector2Array = PackedVector2Array()
	var indices: PackedInt32Array = PackedInt32Array()
	verts.append(_corner(x0, y1, soles, fl, fr, dir, px))
	verts.append(_corner(x1, y1, soles, fl, fr, dir, px))
	verts.append(_corner(x1, y0, soles, fl, fr, dir, px))
	verts.append(_corner(x0, y0, soles, fl, fr, dir, px))
	uvs.append(Vector2(span.x, span.w))
	uvs.append(Vector2(span.z, span.w))
	uvs.append(Vector2(span.z, span.y))
	uvs.append(Vector2(span.x, span.y))
	indices.append_array(PackedInt32Array([0, 1, 2, 0, 2, 3]))
	var arrays: Array = []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = verts
	arrays[Mesh.ARRAY_TEX_UV] = uvs
	arrays[Mesh.ARRAY_INDEX] = indices
	var mesh: ArrayMesh = ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return mesh


func _corner(tx: float, ty: float, soles: Vector4, fl: Vector2, fr: Vector2, dir: Vector2, px: float) -> Vector3:
	var span_x: float = soles.z - soles.x
	if absf(span_x) < 0.5:
		span_x = 0.5 if soles.z >= soles.x else -0.5
	var a: float = (tx - soles.x) / span_x
	var foot_y: float = soles.y + a * (soles.w - soles.y)
	var pos: Vector2 = fl.lerp(fr, a) + dir * ((foot_y - ty) * px * _stretch)
	return Vector3(pos.x, 0.0, pos.y)


static func _soles(tex: Texture2D) -> Vector4:
	var id: int = tex.get_rid().get_id()
	if _sole_at.has(id):
		return _sole_at[id] as Vector4
	var tw: int = maxi(1, tex.get_width())
	var th: int = maxi(1, tex.get_height())
	var fb: Vector4 = Vector4(0.0, float(th), float(tw), float(th))
	var img: Image = tex.get_image()
	if img == null or img.is_empty():
		return _keep(id, fb)
	if img.get_format() != Image.FORMAT_RGBA8:
		var copy: Image = img.duplicate()
		copy.convert(Image.FORMAT_RGBA8)
		img = copy
	var w: int = img.get_width()
	var h: int = img.get_height()
	var bytes: PackedByteArray = img.get_data()
	if w < 1 or h < 1 or bytes.size() < w * h * 4:
		return _keep(id, fb)
	var min_x: int = w
	var min_y: int = h
	var max_x: int = -1
	var max_y: int = -1
	for y in h:
		var row: int = y * w * 4
		for x in w:
			if bytes[row + x * 4 + 3] < 51:
				continue
			if x < min_x:
				min_x = x
			if y < min_y:
				min_y = y
			if x > max_x:
				max_x = x
			if y > max_y:
				max_y = y
	if max_x < 0:
		return _keep(id, fb)
	_spans[id] = Vector4(
		float(min_x) / float(w), float(min_y) / float(h),
		float(max_x + 1) / float(w), float(max_y + 1) / float(h)
	)
	var mid: int = int(float(min_x + max_x) * 0.5)
	var ly: int = -1
	var ry: int = -1
	var ls: float = 0.0
	var ln: int = 0
	var rs: float = 0.0
	var rn: int = 0
	for y2 in range(min_y, max_y + 1):
		var row2: int = y2 * w * 4
		var lsum: float = 0.0
		var lnum: int = 0
		var rsum: float = 0.0
		var rnum: int = 0
		for x2 in range(min_x, max_x + 1):
			if bytes[row2 + x2 * 4 + 3] < 51:
				continue
			if x2 <= mid:
				lsum += float(x2) + 0.5
				lnum += 1
			else:
				rsum += float(x2) + 0.5
				rnum += 1
		if lnum > 0:
			ly = y2
			ls = lsum
			ln = lnum
		if rnum > 0:
			ry = y2
			rs = rsum
			rn = rnum
	if ly < 0 or ry < 0:
		return _keep(id, _bottom_span(bytes, w, max_y, min_x, max_x))
	var lx: float = ls / float(ln)
	var rx: float = rs / float(rn)
	if absf(rx - lx) < 0.5:
		lx = float(min_x) + 0.5
		rx = float(max_x) + 0.5
	return _keep(id, Vector4(lx, float(ly + 1), rx, float(ry + 1)))


static func _keep(id: int, sole: Vector4) -> Vector4:
	_sole_at[id] = sole
	return sole


static func _bottom_span(bytes: PackedByteArray, w: int, y: int, x0: int, x1: int) -> Vector4:
	var row: int = y * w * 4
	var left: int = x1
	var right: int = x0
	for x in range(x0, x1 + 1):
		if bytes[row + x * 4 + 3] < 51:
			continue
		if x < left:
			left = x
		if x > right:
			right = x
	if right <= left:
		right = mini(w - 1, left + 1)
	return Vector4(float(left) + 0.5, float(y + 1), float(right) + 0.5, float(y + 1))


static func _span(tex: Texture2D) -> Vector4:
	var id: int = tex.get_rid().get_id()
	if not _spans.has(id):
		_soles(tex)
	if _spans.has(id):
		return _spans[id] as Vector4
	return Vector4(0.0, 0.0, 1.0, 1.0)


static func _mat() -> ShaderMaterial:
	if _shade == null:
		var sh: Shader = Shader.new()
		sh.code = SHADE
		_shade = sh
	var mat: ShaderMaterial = ShaderMaterial.new()
	mat.shader = _shade
	mat.render_priority = 8
	return mat
