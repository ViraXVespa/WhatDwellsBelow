extends Object

## Object-frame art ships as baked PNGs: res://assets/ui/frames/<art>/<key>.png. The *_art.gd scripts still hold
## the drawing code; at runtime each picture comes from its PNG (hit() fills the script's cache), and a missing PNG
## is an error, never redrawn. Re-bake after editing any *_art.gd: `python tools/bake.py frames` (runs the game
## with --wdb-bake-frame-art: draws every skin in code and writes the PNGs). --wdb-frame-art-time prints how long
## building every skin takes (draw cost before a bake, load cost after).

const DIR := "res://assets/ui/frames/"
const BAKE_FLAG := "--wdb-bake-frame-art"
const TIME_FLAG := "--wdb-frame-art-time"
## Draw in code and compare with the committed PNGs (exit 1 on any stale or missing picture).
const CHECK_FLAG := "--wdb-frame-art-check"
const FRAME_SET := "res://scripts/ui/progress_ui/frame_set.gd"
## Every art script; each declares ART (its folder name) and a static _images cache.
const ARTS: Array[String] = [
	"res://scripts/ui/progress_ui/vendor_art.gd",
	"res://scripts/ui/progress_ui/dumpster_art.gd",
	"res://scripts/ui/progress_ui/controls_art.gd",
	"res://scripts/ui/progress_ui/anvil_art.gd",
	"res://scripts/ui/progress_ui/crystal_art.gd",
	"res://scripts/ui/progress_ui/extract_art.gd",
	"res://scripts/ui/progress_ui/shop_art.gd",
	"res://scripts/ui/progress_ui/receptionist_art.gd",
	"res://scripts/ui/progress_ui/guide_art.gd",
]

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

static func active() -> bool:
	return OS.get_cmdline_user_args().has(BAKE_FLAG) or OS.get_cmdline_user_args().has(TIME_FLAG) or OS.get_cmdline_user_args().has(CHECK_FLAG)

static func run_and_quit(tree: SceneTree) -> void:
	var check: bool = OS.get_cmdline_user_args().has(CHECK_FLAG)
	if OS.get_cmdline_user_args().has(BAKE_FLAG) or check:
		drawing = true
	var ms: float = _build_all()
	print("FRAME_ART: build_ms=%.1f mode=%s" % [ms, "draw" if drawing else "load"])
	var ok: bool = true
	if check:
		ok = _compare()
	elif drawing:
		ok = _write()
	tree.quit(0 if ok else 1)

static func _build_all() -> float:
	var t0: int = Time.get_ticks_usec()
	for skin: GDScript in (load(FRAME_SET) as GDScript).get("SKINS"):
		var t: int = Time.get_ticks_usec()
		var scratch := Control.new()
		skin.build(scratch)
		scratch.free()
		_dress_all(skin)
		print("FRAME_ART: %s ms=%.1f" % [skin.resource_path.get_file(), (Time.get_ticks_usec() - t) / 1000.0])
	return (Time.get_ticks_usec() - t0) / 1000.0

## Button looks are drawn when a button is dressed: dress one scratch button per variant so they bake too.
static func _dress_all(skin: GDScript) -> void:
	for m: Dictionary in skin.get_script_method_list():
		if str(m["name"]) != "dress":
			continue
		var variants: Array = [[true], [false]] if (m["args"] as Array).size() > 1 else [[]]
		for v: Array in variants:
			var b := Button.new()
			skin.callv("dress", [b] + v)
			b.free()

static func _write() -> bool:
	var n: int = 0
	for p: String in ARTS:
		var s: GDScript = load(p)
		var art: String = str(s.get("ART"))
		var cache: Dictionary = s.get("_images")
		DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(DIR + art))
		for key: String in cache.keys():
			var img: Image = (cache[key] as Texture2D).get_image()
			var err: int = img.save_png(ProjectSettings.globalize_path(path_of(art, key)))
			if err != OK:
				push_error("frame art: cannot write " + path_of(art, key))
				return false
			n += 1
	print("FRAME_ART: wrote=%d dir=%s" % [n, DIR])
	return n > 0

static func _compare() -> bool:
	var bad: int = 0
	var n: int = 0
	for p: String in ARTS:
		var s: GDScript = load(p)
		var art: String = str(s.get("ART"))
		var cache: Dictionary = s.get("_images")
		for key: String in cache.keys():
			n += 1
			var path: String = path_of(art, key)
			var want: Image = (cache[key] as Texture2D).get_image()
			var tex: Texture2D = load(path) as Texture2D if ResourceLoader.exists(path) else null
			var have: Image = tex.get_image() if tex else null
			if have:
				have.convert(want.get_format())
			if have == null or have.get_size() != want.get_size() or have.get_data() != want.get_data():
				print("FRAME_ART: stale %s" % path)
				bad += 1
	print("FRAME_ART: checked=%d stale=%d" % [n, bad])
	return bad == 0 and n > 0
