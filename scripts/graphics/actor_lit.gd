extends Node

## Feet tint from the light RT. Idle silhouette on FLOOR_Y.
## Both feet stay on the sticker. The head edge shears away from the light.
## Hub driver is the sun. Dungeon length follows the nearest torch, crystal, or campfire.

const T := preload("res://scripts/data/tunables.gd")
const LightRt := preload("res://scripts/graphics/light_rt.gd")

const SUN_AWAY := Vector2(0.406138, 0.913811)
const HUB_STRETCH := 0.72
const HUB_ALPHA := 0.55

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
static var _feet_ok: Dictionary = {}

var spr: Sprite3D
var mark: MeshInstance3D
var _game: Color = Color.WHITE
var _sent: Color = Color(-1.0, -1.0, -1.0, -1.0)
var _key: String = ""
var _away: Vector2 = SUN_AWAY
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


func _process(_delta: float) -> void:
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
		mark.visible = false
		return
	var feet: Vector2 = Vector2(host.global_position.x, host.global_position.z)
	var tex: Texture2D = _planted()
	if not _usable(tex):
		mark.visible = false
		return
	var stretch: float = HUB_STRETCH
	var alpha: float = HUB_ALPHA
	_away = SUN_AWAY
	if App.in_dungeon:
		if not LightRt.floor_open(feet):
			mark.visible = false
			return
		var hit: Dictionary = LightRt.nearest_cast(feet)
		if hit.get("ok", false) == true:
			var src: Vector2 = hit["xz"]
			var delta: Vector2 = feet - src
			if delta.length_squared() > 0.0004:
				_away = delta.normalized()
			var reach: float = maxf(float(hit["reach"]), 0.001)
			var along: float = clampf(float(hit["dist"]) / reach, 0.0, 1.0)
			stretch = lerpf(0.32, 1.2, along)
			alpha = lerpf(0.55, 0.22, along)
	var shown: float = spr.pixel_size * float(maxi(1, spr.texture.get_height()))
	var px: float = shown / float(maxi(1, tex.get_height()))
	var warp: Vector2 = _shear(_away) * (px * float(tex.get_height())) * stretch
	_sync(tex, px, warp)
	mark.global_transform = Transform3D(Basis.IDENTITY, Vector3(feet.x, T.FLOOR_Y, feet.y))
	var shade_mat: ShaderMaterial = mark.material_override as ShaderMaterial
	if shade_mat != null:
		shade_mat.set_shader_parameter("shade", Color(0.02, 0.02, 0.02, alpha))
	mark.visible = true


func _shear(away: Vector2) -> Vector2:
	# Feet lie on camera X. A light beside the actor would slide the head
	# along that same line and the quad would have no area.
	var dir: Vector2 = SUN_AWAY
	if away.length_squared() > 0.0004:
		dir = away.normalized()
	if absf(dir.y) < 0.35:
		var side: float = 1.0 if dir.x >= 0.0 else -1.0
		dir = Vector2(side * 0.45, 0.89).normalized()
	return dir


func _mix(sample: Color) -> Color:
	return Color(_game.r * sample.r, _game.g * sample.g, _game.b * sample.b, _game.a)


func _planted() -> Texture2D:
	_flip = false
	var host: Node = get_parent()
	if host != null and host.get("idle") is Dictionary:
		var sheet: Texture2D = _idle_sheet(host)
		if _usable(sheet):
			return sheet
	if _usable(spr.texture):
		_flip = spr.flip_h
		return spr.texture
	return null


func _idle_sheet(host: Node) -> Texture2D:
	var key: String = "down"
	var raw: Variant = host.get("facing_key")
	if raw is String and raw != "":
		key = raw
	var book: Variant = host.get("idle")
	if book is Dictionary:
		var face: Texture2D = _book_tex(book, key)
		if _usable(face) and _feet_in_frame(face):
			return face
		var down: Texture2D = _book_tex(book, "down")
		if _usable(down) and _feet_in_frame(down):
			return down
	var kind: String = str(App.character_type)
	if kind != "male" and kind != "female":
		kind = "male"
	var path: String = "res://assets/sprites/player/%s/idle_%s.png" % [kind, key]
	if not ResourceLoader.exists(path):
		path = "res://assets/sprites/player/%s/idle_down.png" % kind
	if not ResourceLoader.exists(path):
		return null
	var loaded: Texture2D = load(path) as Texture2D
	if _usable(loaded) and _feet_in_frame(loaded):
		return loaded
	return null


func _book_tex(book: Dictionary, key: String) -> Texture2D:
	if key == "" or not book.has(key):
		return null
	return book[key] as Texture2D


func _usable(tex: Texture2D) -> bool:
	return tex != null and tex.get_width() > 8 and tex.get_height() > 8


func _feet_in_frame(tex: Texture2D) -> bool:
	var id: int = tex.get_rid().get_id()
	if _feet_ok.has(id):
		return _feet_ok[id] == true
	var ok: bool = _both_feet(tex)
	_feet_ok[id] = ok
	return ok


