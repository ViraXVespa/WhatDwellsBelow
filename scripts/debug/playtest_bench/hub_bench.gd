extends Node

## --wdb-hub-bench: one camp walk, about 30 s, then quit.
## Eight facings with idle and walk, then crystal, anvil, vendor, guild board,
## receptionist, and one strike on the dummy. Drives App.playtest (ai_on) and
## does not start a dungeon live run. --wdb-hitch-mult=N (default 1).

const FLAG := "--wdb-hub-bench"
const CliArgs := preload("res://scripts/app/cli_args.gd")
const HitchLog := preload("res://scripts/debug/hitch_log.gd")

const Iso := preload("res://scripts/debug/playtest_bench/hub_bench_iso.gd")
const End := preload("res://scripts/debug/playtest_bench/hub_bench_end.gd")
const Step := preload("res://scripts/debug/playtest_bench/hub_bench_step.gd")
const ST_WAIT := 0
const ST_FACE := 1
const ST_GOTO := 2
const ST_OPEN := 3
const ST_HOLD := 4
const ST_GAP := 5
const ST_STRIKE := 6
const ST_FILL := 7
const ST_ISO := 8
const ISO_FLAG := "--wdb-hub-isolate"
const WALK_FLAG := "--wdb-hub-walk-layers"
const ABA_FLAG := "--wdb-hub-fill-aba"

const PLAY_SEC := 30.0
const HARD_SEC := 45.0
## Above the 60 FPS bar, and finite. VSYNC_DISABLED with max_fps 0 can peg the GPU.
const FPS_CAP := 120

static func active() -> bool:
	return CliArgs.has(FLAG)

static func _vsync_off() -> void:
	# Compatibility honors VSYNC_DISABLED (swap interval 0). Web ignores it.
	# The cap only pads frames faster than 120; a frame over 16.7 ms stays slow.
	# Borderless fullscreen so the framebuffer is the screen, not a smaller window.
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	Engine.max_fps = FPS_CAP
	if not OS.has_feature("web"):
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)

static func _warm_user() -> bool:
	return FileAccess.file_exists("user://live/save.json")

static func _hb(msg: String) -> void:
	printerr(msg)
	HitchLog.hb(msg)

func pin_zoom() -> void:
	if _saved_zoom < 0.0:
		_saved_zoom = float(App.cam_zoom)
	App.set_zoom(1.0)

func _phase_name() -> String:
	if _state == ST_FACE:
		return "face"
	if _state == ST_GOTO:
		return "goto"
	if _state == ST_OPEN:
		return "open"
	if _state == ST_HOLD:
		return "hold"
	if _state == ST_GAP:
		return "gap"
	if _state == ST_STRIKE:
		return "strike"
	if _state == ST_FILL:
		return "fill"
	if _state == ST_ISO:
		return "iso"
	return "wait"

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
	HitchLog.set_phase("wait")
	_hb("HB: fresh=1")
	App.character_type = "male"
	App.character_chosen = true
	attach(App)
	App.call_deferred("play_from_menu")

static func attach(_host: Node) -> void:
	if not active() or App.get_node_or_null("HubBench") != null:
		return
	var scr: GDScript = load("res://scripts/debug/playtest_bench/hub_bench.gd") as GDScript
	var node: Node = scr.new() as Node
	node.name = "HubBench"
	App.add_child(node)

var _state: int = ST_WAIT
var _clock: float = 0.0
var _wait_t: float = 0.0
var _wait_hb: float = 2.0
var _sub_t: float = 0.0
var _face_i: int = 0
var _face_idle: bool = false
var _vi: int = 0
var _fill_i: int = 0
var _open_tries: int = 0
var _pulsed: bool = false
var _done: bool = false
var _saved_zoom: float = -1.0
var _to_walk: bool = false
var _to_idle: bool = false
var _was_moving: bool = false
var _stuck_t: float = 0.0
var _bias_t: float = 0.0
var _post_t: float = 0.0
var _stuck_from: Vector3 = Vector3.ZERO
var _dirs: Array[Vector2] = []
var _face_names: PackedStringArray = PackedStringArray()
var _need: PackedStringArray = PackedStringArray()
var _visits: Array[Dictionary] = []
var _faces: Dictionary = {}
var _got: Dictionary = {}
var _iso_ready: bool = false
var _iso_i: int = 0
var _iso_applied: int = -1
var _iso_t: float = 0.0
var _iso_spot: Vector3 = Vector3.ZERO
var _iso_dts: Array[float] = []
var _iso_proc: Array[float] = []
var _iso_phys: Array[float] = []
var _iso_submit: Array[float] = []
var _iso_all: Array[Node] = []
var _iso_on: Array[bool] = []
var _iso_tag: PackedStringArray = PackedStringArray()
var _iso_lits: Array[Node] = []

