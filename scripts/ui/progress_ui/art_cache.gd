extends Object

## Frame-art PNG cache every *_art.gd calls (leaf: loads no script). art_bake.gd drives bakes and sets `drawing`.

const DIR := "res://assets/ui/frames/"

## True while baking: pictures are drawn in code instead of loaded.
static var drawing: bool = false

static func path_of(art: String, key: String) -> String:
	return DIR + art + "/" + key + ".png"

## Cache check for an art function: true when cache[key] is ready (loaded from its PNG), false only while baking
## (draw it). A missing PNG fails loudly.
static func hit(cache: Dictionary, art: String, key: String) -> bool:
	if cache.has(key):
		return true
	if drawing:
		return false
	var path: String = path_of(art, key)
	var tex: Texture2D = load(path) as Texture2D if ResourceLoader.exists(path) else null
	if tex == null:
		push_error("frame art PNG missing: %s (run tools/bake.py frames)" % path)
		assert(false, "frame art PNG missing: " + path)
		return false
	cache[key] = tex
	return true
