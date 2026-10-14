extends Object

## Quest-board poster art is hand-made PNG (her ruling): res://assets/ui/posters/<name>.png, loaded once and cached.
## A missing PNG is an error; there is no drawn or default stand-in. Names in REQUIRED are what the poster frame
## needs; the frame is built by the ui-quest-board-posters task once the art exists.

const DIR := "res://assets/ui/posters/"
## board: the notice-board backdrop; poster: one blank poster sheet (text is drawn on top); pin: the pin sprite.
const REQUIRED: Array[String] = ["board", "poster", "pin"]

static var _cache: Dictionary = {}

static func path_of(name: String) -> String:
	return DIR + name + ".png"

static func tex(name: String) -> Texture2D:
	if _cache.has(name):
		return _cache[name]
	var path: String = path_of(name)
	var t: Texture2D = load(path) as Texture2D if ResourceLoader.exists(path) else null
	if t == null:
		push_error("poster art PNG missing: " + path)
		assert(false, "poster art PNG missing: " + path)
		return null
	_cache[name] = t
	return t

## Names in REQUIRED with no PNG yet (for the task's start check and the warm-up).
static func missing() -> Array[String]:
	var out: Array[String] = []
	for n: String in REQUIRED:
		if not ResourceLoader.exists(path_of(n)):
			out.append(n)
	return out