var _pre_us: int = 0
var _proc_us: int = 0
var _post_us: int = 0
var _tree_ms: float = -1.0

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	if not RenderingServer.frame_pre_draw.is_connected(_on_pre_draw):
		RenderingServer.frame_pre_draw.connect(_on_pre_draw)
	if not RenderingServer.frame_post_draw.is_connected(_on_post_draw):
		RenderingServer.frame_post_draw.connect(_on_post_draw)
	if CliArgs.has(ISO_FLAG):
		process_priority = 100
	_vsync_off()
	_dirs = [
		Vector2(1, 0),
		Vector2(0.70710678, 0.70710678),
		Vector2(0, 1),
		Vector2(-0.70710678, 0.70710678),
		Vector2(-1, 0),
		Vector2(-0.70710678, -0.70710678),
		Vector2(0, -1),
		Vector2(0.70710678, -0.70710678),
	]
	_face_names = PackedStringArray([
		"right", "down_right", "down", "down_left",
		"left", "up_left", "up", "up_right",
	])
	_need = PackedStringArray([
		"loadout_crystal", "anvil", "vendor", "quest_board", "receptionist", "dummy",
	])

func _on_pre_draw() -> void:
	var now: int = Time.get_ticks_usec()
	if _proc_us > 0:
		_tree_ms = float(now - _proc_us) / 1000.0
	_pre_us = now

func _on_post_draw() -> void:
	var now: int = Time.get_ticks_usec()
	HitchLog.set_tree_ms(_tree_ms)
	HitchLog.set_submit_ms(float(now - _pre_us) / 1000.0)
	_post_us = now

func _process(delta: float) -> void:
	var now: int = Time.get_ticks_usec()
	if _post_us > 0:
		HitchLog.set_after_ms(float(now - _post_us) / 1000.0)
	_proc_us = now
	HitchLog.set_phase(_phase_name())
	HitchLog.set_play_s(_clock)
	_post_t += delta
	if _post_t >= 0.5:
		_post_t = 0.0
		HitchLog.flush_web()
	if _done or App.playtest == null:
		return
	if _state == ST_WAIT:
		Step._wait(self, delta)
		return
	_clock += delta
	var actor: Node3D = _actor()
	if actor == null:
		End._finish(self, "no_player")
		return
	End._sample(self, actor)
	_blank()
	var cap: float = 90.0 if CliArgs.has(WALK_FLAG) else HARD_SEC
	if _clock >= cap and _state != ST_HOLD:
		End._finish(self, "")
		return
	if _state == ST_FACE:
		Step._face(self, delta)
	elif _state == ST_GOTO:
		Step._goto(self, actor, delta)
	elif _state == ST_OPEN:
		Step._open(self, actor, delta)
	elif _state == ST_HOLD:
		Step._hold(self, delta)
	elif _state == ST_GAP:
		Step._gap(self, delta)
	elif _state == ST_STRIKE:
		Step._strike(self, actor, delta)
	elif _state == ST_FILL:
		if CliArgs.has(ABA_FLAG):
			Iso._fill_aba(self, delta)
		elif CliArgs.has(WALK_FLAG):
			Iso._fill_layers(self, delta)
		else:
			Step._fill(self, delta)
	elif _state == ST_ISO:
		Iso._isolate(self, actor, delta)
	if not _done and _state != ST_WAIT and _state != ST_HOLD and _state != ST_ISO and not CliArgs.has(WALK_FLAG) and _visits_done() and End._faces_done(self) and _clock >= PLAY_SEC:
		End._finish(self, "")

func _actor() -> Node3D:
	var n: Node = get_tree().get_first_node_in_group("player") if get_tree() != null else null
	if n is Node3D:
		return n as Node3D
	return null

func _blank() -> void:
	App.playtest.move = Vector2.ZERO
	App.playtest.just = {}
	App.playtest.attack = false
	App.playtest.special = false

func _visits_done() -> bool:
	return _state == ST_FILL or (_visits.size() > 0 and _vi >= _visits.size())
