extends Object

## Floor minimap. The base image is built once when the floor is ready.
## Fog is a mask texture. Crystals and the player marker are a second image, written on those events.
## Enemies, loot and interactables are drawn over both by map_marks.gd. Region math and view sync: minimap_view.gd.

const Gen := preload("res://scripts/dungeon/gen.gd")
const T := preload("res://scripts/data/tunables.gd")
const ThemeS := preload("res://scripts/ui/theme.gd")
const View := preload("res://scripts/world/dungeon/minimap_view.gd")
const Marks := preload("res://scripts/world/dungeon/map_marks.gd")

const _SHADER := """shader_type canvas_item;

uniform sampler2D base_tex : filter_nearest, repeat_disable;
uniform sampler2D mask_tex : filter_nearest, repeat_disable;
uniform sampler2D mark_tex : filter_nearest, repeat_disable;
uniform vec4 fog_color : source_color = vec4(0.02, 0.02, 0.03, 1.0);
uniform vec4 region = vec4(0.0, 0.0, 1.0, 1.0);

void fragment() {
	vec2 uv = region.xy + UV * region.zw;
	vec4 base_px = texture(base_tex, uv);
	float revealed = texture(mask_tex, uv).r;
	vec4 mark_px = texture(mark_tex, uv);
	vec4 terrain = mix(fog_color, base_px, revealed);
	COLOR = mix(terrain, mark_px, mark_px.a * revealed);
}
"""

static var _shader: Shader = null

## Last full reveal: same host, cell, radius and visited buffer means every cell in the disk is already set
## (visited bits are only ever set; dungeon_boot calls forget() when it makes a new buffer), so the walk is skipped.
static var _last_host: int = 0
static var _last_c: Vector2i = Vector2i(-99999, -99999)
static var _last_rad: int = -1

static func forget() -> void:
	_last_host = 0
	_last_rad = -1

static func _ensure_shader() -> Shader:
	if _shader == null:
		_shader = Shader.new()
		_shader.code = _SHADER
	return _shader

static func _terrain(host: Node, x: int, y: int) -> Color:
	var w: int = int(host.data.w)
	if host.data.grid[Gen.idx(x, y, w)] == Gen.FLOOR:
		return Color(0.22, 0.24, 0.28)
	return Color(0.08, 0.08, 0.1)

static func _inside(host: Node, p: Vector2i) -> bool:
	return p.x >= 0 and p.y >= 0 and p.x < int(host.data.w) and p.y < int(host.data.h)

static func _seen(host: Node, p: Vector2i) -> bool:
	if not _inside(host, p):
		return false
	return host.visited[Gen.idx(p.x, p.y, int(host.data.w))] != 0

static func _base_dot(host: Node, p: Vector2i, col: Color) -> void:
	if host.map_img == null or not _inside(host, p):
		return
	host.map_img.set_pixel(p.x, p.y, col)

static func _bake_static(host: Node) -> void:
	var stairs: Vector2i = host.data.stairs
	_base_dot(host, stairs, Color(0.95, 0.75, 0.25))
	var marked := false
	var openings: Array = host.data.get("openings", [])
	for o: Variant in openings:
		var opening: Dictionary = o as Dictionary
		var cells: Array = opening.get("cells", [])
		for raw: Variant in cells:
			_base_dot(host, Vector2i(raw), Color(0.9, 0.2, 0.15))
			marked = true
	if not marked:
		var door_cell: Vector2i = host.data.door
		_base_dot(host, door_cell, Color(0.9, 0.2, 0.15))

static func _build_base(host: Node) -> void:
	host.map_seen_min = Vector2i(-1, -1)
	host.map_seen_max = Vector2i(-1, -1)
	var w: int = int(host.data.w)
	var h: int = int(host.data.h)
	host.map_img = Image.create(w, h, false, Image.FORMAT_RGBA8)
	for y: int in h:
		for x: int in w:
			host.map_img.set_pixel(x, y, _terrain(host, x, y))
	_bake_static(host)
	host.map_tex = ImageTexture.create_from_image(host.map_img)
	host.map_mask = Image.create(w, h, false, Image.FORMAT_RGBA8)
	host.map_mask.fill(Color(0, 0, 0, 1))
	# Born after the first reveal paints. A texture created from the still-black mask stays black:
	# ImageTexture.update during floor ready does not replace that upload on the compatibility renderer.
	host.map_mask_tex = null
	host.map_marks = Image.create(w, h, false, Image.FORMAT_RGBA8)
	host.map_marks.fill(Color(0, 0, 0, 0))
	host.map_mark_tex = null
	host.map_shader = _ensure_shader()

static func attach(host: Node, rect: TextureRect, region: Rect2) -> void:
	View.attach(host, rect, region)

## First call creates the texture from the painted image. Later calls replace its storage.
static func _upload(tex: ImageTexture, img: Image) -> ImageTexture:
	if img == null:
		return tex
	if tex == null:
		return ImageTexture.create_from_image(img)
	tex.set_image(img)
	return tex