func _both_feet(tex: Texture2D) -> bool:
	var img: Image = tex.get_image()
	if img == null or img.is_empty():
		return false
	if img.get_format() != Image.FORMAT_RGBA8:
		var copy: Image = img.duplicate()
		copy.convert(Image.FORMAT_RGBA8)
		img = copy
	var tw: int = img.get_width()
	var th: int = img.get_height()
	var bytes: PackedByteArray = img.get_data()
	if tw < 8 or th < 8 or bytes.size() < tw * th * 4:
		return false
	var min_x: int = tw
	var max_x: int = -1
	var max_y: int = -1
	for y in th:
		for x in tw:
			if bytes[(y * tw + x) * 4 + 3] < 51:
				continue
			if x < min_x:
				min_x = x
			if x > max_x:
				max_x = x
			if y > max_y:
				max_y = y
	if max_x < min_x or max_y < 1:
		return false
	var foot_y: int = maxi(0, max_y - maxi(2, int(float(th) * 0.14)))
	var mid: int = int(float(min_x + max_x) * 0.5)
	var left_foot: bool = false
	var right_foot: bool = false
	for y2 in range(foot_y, max_y + 1):
		for x2 in range(min_x, max_x + 1):
			if bytes[(y2 * tw + x2) * 4 + 3] < 51:
				continue
			if x2 <= mid:
				left_foot = true
			else:
				right_foot = true
	return left_foot and right_foot


func _sync(tex: Texture2D, px: float, warp: Vector2) -> void:
	var qwarp: Vector2 = Vector2(snappedf(warp.x, 0.02), snappedf(warp.y, 0.02))
	var key: String = "%s|%s|%s|%s|%s" % [
		tex.get_rid().get_id(), px, _flip, qwarp.x, qwarp.y,
	]
	if key == _key and mark.mesh != null:
		return
	_key = key
	var mat: ShaderMaterial = mark.material_override as ShaderMaterial
	if mat != null:
		mat.set_shader_parameter("albedo_tex", tex)
	mark.mesh = _quad(tex, _span(tex), px, qwarp)


func _quad(tex: Texture2D, span: Vector4, px: float, warp: Vector2) -> ArrayMesh:
	var world_w: float = px * float(maxi(1, tex.get_width()))
	var x0: float = (span.x - 0.5) * world_w
	var x1: float = (span.z - 0.5) * world_w
	if _flip:
		x0 = -x0
		x1 = -x1
	var shift: Vector3 = Vector3(warp.x, 0.0, warp.y)
	var verts: PackedVector3Array = PackedVector3Array()
	var uvs: PackedVector2Array = PackedVector2Array()
	var indices: PackedInt32Array = PackedInt32Array()
	verts.append(Vector3(x0, 0.0, 0.0))
	verts.append(Vector3(x1, 0.0, 0.0))
	verts.append(Vector3(x1, 0.0, 0.0) + shift)
	verts.append(Vector3(x0, 0.0, 0.0) + shift)
	uvs.append(Vector2(span.x, span.w))
	uvs.append(Vector2(span.z, span.w))
	uvs.append(Vector2(span.z, span.y))
	uvs.append(Vector2(span.x, span.y))
	indices.append(0)
	indices.append(1)
	indices.append(2)
	indices.append(0)
	indices.append(2)
	indices.append(3)
	var arrays: Array = []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = verts
	arrays[Mesh.ARRAY_TEX_UV] = uvs
	arrays[Mesh.ARRAY_INDEX] = indices
	var mesh: ArrayMesh = ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return mesh


static func _span(tex: Texture2D) -> Vector4:
	var id: int = tex.get_rid().get_id()
	if _spans.has(id):
		return _spans[id] as Vector4
	var full: Vector4 = Vector4(0.0, 0.0, 1.0, 1.0)
	var img: Image = tex.get_image()
	if img == null or img.is_empty():
		_spans[id] = full
		return full
	if img.get_format() != Image.FORMAT_RGBA8:
		var copy: Image = img.duplicate()
		copy.convert(Image.FORMAT_RGBA8)
		img = copy
	var tw: int = img.get_width()
	var th: int = img.get_height()
	var bytes: PackedByteArray = img.get_data()
	if tw < 1 or th < 1 or bytes.size() < tw * th * 4:
		_spans[id] = full
		return full
	var min_x: int = tw
	var min_y: int = th
	var max_x: int = -1
	var max_y: int = -1
	for y in th:
		for x in tw:
			var a: int = bytes[(y * tw + x) * 4 + 3]
			if a < 51:
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
		_spans[id] = full
		return full
	var span: Vector4 = Vector4(
		float(min_x) / float(tw),
		float(min_y) / float(th),
		float(max_x + 1) / float(tw),
		float(max_y + 1) / float(th)
	)
	_spans[id] = span
	return span


static func _mat() -> ShaderMaterial:
	if _shade == null:
		var sh: Shader = Shader.new()
		sh.code = SHADE
		_shade = sh
	var mat: ShaderMaterial = ShaderMaterial.new()
	mat.shader = _shade
	mat.render_priority = 8
	return mat
