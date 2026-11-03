extends Object

## Mark silhouette mask: glowing and see-through pixels cast no mark. Cut: alpha < CUT drops (glow halos, soft
## edges). GLOW (lit_k) flags a kind's emissive colours: "flame" (saturated 18-62 deg v >= 0.8, imp hand fire, lantern
## flames), "glow" (cyan-blue 160-240 deg v >= 0.6 or white core, wisp body, crystal light). Cached per texture and rule.

const CUT := 0.5
static var _cache: Dictionary = {}

static func rule_of(n: Node) -> String:
	if n == null:
		return ""
	const K := preload("res://scripts/graphics/actor_lit/lit_k.gd")
	for key in ["type_id", "kind"]:
		var v: Variant = n.get(key) if n.get(key) != null else (n.get_meta(key) if n.has_meta(key) else null)
		if v != null and K.GLOW.has(str(v)):
			return K.GLOW[str(v)]
	return ""

static func emissive(c: Color, rule: String) -> bool:
	if rule == "flame":
		return c.h * 360.0 >= 18.0 and c.h * 360.0 <= 62.0 and c.s >= 0.6 and c.v >= 0.8
	if rule == "glow":
		return (c.h * 360.0 >= 160.0 and c.h * 360.0 <= 240.0 and c.v >= 0.6) or (c.s < 0.15 and c.v >= 0.9)
	return false

static func image(img: Image, rule: String) -> Image:
	var out: Image = img.duplicate()
	if out.is_compressed():
		out.decompress()
	out.convert(Image.FORMAT_RGBA8)
	for y in out.get_height():
		for x in out.get_width():
			var c: Color = out.get_pixel(x, y)
			if c.a > 0.0 and (c.a < CUT or emissive(c, rule)):
				out.set_pixel(x, y, Color(c.r, c.g, c.b, 0.0))
	return out

static func mask(tex: Texture2D, rule: String) -> Texture2D:
	if tex == null or rule == "":
		return tex  # the mark shader cuts alpha < CUT itself; only flagged kinds need a colour pass
	var key: String = "%d:%s" % [tex.get_rid().get_id(), rule]
	if _cache.has(key):
		return _cache[key]
	var src: Image = tex.get_image()
	if src == null:
		return tex
	var t: Texture2D = ImageTexture.create_from_image(image(src, rule))
	_cache[key] = t
	return t