static func refresh_marks(host: Node) -> void:
	if host.map_marks == null:
		return
	host.map_marks.fill(Color(0, 0, 0, 0))
	var CrystalNet: GDScript = load("res://scripts/world/crystal/net.gd") as GDScript
	for n: Node in CrystalNet.floor_list(host):
		var cell: Vector2i = Vector2i(n.get("crystal_cell"))
		if not _seen(host, cell):
			continue
		var on: bool = bool(n.get("crystal_on"))
		var col: Color = Color(0.35, 0.95, 1.0) if on else Color(0.2, 0.45, 0.55)
		if _inside(host, cell):
			host.map_marks.set_pixel(cell.x, cell.y, col)
	var pc: Vector2i = host.get_meta("map_pc", Vector2i(-999, -999))
	if pc.x >= 0 and _inside(host, pc):
		host.map_marks.set_pixel(pc.x, pc.y, Color(1, 1, 1))
	host.map_mark_tex = _upload(host.map_mark_tex, host.map_marks)

static func note_player(host: Node, cell: Vector2i) -> void:
	host.set_meta("map_pc", cell)
	refresh_marks(host)
	View.sync_views(host)

static func reveal_around(host: Node, c: Vector2i, rad: int) -> bool:
	if host.map_mask == null:
		return false
	var hid: int = host.get_instance_id()
	if hid == _last_host and c == _last_c and rad == _last_rad:
		return false
	_last_host = hid
	_last_c = c
	_last_rad = rad
	var w: int = int(host.data.w)
	var h: int = int(host.data.h)
	var r2: int = rad * rad
	var grew := false
	var mask_dirty := false
	for y: int in range(maxi(0, c.y - rad), mini(h, c.y + rad + 1)):
		for x: int in range(maxi(0, c.x - rad), mini(w, c.x + rad + 1)):
			var dx: int = x - c.x
			var dy: int = y - c.y
			if dx * dx + dy * dy <= r2:
				var i: int = Gen.idx(x, y, w)
				if host.visited[i] == 0:
					host.visited[i] = 1
					grew = true
					_note_seen(host, x, y)
					host.map_mask.set_pixel(x, y, Color(1, 1, 1, 1))
					mask_dirty = true
	if mask_dirty:
		host.map_mask_tex = _upload(host.map_mask_tex, host.map_mask)
	if grew:
		refresh_marks(host)
		View.sync_views(host)
	return grew

static func make_map(host: Node) -> void:
	host.map_state = "mini"
	host.map_arm_ms = -1
	host.map_layer = CanvasLayer.new()
	host.map_layer.layer = 30
	host.map_layer.visible = false
	host.add_child(host.map_layer)
	host.map_shade = Control.new()
	host.map_shade.set_anchors_preset(Control.PRESET_FULL_RECT)
	host.map_shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	host.map_layer.add_child(host.map_shade)
	var shade_i: int = 0
	while shade_i < 4:
		var bar: ColorRect = ColorRect.new()
		bar.color = Color(0.02, 0.03, 0.05, 0.55)
		bar.mouse_filter = Control.MOUSE_FILTER_STOP
		bar.gui_input.connect(func(ev: InputEvent) -> void: _map_input(host, ev))
		host.map_shade.add_child(bar)
		shade_i += 1
	host.map_border = ColorRect.new()
	host.map_border.color = ThemeS.RULE
	host.map_border.mouse_filter = Control.MOUSE_FILTER_IGNORE
	host.map_layer.add_child(host.map_border)
	host.map_clip = Control.new()
	host.map_clip.clip_contents = true
	host.map_clip.mouse_filter = Control.MOUSE_FILTER_STOP
	host.map_clip.gui_input.connect(func(ev: InputEvent) -> void: _map_input(host, ev))
	host.map_layer.add_child(host.map_clip)
	_build_base(host)
	host.map_rect = TextureRect.new()
	host.map_rect.texture = host.map_tex
	host.map_rect.stretch_mode = TextureRect.STRETCH_SCALE
	host.map_rect.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	host.map_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	host.map_clip.add_child(host.map_rect)
	attach(host, host.map_rect, Rect2(0, 0, 1, 1))
	Marks.bind(host, host.map_rect, Rect2(0, 0, 1, 1))
	var viewport: Viewport = host.get_viewport()
	if not viewport.size_changed.is_connected(host._redraw_map):
		viewport.size_changed.connect(host._redraw_map)
	host.set_meta("map_pc", Vector2i(-999, -999))
	redraw_map(host)
	var MapActS: GDScript = load("res://scripts/world/dungeon/map_act.gd") as GDScript
	MapActS.reset(host)

static func _map_input(host: Node, event: InputEvent) -> void:
	var LookS: GDScript = load("res://scripts/input/look_ctrl.gd") as GDScript
	LookS.note_event(event)
	var MapActS: GDScript = load("res://scripts/world/dungeon/map_act.gd") as GDScript
	if MapActS.handle_mouse(host, event):
		host.get_viewport().set_input_as_handled()

static func redraw_map(host: Node) -> void:
	if host.map_img == null:
		return
	if host.player:
		var pc := Vector2i(int(host.player.global_position.x), int(host.player.global_position.z))
		host.set_meta("map_pc", pc)
	refresh_marks(host)
	if host.map_rect:
		attach(host, host.map_rect, Rect2(0, 0, 1, 1))
	View.sync_views(host)

static func _note_seen(host: Node, x: int, y: int) -> void:
	var lo: Vector2i = host.map_seen_min
	var hi: Vector2i = host.map_seen_max
	if lo.x < 0:
		host.map_seen_min = Vector2i(x, y)
		host.map_seen_max = Vector2i(x, y)
		return
	host.map_seen_min = Vector2i(mini(lo.x, x), mini(lo.y, y))
	host.map_seen_max = Vector2i(maxi(hi.x, x), maxi(hi.y, y))
