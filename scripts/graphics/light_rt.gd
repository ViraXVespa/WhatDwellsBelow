extends Object

## Origin and span are what the floor and wall shaders already sample. The RT is SUB 4 texels per tile.

const T := preload("res://scripts/data/tunables.gd")
const Stamp := preload("res://scripts/graphics/light_stamp.gd")
const HubBake := preload("res://scripts/graphics/light_rt/hub_bake.gd")
const Publish := preload("res://scripts/graphics/light_rt/publish.gd")

const COL_TORCH := Color(1.0, 0.48, 0.16)
const COL_CRYSTAL := Color(0.35, 0.72, 1.0)
const COL_FIRE := Color(1.0, 0.40, 0.12)
const COL_SUN := Color(1.0, 0.78, 0.48)

const HUB_LIGHT_PATH := "res://assets/baked/hub_light.png"
const HUB_SUB := 16
static var tex: Texture2D
static var origin := Vector2.ZERO
static var span := Vector2.ONE
static var _gpu: ImageTexture
static var _mats: Array[ShaderMaterial] = []
static var _props: Array[Node] = []
static var _sites: Array[Dictionary] = []
static var _planned := false
static var _plan_partial := false
static var _plan_dirty := true
static var _rect := Rect2i(-1, -1, 0, 0)
static var _live := ""
static var _knob := ""
static var _bill: GDScript
static var _img: Image
static var _solid: PackedByteArray = PackedByteArray()
static var _sw := 0
static var _sh := 0
static var _sn := 0
static var _casts: Array[Dictionary] = []
static var hub_crystal := Vector2.ZERO
static var _hub_layout: Node

static func texture() -> Texture2D:
	if tex != null:
		return tex
	var img: Image = Image.create(1, 1, false, Image.FORMAT_RGBA8)
	img.fill(Color.WHITE)
	tex = ImageTexture.create_from_image(img)
	return tex
static func bind(mat: ShaderMaterial) -> void:
	if mat == null:
		return
	if tex == null:
		texture()
	mat.set_shader_parameter("light_tex", tex)
	mat.set_shader_parameter("light_origin", origin)
	mat.set_shader_parameter("light_span", span)
	if not _mats.has(mat):
		_mats.append(mat)
static func rebuild_hub(x0: int, z0: int, x1: int, z1: int, crystal_xz: Vector2, layout: Node = null) -> void:
	HubBake.rebuild_hub(x0, z0, x1, z1, crystal_xz, layout)
static func rebind_tree(n: Node) -> void:
	if n == null:
		return
	if n is MeshInstance3D:
		var mi: MeshInstance3D = n
		if mi.material_override is ShaderMaterial:
			bind(mi.material_override)
	var i: int = 0
	while i < n.get_child_count():
		rebind_tree(n.get_child(i))
		i += 1
static func save_hub_bake() -> void:
	HubBake.save_hub_bake()
static func prepare_hub(x0: int, z0: int, x1: int, z1: int, crystal_xz: Vector2, layout: Node = null) -> void:
	HubBake.prepare_hub(x0, z0, x1, z1, crystal_xz, layout)
static func note_prop(node: Node) -> void:
	if node == null:
		return
	var kind: String = str(node.get("kind"))
	if kind != "crystal" and kind != "campfire":
		return
	if not App.in_dungeon:
		return
	if _props.has(node):
		return
	_props.append(node)
	_plan_dirty = true
static func drop_prop(node: Node) -> void:
	_props.erase(node)
	_plan_dirty = true
static func reset_floor() -> void:
	_props.clear()
	_sites.clear()
	_planned = false
	_plan_partial = false
	_plan_dirty = true
	_live = ""
	_knob = ""
	_rect = Rect2i(-1, -1, 0, 0)
static func maintain(host: Node) -> void:
	Publish.maintain(host)
static func _push() -> void:
	var keep: Array[ShaderMaterial] = []
	for mat in _mats:
		if mat == null or not is_instance_valid(mat):
			continue
		mat.set_shader_parameter("light_tex", tex)
		mat.set_shader_parameter("light_origin", origin)
		mat.set_shader_parameter("light_span", span)
		keep.append(mat)
	_mats = keep
static func sample_xz(world: Vector2) -> Color:
	# Same luv as the floor and wall shaders. Bilinear across texels.
	if _img == null:
		return Color.WHITE
	var sp: Vector2 = span
	if sp.x < 0.001 or sp.y < 0.001:
		return Color.WHITE
	var w: int = _img.get_width()
	var h: int = _img.get_height()
	if w < 1 or h < 1:
		return Color.WHITE
	var luv: Vector2 = (world - origin) / sp
	var u: float = clampf(luv.x, 0.0, 1.0)
	var v: float = clampf(luv.y, 0.0, 1.0)
	var max_x: float = maxf(float(w) - 1.0001, 0.0)
	var max_y: float = maxf(float(h) - 1.0001, 0.0)
	var px: float = clampf(u * float(w) - 0.5, 0.0, max_x)
	var py: float = clampf(v * float(h) - 0.5, 0.0, max_y)
	var x0: int = int(floor(px))
	var y0: int = int(floor(py))
	var x1: int = mini(x0 + 1, w - 1)
	var y1: int = mini(y0 + 1, h - 1)
	var fx: float = px - float(x0)
	var fy: float = py - float(y0)
	var c00: Color = _img.get_pixel(x0, y0)
	var c10: Color = _img.get_pixel(x1, y0)
	var c01: Color = _img.get_pixel(x0, y1)
	var c11: Color = _img.get_pixel(x1, y1)
	return c00.lerp(c10, fx).lerp(c01.lerp(c11, fx), fy)
static func floor_open(world: Vector2) -> bool:
	if _img == null:
		return false
	var sp: Vector2 = span
	if sp.x < 0.001 or sp.y < 0.001:
		return false
	if world.x < origin.x or world.y < origin.y:
		return false
	if world.x >= origin.x + sp.x or world.y >= origin.y + sp.y:
		return false
	if _sn < 1 or _solid.is_empty():
		return true
	return Stamp.solid_open(_solid, _sw, _sh, _sn, world.x, world.y)
static func nearest_casts(world: Vector2, cap: int = 3) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var limit: int = cap
	if limit < 1:
		return out
	for src in _casts:
		var item: Dictionary = src
		var xz: Vector2 = item["xz"]
		var reach: float = float(item["reach"])
		var dist: float = world.distance_to(xz)
		if dist > reach:
			continue
		var row: Dictionary = {"ok": true, "xz": xz, "dist": dist, "reach": reach}
		var at: int = out.size()
		for i in out.size():
			var prev: Dictionary = out[i]
			if dist < float(prev["dist"]):
				at = i
				break
		if at >= limit:
			continue
		out.insert(at, row)
		if out.size() > limit:
			out.resize(limit)
	return out
