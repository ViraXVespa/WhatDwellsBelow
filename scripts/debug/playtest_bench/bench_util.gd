extends RefCounted

## Shared by dungeon_bench / hub_bench and their _iso helpers: frame-cap setup,
## heartbeat line, isolate-leg reset, and per-tag node counts.

const HitchLog := preload("res://scripts/debug/hitch_log.gd")

## Above the 60 FPS bar, and finite. VSYNC_DISABLED with max_fps 0 can peg the GPU.
const FPS_CAP := 120

static func vsync_off() -> void:
	# Compatibility honors VSYNC_DISABLED (swap interval 0). Web ignores it.
	# The cap only pads frames faster than 120; a frame over 16.7 ms stays slow.
	# Borderless fullscreen so the framebuffer is the screen, not a smaller window.
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	Engine.max_fps = FPS_CAP
	if not OS.has_feature("web"):
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)

static func warm_user() -> bool:
	return FileAccess.file_exists("user://live/save.json")

static func hb(msg: String) -> void:
	printerr(msg)
	HitchLog.hb(msg)

## True when host moved to a new isolate leg; clears that leg's samples.
static func iso_enter(host: Node) -> bool:
	if host._iso_applied == host._iso_i:
		return false
	host._iso_applied = host._iso_i
	host._iso_t = 0.0
	host._iso_dts.clear()
	host._iso_proc.clear()
	host._iso_phys.clear()
	host._iso_submit.clear()
	return true

## "a=1 b=0 ..." for each name, counting host._iso_tag entries.
static func tag_counts(tags: Array, names: PackedStringArray) -> String:
	var n: Dictionary = {}
	for t in tags:
		n[t] = int(n.get(t, 0)) + 1
	var parts: PackedStringArray = []
	for k in names:
		parts.append("%s=%d" % [k, int(n.get(k, 0))])
	return " ".join(parts)

## Walk out and back on each facing; true when the 0.8 s sub-step rolled over.
static func walk_leg(host: Node, delta: float) -> bool:
	var leg: int = int(host._fill_i / 2.0) % host._dirs.size()
	var dir: Vector2 = host._dirs[leg]
	if host._fill_i % 2 == 1:
		dir = -dir
	App.playtest.move = dir
	App.playtest.aim = dir
	host._sub_t += delta
	if host._sub_t < 0.8:
		return false
	host._sub_t = 0.0
	host._fill_i += 1
	return true
