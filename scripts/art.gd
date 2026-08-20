class_name Art
extends Object

const FACING_KEYS := ["right", "down_right", "down", "down_left", "left", "up_left", "up", "up_right"]


static func facing_from_dir(dir: Vector2) -> String:
	if dir.length_squared() < 0.0001:
		return "down"
	var oct := int(round(atan2(dir.y, dir.x) / (PI * 0.25)))
	match oct:
		0:
			return "right"
		1:
			return "down_right"
		2:
			return "down"
		3:
			return "down_left"
		4, -4:
			return "left"
		-3:
			return "up_left"
		-2:
			return "up"
		-1:
			return "up_right"
		_:
			return "down"


static func cardinal_from_dir(dir: Vector2) -> String:
	if absf(dir.x) > absf(dir.y):
		return "right" if dir.x > 0.0 else "left"
	return "down" if dir.y >= 0.0 else "up"


static func pick_facing(dir: Vector2, sprites: Dictionary, prefix: String = "") -> String:
	var key := facing_from_dir(dir)
	if sprites.has(prefix + key):
		return key
	key = cardinal_from_dir(dir)
	if sprites.has(prefix + key):
		return key
	for fallback in ["down", "right", "left", "up"]:
		if sprites.has(prefix + fallback):
			return fallback
	return "down"


# Pin texture by offset so the sprite sits on the collider (not a half-size right shift).
static func make_sprite(tex: Texture2D = null, scale := 1.0) -> Sprite2D:
	var s := Sprite2D.new()
	s.centered = false
	s.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	s.scale = Vector2(scale, scale)
	if tex:
		apply_tex(s, tex)
	return s


static func apply_tex(s: Sprite2D, tex: Texture2D, anchor_body: bool = false) -> void:
	s.texture = tex
	if tex:
		s.centered = false
		s.offset = -body_pivot(tex) if anchor_body else -tex.get_size() * 0.5
	else:
		s.offset = Vector2.ZERO


## Texture-space point that should sit on the node origin (torso / stand-point),
## not the canvas center — otherwise 4-dir swaps orbit around the weapon.
static func body_pivot(tex: Texture2D) -> Vector2:
	if tex.has_meta("wdb_pivot"):
		return tex.get_meta("wdb_pivot")
	var fallback := tex.get_size() * 0.5
	var img := tex.get_image()
	if img == null:
		return fallback
	if img.is_compressed():
		img.decompress()
	var w := img.get_width()
	var h := img.get_height()
	var miny := h
	var maxy := 0
	for y in h:
		for x in w:
			if img.get_pixel(x, y).a > 0.1:
				miny = mini(miny, y)
				maxy = maxi(maxy, y)
	if maxy <= miny:
		tex.set_meta("wdb_pivot", fallback)
		return fallback
	var y0 := miny + int(float(maxy - miny) * 0.86)
	var xs: Array[int] = []
	var feet_y := miny
	for y in range(y0, maxy + 1):
		for x in w:
			var c := img.get_pixel(x, y)
			if c.a <= 0.1:
				continue
			var cyan := c.b > c.r + 0.06 and c.b > c.g + 0.04 and c.b > 0.32
			if cyan:
				continue
			xs.append(x)
			feet_y = maxi(feet_y, y)
	if xs.is_empty():
		tex.set_meta("wdb_pivot", fallback)
		return fallback
	xs.sort()
	var fx := xs[xs.size() / 2]
	var ty := feet_y - int(float(maxy - miny) * 0.38)
	var pivot := Vector2(fx, ty)
	tex.set_meta("wdb_pivot", pivot)
	return pivot


static func load_tex(path: String) -> Texture2D:
	if path != "" and ResourceLoader.exists(path):
		return load(path) as Texture2D
	return null


static func foot_sprite(tex: Texture2D, scale := 1.0) -> Sprite2D:
	var s := Sprite2D.new()
	s.centered = false
	s.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	s.scale = Vector2(scale, scale)
	if tex:
		s.texture = tex
		var sz: Vector2 = tex.get_size()
		s.offset = Vector2(-sz.x * 0.5, -sz.y)
	return s


