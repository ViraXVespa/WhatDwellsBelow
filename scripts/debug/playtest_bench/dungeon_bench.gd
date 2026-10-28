extends Node

## --wdb-dungeon-bench: one fresh-save playtest at time scale 1, then quit.
## Frames count only while the dungeon scene is showing and the loader bar is down.
## --wdb-pt-sec (default 30) is acting seconds. --wdb-hitch-mult=N (default 1).
## --wdb-dungeon-walk-layers times hidden groups during play and does not score fps_pct.

const FLAG := "--wdb-dungeon-bench"
const CliArgs := preload("res://scripts/app/cli_args.gd")
const HitchLog := preload("res://scripts/debug/hitch_log.gd")
const Iso := preload("res://scripts/debug/playtest_bench/dungeon_bench_iso.gd")

const WAIT_SEC := 120.0
const HARD_SEC := 210.0
## Above the 60 FPS bar, and finite. VSYNC_DISABLED with max_fps 0 can peg the GPU.
const FPS_CAP := 120

static func active() -> bool:
	return CliArgs.has(FLAG)

static func _vsync_off() -> void:
	# Compatibility honors VSYNC_DISABLED (swap interval 0). Web ignores it.
	# The cap only pads frames faster than 120; a frame over 16.7 ms stays slow.
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	Engine.max_fps = FPS_CAP
	if not OS.has_feature("web"):
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)

static func _warm_user() -> bool:
	return FileAccess.file_exists("user://live/save.json")

static func _hb(msg: String) -> void:
	printerr(msg)
	HitchLog.hb(msg)

static func start() -> void:
	_vsync_off()
	if _warm_user():
		_hb("HB: fresh=0")
		_hb("HB: missing=warm_user")
		_hb("HB: ok=0")
		App.get_tree().quit(1)
		return
	var mult: float = CliArgs.float_arg("--wdb-hitch-mult", 1.0)
	HitchLog.bench_reset(mult)
	HitchLog.set_score_where("dungeon")
	HitchLog.arm_harness()
	HitchLog.set_phase("wait")
	_hb("HB: fresh=1")
	App.character_type = "male"
	App.character_chosen = true
	attach(App)

static func attach(_host: Node) -> void:
	if not active() or App.get_node_or_null("DungeonBench") != null:
		return
	var scr: GDScript = load("res://scripts/debug/playtest_bench/dungeon_bench.gd") as GDScript
	var node: Node = scr.new() as Node
	node.name = "DungeonBench"
	App.add_child(node)

var _clock: float = 0.0
var _wall0: int = 0
var _wait_hb: float = 0.0
var _post_t: float = 0.0
var _done: bool = false
var _saw: bool = false
var _proc_us: int = 0
var _pre_us: int = 0
var _post_us: int = 0
var _tree_ms: float = -1.0
var _iso_ready: bool = false
var _iso_i: int = 0
var _iso_applied: int = -1
var _iso_t: float = 0.0
var _iso_dts: Array[float] = []
var _iso_proc: Array[float] = []
var _iso_phys: Array[float] = []
var _iso_submit: Array[float] = []
var _iso_all: Array[Node] = []
var _iso_on: Array[bool] = []
var _iso_tag: PackedStringArray = PackedStringArray()

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_wall0 = Time.get_ticks_msec()
	if not RenderingServer.frame_pre_draw.is_connected(_on_pre_draw):
		RenderingServer.frame_pre_draw.connect(_on_pre_draw)
	if not RenderingServer.frame_post_draw.is_connected(_on_post_draw):
		RenderingServer.frame_post_draw.connect(_on_post_draw)
	_vsync_off()
	_enqueue()

func _enqueue() -> void:
	if App.playtest == null:
		_finish("no_playtest")
		return
	var act_sec: float = CliArgs.float_arg("--wdb-pt-sec", 30.0)
	if Iso.active():
		act_sec = maxf(act_sec, 45.0)
	var job: Dictionary = {
		"save": "fresh",
		"weapon": "great_axe",
		"tool": "pickaxe",
		"gender": "male",
		"scale": 1.0,
		"limit": act_sec,
		"cfg": {},
	}
	App.playtest.enqueue(job)

func _on_pre_draw() -> void:
	Iso.pin_draw(self)
	var now: int = Time.get_ticks_usec()
	if _proc_us > 0:
		_tree_ms = float(now - _proc_us) / 1000.0
	_pre_us = now

func _on_post_draw() -> void:
	var now: int = Time.get_ticks_usec()
	HitchLog.set_tree_ms(_tree_ms)
	HitchLog.set_submit_ms(float(now - _pre_us) / 1000.0)
	_post_us = now

func _wall_s() -> float:
	return float(Time.get_ticks_msec() - _wall0) / 1000.0

func _process(delta: float) -> void:
	var now: int = Time.get_ticks_usec()
	if _post_us > 0:
		var after_ms: float = float(now - _post_us) / 1000.0 - HitchLog.harness_in_after_ms()
		if after_ms < 0.0:
			after_ms = 0.0
		HitchLog.set_after_ms(after_ms)
	_proc_us = now
	_post_t += delta
	if _post_t >= 0.5:
		_post_t = 0.0
		HitchLog.flush_web()
	if _done or App.playtest == null:
		if not _done:
			_finish("no_playtest")
		return
	var showing: bool = HitchLog.scoring(App)
	if showing:
		if not _saw:
			_saw = true
			HitchLog.mark("dungeon_show")
			_hb("HB: play")
		HitchLog.set_phase("play")
		_clock += delta
		HitchLog.set_play_s(_clock)
		if Iso.active() and _clock >= 2.0 and Iso.tick(self, delta):
			_finish("")
			return
	else:
		HitchLog.set_phase("wait")
		_wait_hb += delta
		if _wait_hb >= 2.0:
			_wait_hb = 0.0
			_hb("HB: wait")
	if Iso.active() and _saw:
		if not showing:
			_finish("left")
			return
		if _wall_s() >= HARD_SEC:
			_finish("timeout")
		return
	if _saw and not App.playtest.live_running:
		_finish("")
		return
	if not _saw and not App.playtest.live_running and _wall_s() >= 2.0:
		_finish("stall")
		return
	if not _saw and _wall_s() >= WAIT_SEC:
		_finish("stall")
		return
	if _wall_s() >= HARD_SEC:
		_finish("timeout")

func _finish(extra: String) -> void:
	if _done:
		return
	_done = true
	if App.playtest != null:
		App.playtest.ai_on = false
		App.playtest.move = Vector2.ZERO
		App.playtest.attack = false
	var missing: PackedStringArray = PackedStringArray()
	if extra != "":
		missing.append(extra)
	if not _saw:
		missing.append("dungeon")
	elif HitchLog.frame_n <= 0:
		missing.append("frames")
	var ok: bool = missing.is_empty()
	var miss: String = "-" if ok else ",".join(missing)
	_hb("HB: sec=%.1f hitches=%d frames=%d slow=%d pause_slow=%d fps_pct=%.1f worst=%.1f %s path=%s" % [_clock, HitchLog.hitch_n, HitchLog.frame_n, HitchLog.slow_n, HitchLog.pause_slow_n, HitchLog.fps_pct(), HitchLog.worst_ms, HitchLog.present_text(), HitchLog.file_path])
	_hb("HB: missing=%s" % miss)
	_hb("HB: ok=%d" % (1 if ok else 0))
	HitchLog.bench_done(_clock, ok, miss)
	var tree: SceneTree = get_tree()
	if tree != null:
		tree.quit(0 if ok else 1)
