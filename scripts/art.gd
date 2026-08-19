class_name Art
extends Object

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
