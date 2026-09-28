extends Node3D

## Unlit bracket from the 4-facing bible. Flame is a Y-billboard shader, not a sheet.

const BIBLE := "res://assets/sprites/props/torch_bracket_bible.png"
const FLAME := """
shader_type spatial;
render_mode unshaded, cull_disabled, blend_add, depth_draw_opaque;
uniform float flame_seed = 0.0;
varying vec2 uv;

void vertex() {
	uv = UV;
	float flick = 0.82 + 0.22 * sin(TIME * 17.0 + flame_seed);
	float tall = 0.86 + 0.22 * sin(TIME * 11.0 + flame_seed * 2.1);
	VERTEX.x *= flick;
	VERTEX.y *= tall;
}

void fragment() {
	vec2 p = uv * 2.0 - 1.0;
	float wob = sin(p.y * 6.0 + flame_seed + TIME * 13.0) * 0.16;
	p.x += wob * (0.35 + p.y);
	float body = 1.0 - smoothstep(0.06, 0.72, length(vec2(p.x * 1.45, (p.y - 0.08) * 0.7)));
	float flick = 0.55 + 0.45 * abs(sin(TIME * 23.0 + flame_seed * 3.0));
	float a = body * flick;
	if (a < 0.06) {
		discard;
	}
	float hot = clamp(p.y * 0.55 + 0.35, 0.0, 1.0);
	vec3 col = mix(vec3(1.0, 0.92, 0.45), vec3(0.95, 0.28, 0.04), hot);
	ALBEDO = col * (0.65 + 0.55 * flick);
	ALPHA = a;
}
"""

static var _keyed: Texture2D
static var _flame_shader: Shader
static var _quad: QuadMesh

var _spr: Sprite3D
var _flame: MeshInstance3D
var _nx: float = 0.0
var _nz: float = 1.0
var _half: float = 512.0


static func refill(host: Node, sites: Array, chunk: int) -> void:
	if host.geo_root == null:
		return
	for job in host.geo_jobs:
		if str(job.state) != "live":
			continue
		var root: Node = job.node
		if root == null or not is_instance_valid(root):
			continue
		var origin: Vector2i = Vector2i(job.origin)
		_clear(root)
		add_chunk(root, origin.x, origin.y, sites, chunk)


static func add_chunk(root: Node, ox: int, oy: int, sites: Array, chunk: int) -> void:
	var script: GDScript = load("res://scripts/graphics/torch_bill.gd") as GDScript
	for site in sites:
		var fx: int = int(site["fx"])
		var fz: int = int(site["fz"])
		if fx < ox or fz < oy or fx >= ox + chunk or fz >= oy + chunk:
			continue
		var node: Node3D = script.new() as Node3D
		node.set_meta("nx", float(site["nx"]))
		node.set_meta("nz", float(site["nz"]))
		node.set_meta("fx", fx)
		node.position = _bracket_pos(site)
		node.add_to_group("wall_torch")
		root.add_child(node)


static func _clear(root: Node) -> void:
	var doomed: Array[Node] = []
	for child in root.get_children():
		if child.is_in_group("wall_torch"):
			doomed.append(child)
	for n in doomed:
		root.remove_child(n)
		n.free()


static func _bracket_pos(site: Dictionary) -> Vector3:
	if site.has("px") and site.has("pz"):
		return Vector3(float(site["px"]), 0.0, float(site["pz"]))
	var fx: int = int(site["fx"])
	var fz: int = int(site["fz"])
	var nx: float = float(site["nx"])
	var nz: float = float(site["nz"])
	var px: float = float(fx) + 0.5 - nx * 0.44
	var pz: float = float(fz) + 0.5 - nz * 0.44
	return Vector3(px, 0.0, pz)


func _ready() -> void:
	_nx = float(get_meta("nx", 0.0))
	_nz = float(get_meta("nz", 1.0))
	var tex: Texture2D = _bible()
	if tex != null:
		_half = float(tex.get_width()) * 0.5
		var spr: Sprite3D = Sprite3D.new()
		spr.centered = true
		spr.shaded = false
		spr.billboard = BaseMaterial3D.BILLBOARD_DISABLED
		spr.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
		spr.alpha_cut = SpriteBase3D.ALPHA_CUT_DISCARD
		spr.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		spr.texture = tex
		spr.region_enabled = true
		spr.region_rect = _front_cell()
		spr.pixel_size = 1.45 / maxf(_half, 1.0)
		spr.position.y = 0.72
		_spr = spr
		add_child(spr)
	_flame = _make_flame()
	add_child(_flame)


func _process(_delta: float) -> void:
	if _flame == null:
		return
	var vp: Viewport = get_viewport()
	if vp == null:
		return
	var cam: Camera3D = vp.get_camera_3d()
	if cam == null:
		return
	var flat: Vector3 = cam.global_position - _flame.global_position
	flat.y = 0.0
	if flat.length_squared() < 0.0001:
		return
	_flame.look_at(_flame.global_position + flat, Vector3.UP)


func _front_cell() -> Rect2:
	# Wall normal against the fixed south camera. Quad stays put; only the flame yaws.
	var q: int = int(round(atan2(float(_nx), float(_nz)) / (PI * 0.5)))
	var col: float = 0.0
	var row: float = 0.0
	if q == 1:
		col = _half
	elif absi(q) == 2:
		col = _half
		row = _half
	elif q == -1:
		row = _half
	return Rect2(col, row, _half, _half)


func _make_flame() -> MeshInstance3D:
	if _quad == null:
		var quad: QuadMesh = QuadMesh.new()
		quad.size = Vector2(0.26, 0.42)
		_quad = quad
	if _flame_shader == null:
		var sh: Shader = Shader.new()
		sh.code = FLAME
		_flame_shader = sh
	var mat: ShaderMaterial = ShaderMaterial.new()
	mat.shader = _flame_shader
	mat.set_shader_parameter("flame_seed", float(int(get_meta("fx", 0)) * 13 + _nz * 3))
	var mesh: MeshInstance3D = MeshInstance3D.new()
	mesh.mesh = _quad
	mesh.material_override = mat
	mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var lift: float = 1.18
	mesh.position = Vector3(float(_nx) * 0.12, lift, float(_nz) * 0.12)
	return mesh


static func _bible() -> Texture2D:
	if _keyed != null:
		return _keyed
	if not ResourceLoader.exists(BIBLE):
		return null
	var src: Texture2D = load(BIBLE) as Texture2D
	if src == null:
		return null
	var img: Image = src.get_image()
	if img == null:
		_keyed = src
		return _keyed
	img.convert(Image.FORMAT_RGBA8)
	var w: int = img.get_width()
	var h: int = img.get_height()
	for y in h:
		for x in w:
			var c: Color = img.get_pixel(x, y)
			if c.r > 0.65 and c.b > 0.65 and c.g < 0.28:
				img.set_pixel(x, y, Color(0, 0, 0, 0))
	_keyed = ImageTexture.create_from_image(img)
	return _keyed
