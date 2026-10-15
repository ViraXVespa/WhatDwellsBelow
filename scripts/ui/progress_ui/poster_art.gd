extends Object

## Hand-made quest-board art. A missing file is an error; there is no drawn stand-in.

const DIR := "res://assets/ui/posters/"
const REQUIRED: Array[String] = ["board.png", "poster.png", "pin.png"]

static var _cache: Dictionary = {}

static func tex(file_name: String) -> Texture2D:
	if not REQUIRED.has(file_name):
		push_error("poster art is not a required file: " + file_name)
		assert(false, "poster art is not a required file: " + file_name)
	if _cache.has(file_name):
		return _cache[file_name] as Texture2D
	var path: String = DIR + file_name
	var img: Texture2D = load(path) as Texture2D if ResourceLoader.exists(path) else null
	if img == null:
		push_error("poster art PNG missing: " + path)
		assert(false, "poster art PNG missing: " + path)
	_cache[file_name] = img
	return img