static func add_blocker(host: Node, size: Vector2, local_pos: Vector2 = Vector2.ZERO) -> void:
	var body := StaticBody2D.new()
	body.collision_layer = 1
	body.collision_mask = 0
	body.position = local_pos
	var cs := CollisionShape2D.new()
	var sh := RectangleShape2D.new()
	sh.size = size
	cs.shape = sh
	body.add_child(cs)
	host.add_child(body)


static func solid(size: Vector2i, fill: Color) -> Texture2D:
	var img := Image.create(size.x, size.y, false, Image.FORMAT_RGBA8)
	img.fill(fill)
	return ImageTexture.create_from_image(img)


static func body(size: Vector2i, fill: Color, accent: Color) -> Texture2D:
	var img := Image.create(size.x, size.y, false, Image.FORMAT_RGBA8)
	img.fill(fill)
	var m := 8
	img.fill_rect(Rect2i(m, m, size.x - m * 2, size.y - m * 2), fill.lightened(0.12))
	img.fill_rect(Rect2i(size.x / 2 - 6, 4, 12, 14), accent)
	return ImageTexture.create_from_image(img)


static func stairs(size: Vector2i) -> Texture2D:
	var img := Image.create(size.x, size.y, false, Image.FORMAT_RGBA8)
	img.fill(Color(0.08, 0.18, 0.22, 1.0))
	var cyan := Color(0.35, 0.88, 0.92)
	var gold := Color(0.92, 0.78, 0.28)
	img.fill_rect(Rect2i(0, 0, size.x, 4), cyan)
	img.fill_rect(Rect2i(0, size.y - 4, size.x, 4), cyan)
	img.fill_rect(Rect2i(0, 0, 4, size.y), cyan)
	img.fill_rect(Rect2i(size.x - 4, 0, 4, size.y), cyan)
	var steps := 4
	for i in steps:
		var t := float(i + 1) / float(steps + 1)
		var inset := int(6 + t * float(size.x) * 0.28)
		var y := int(10 + t * float(size.y - 22))
		var h := 6
		var col := cyan.lerp(gold, t)
		img.fill_rect(Rect2i(inset, y, size.x - inset * 2, h), col)
	img.fill_rect(Rect2i(size.x / 2 - 4, size.y - 16, 8, 12), gold)
	return ImageTexture.create_from_image(img)


static func ore_vein(size: Vector2i) -> Texture2D:
	var img := Image.create(size.x, size.y, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	var rock := Color(0.38, 0.34, 0.32)
	var dark := Color(0.18, 0.16, 0.15)
	var spark := Color(0.55, 0.62, 0.72)
	img.fill_rect(Rect2i(4, 8, size.x - 8, size.y - 12), rock)
	img.fill_rect(Rect2i(8, 4, size.x - 16, 10), rock.lightened(0.08))
	img.fill_rect(Rect2i(6, 14, 8, 6), dark)
	img.fill_rect(Rect2i(size.x - 16, 18, 10, 8), dark)
	img.fill_rect(Rect2i(12, 10, 4, 4), spark)
	img.fill_rect(Rect2i(size.x / 2, 20, 5, 5), spark.lightened(0.15))
	img.fill_rect(Rect2i(18, size.y - 14, 3, 3), spark)
	return ImageTexture.create_from_image(img)


static func chest(size: Vector2i) -> Texture2D:
	var img := Image.create(size.x, size.y, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	var wood := Color(0.55, 0.32, 0.12)
	var dark := Color(0.28, 0.15, 0.06)
	var gold := Color(0.92, 0.74, 0.18)
	img.fill_rect(Rect2i(6, 18, size.x - 12, size.y - 24), wood)
	img.fill_rect(Rect2i(6, 10, size.x - 12, 16), wood.lightened(0.08))
	img.fill_rect(Rect2i(6, 24, size.x - 12, 4), dark)
	img.fill_rect(Rect2i(size.x / 2 - 4, 18, 8, 14), gold)
	img.fill_rect(Rect2i(8, 14, size.x - 16, 3), gold)
	return ImageTexture.create_from_image(img)


static func rarity_color(rarity: int) -> Color:
	match rarity:
		0:
			return Color(0.82, 0.82, 0.82)
		1:
			return Color(0.35, 0.78, 0.38)
		2:
			return Color(0.30, 0.50, 0.95)
		3:
			return Color(0.70, 0.35, 0.90)
		4:
			return Color(0.95, 0.55, 0.12)
		_:
			return Color.WHITE
