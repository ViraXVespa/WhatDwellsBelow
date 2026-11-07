extends RefCounted

## Shared by dungeon_bench / hub_bench and their _iso helpers: frame-cap setup,
## heartbeat line, isolate-leg reset, and per-tag node counts.

const CliArgs := preload("res://scripts/app/cli_args.gd")
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

static func start_fresh(score_where: String = "", harness: bool = false) -> bool:
	vsync_off()
	if warm_user():
		hb("HB: fresh=0")
		hb("HB: missing=warm_user")
		hb("HB: ok=0")
		App.get_tree().quit(1)
		return false
	var mult: float = CliArgs.float_arg("--wdb-hitch-mult", 1.0)
	HitchLog.bench_reset(mult)
	if score_where != "":
		HitchLog.set_score_where(score_where)
	if harness:
		HitchLog.arm_harness()
	HitchLog.set_phase("wait")
	hb("HB: fresh=1")
	App.character_type = "male"
	App.character_chosen = true
	return true

static func iso_add(host: Node, n: Node, tag: String) -> void:
	if n is Node3D:
		var body: Node3D = n as Node3D
		host._iso_all.append(body)
		host._iso_on.append(body.visible)
		host._iso_tag.append(tag)
	elif n is CanvasLayer:
		var layer: CanvasLayer = n as CanvasLayer
		host._iso_all.append(layer)
		host._iso_on.append(layer.visible)
		host._iso_tag.append(tag)

static func percentile(vals: Array[float], fraction: float, empty: float = 0.0) -> float:
	if vals.is_empty():
		return empty
	var ordered: Array[float] = vals.duplicate()
	ordered.sort()
	var at: int = int(round(float(ordered.size() - 1) * fraction))
	return ordered[at]
