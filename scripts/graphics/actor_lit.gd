extends Node

## Feet tint from the light RT. Floor mark is the current frame, near-black, hinged at the feet.

const T := preload("res://scripts/data/tunables.gd")
const LightRt := preload("res://scripts/graphics/light_rt.gd")

const SHADE := """
shader_type spatial;
render_mode unshaded, cull_disabled, blend_mix, depth_draw_opaque;
uniform sampler2D albedo_tex : source_color, filter_nearest;
uniform vec4 shade = vec4(0.02, 0.02, 0.02, 0.32);

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

var spr: Sprite3D
var mark: MeshInstance3D
var _game: Color = Color.WHITE
var _sent: Color = Color(-1.0, -1.0, -1.0, -1.0)
var _key: String = ""


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
	var hit: Dictionary = LightRt.nearest_cast(feet)
	if not bool(hit.get("ok", false)) or not LightRt.floor_open(feet):
		mark.visible = false
		return
	_sync_frame()
	mark.global_position = Vector3(feet.x, T.FLOOR_Y + T.FEET_LIFT, feet.y)
	mark.global_rotation = Vector3.ZERO
	mark.visible = true


func _mix(sample: Color) -> Color:
	return Color(_game.r * sample.r, _game.g * sample.g, _game.b * sample.b, _game.a)


func _sync_frame() -> void:
	var rect: Rect2 = _frame_rect()
	var key: String = "%s|%s|%s|%s|%s" % [
		spr.texture.get_rid().get_id(), rect, spr.flip_h, spr.flip_v, spr.pixel_size,
	]
	if key == _key and mark.mesh != null:
		return
	_key = key
	var mat: ShaderMaterial = mark.material_override as ShaderMaterial
	if mat != null:
		mat.set_shader_parameter("albedo_tex", spr.texture)
	mark.mesh = _flat_mesh(rect)


func _frame_rect() -> Rect2:
	var tex_w: float = float(maxi(1, spr.texture.get_width()))
	var tex_h: float = float(maxi(1, spr.texture.get_height()))
	if spr.region_enabled:
		return spr.region_rect
	var hf: int = maxi(1, spr.hframes)
	var vf: int = maxi(1, spr.vframes)
	var fw: float = tex_w / float(hf)
	var fh: float = tex_h / float(vf)
	var frame: int = clampi(spr.frame, 0, hf * vf - 1)
	var col: int = frame % hf
	var row: int = int(float(frame) / float(hf))
	return Rect2(float(col) * fw, float(row) * fh, fw, fh)


func _flat_mesh(rect: Rect2) -> ArrayMesh:
	var tex_w: float = float(maxi(1, spr.texture.get_width()))
	var tex_h: float = float(maxi(1, spr.texture.get_height()))
	var w: float = spr.pixel_size * rect.size.x
	var h: float = spr.pixel_size * rect.size.y
	var u0: float = rect.position.x / tex_w
	var v0: float = rect.position.y / tex_h
	var u1: float = (rect.position.x + rect.size.x) / tex_w
	var v1: float = (rect.position.y + rect.size.y) / tex_h
	if spr.flip_h:
		var swap_u: float = u0
		u0 = u1
		u1 = swap_u
	if spr.flip_v:
		var swap_v: float = v0
		v0 = v1
		v1 = swap_v
	var half_w: float = w * 0.5
	var verts: PackedVector3Array = PackedVector3Array()
	var uvs: PackedVector2Array = PackedVector2Array()
	var indices: PackedInt32Array = PackedInt32Array()
	verts.append(Vector3(-half_w, 0.0, h))
	verts.append(Vector3(half_w, 0.0, h))
	verts.append(Vector3(half_w, 0.0, 0.0))
	verts.append(Vector3(-half_w, 0.0, 0.0))
	uvs.append(Vector2(u0, v0))
	uvs.append(Vector2(u1, v0))
	uvs.append(Vector2(u1, v1))
	uvs.append(Vector2(u0, v1))
	indices.append(0)
	indices.append(2)
	indices.append(1)
	indices.append(0)
	indices.append(3)
	indices.append(2)
	var arrays: Array = []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = verts
	arrays[Mesh.ARRAY_TEX_UV] = uvs
	arrays[Mesh.ARRAY_INDEX] = indices
	var mesh: ArrayMesh = ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return mesh


static func _mat() -> ShaderMaterial:
	if _shade == null:
		var sh: Shader = Shader.new()
		sh.code = SHADE
		_shade = sh
	var mat: ShaderMaterial = ShaderMaterial.new()
	mat.shader = _shade
	return mat
