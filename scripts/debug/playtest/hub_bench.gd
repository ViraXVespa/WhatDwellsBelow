extends Node

## --wdb-hub-bench: one camp walk, about 30 s, then quit.
## Eight facings with idle and walk, then crystal, anvil, vendor, guild board,
## receptionist, and one strike on the dummy. Drives App.playtest (ai_on) and
## does not start a dungeon live run. --wdb-hitch-mult=N (default 1).

const FLAG := "--wdb-hub-bench"
const CliArgs := preload("res://scripts/debug/cli_args.gd")
const HitchLog := preload("res://scripts/debug/hitch_log.gd")

const ST_WAIT := 0
const ST_FACE := 1
const ST_GOTO := 2
const ST_OPEN := 3
const ST_HOLD := 4
const ST_GAP := 5
const ST_STRIKE := 6
const ST_FILL := 7

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
	App.call_deferred("play_from_menu")

static func attach(host: Node) -> void:
	if not active() or host.get_node_or_null("HubBench") != null:
		return
	var scr: GDScript = load("res://scripts/debug/playtest/hub_bench.gd") as GDScript
	var node: Node = scr.new() as Node
	node.name = "HubBench"
	host.add_child(node)

var _state: int = ST_WAIT
var _clock: float = 0.0
var _wait_t: float = 0.0
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
var _stuck_from: Vector3 = Vector3.ZERO
var _dirs: Array[Vector2] = []
var _face_names: PackedStringArray = PackedStringArray()
var _need: PackedStringArray = PackedStringArray()
var _visits: Array[Dictionary] = []
var _faces: Dictionary = {}
var _got: Dictionary = {}

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
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

func _process(delta: float) -> void:
	HitchLog.set_phase(_phase_name())
	HitchLog.set_play_s(_clock)
	if _done or App.playtest == null:
		return
	if _state == ST_WAIT:
		_wait(delta)
		return
	_clock += delta
	var actor: Node3D = _actor()
	if actor == null:
		_finish("no_player")
		return
	_sample(actor)
	_blank()
	if _clock >= HARD_SEC and _state != ST_HOLD:
		_finish("")
		return
	if _state == ST_FACE:
		_face(delta)
	elif _state == ST_GOTO:
		_goto(actor, delta)
	elif _state == ST_OPEN:
		_open(actor, delta)
	elif _state == ST_HOLD:
		_hold(delta)
	elif _state == ST_GAP:
		_gap(delta)
	elif _state == ST_STRIKE:
		_strike(actor, delta)
	elif _state == ST_FILL:
		_fill(delta)
	if not _done and _state != ST_WAIT and _state != ST_HOLD and _visits_done() and _faces_done() and _clock >= PLAY_SEC:
		_finish("")

func _wait(delta: float) -> void:
	if bool(App.get("_menu_loading")) or _actor() == null:
		_wait_t += delta
		if _wait_t > 45.0:
			_finish("stall")
		return
	App.playtest.ai_on = true
	_saved_zoom = float(App.cam_zoom)
	App.set_zoom(1.0)
	_state = ST_FACE
	_sub_t = 0.0
	_hb("HB: begin mult=%.2f zoom=1.0 was=%.2f %s" % [HitchLog.mult(), _saved_zoom, HitchLog.present_text()])

func _face(delta: float) -> void:
	var dir: Vector2 = _dirs[_face_i]
	App.playtest.aim = dir
	_sub_t += delta
	if not _face_idle:
		App.playtest.move = dir
		var key: String = _face_names[_face_i]
		var seen: bool = bool(_faces.get(key, false))
		if (seen and _sub_t > 0.45) or _sub_t > 1.6:
			_face_idle = true
			_sub_t = 0.0
			_hb("HB: face=%s loop=%d" % [key, 1 if seen else 0])
		return
	if _sub_t < 0.05:
		return
	_face_i += 1
	_face_idle = false
	_sub_t = 0.0
	_stuck_t = 0.0
	if _face_i >= _dirs.size():
		_build_visits()
		if _done:
			return
		_state = ST_GOTO
		_vi = 0
		_open_tries = 0

func _goto(actor: Node3D, delta: float) -> void:
	if _vi >= _visits.size():
		_state = ST_FILL
		_sub_t = 0.0
		_fill_i = 0
		return
	var row: Dictionary = _visits[_vi]
	var at: Vector3 = row["at"] as Vector3
	var look: Vector3 = row["look"] as Vector3
	_steer(actor, at, look, delta)
	_sub_t += delta
	var nd: float = _xz(actor.global_position, look)
	var strike: bool = bool(row["strike"])
	var close: bool = nd <= 1.15 or (nd <= 1.45 and _sub_t > 3.0)
	if not close and _sub_t <= 12.0:
		return
	if strike:
		if nd > 2.2:
			_hb("HB: miss=%s" % str(row["id"]))
			_next_visit()
			return
		_state = ST_STRIKE
		_sub_t = 0.0
		return
	if nd > 1.45:
		_hb("HB: miss=%s" % str(row["id"]))
		_next_visit()
		return
	_state = ST_OPEN
	_pulsed = false
	_sub_t = 0.0

func _open(actor: Node3D, delta: float) -> void:
	var row: Dictionary = _visits[_vi]
	var look: Vector3 = row["look"] as Vector3
	var id: String = str(row["id"])
	_aim_at(actor, look)
	if not _pulsed:
		App.playtest.just = {"interact": true}
		_pulsed = true
		return
	# This delta is the interact frame. A paused menu would hide it from App's tick.
	HitchLog.note_span(self, "ui_span_" + id, delta)
	_pulsed = false
	if App.ui_open:
		HitchLog.skip_gap()
		_got[id] = true
		_hb("HB: open=%s" % id)
		_state = ST_HOLD
		_sub_t = 0.0
		return
	_open_tries += 1
	if _open_tries >= 3:
		_hb("HB: miss=%s" % id)
		_next_visit()
		return
	_state = ST_GOTO

func _hold(delta: float) -> void:
	_sub_t += delta
	if _sub_t < 0.55:
		return
	var t0: int = Time.get_ticks_usec()
	_close_ui()
	var sec: float = float(Time.get_ticks_usec() - t0) / 1000000.0
	HitchLog.note_span(self, "ui_close_span", sec)
	_state = ST_GAP
	_sub_t = 0.0

func _gap(delta: float) -> void:
	_sub_t += delta
	if _sub_t < 0.2:
		return
	_next_visit()

func _strike(actor: Node3D, delta: float) -> void:
	var row: Dictionary = _visits[_vi]
	var look: Vector3 = row["look"] as Vector3
	_aim_at(actor, look)
	App.playtest.attack = true
	_sub_t += delta
	if int(actor.get("atk_state")) != 0:
		_got["dummy"] = true
	if _sub_t < 0.8:
		return
	if bool(_got.get("dummy", false)):
		_hb("HB: strike=dummy")
	else:
		_hb("HB: miss=dummy")
	_next_visit()

func _fill(delta: float) -> void:
	if _clock >= PLAY_SEC or _fill_i >= 2:
		_finish("")
		return
	var dir: Vector2 = _dirs[_fill_i * 2]
	App.playtest.move = dir
	App.playtest.aim = dir
	_sub_t += delta
	if _sub_t < 1.0:
		return
	_sub_t = 0.0
	_fill_i = (_fill_i + 1) % 4

func _next_visit() -> void:
	_vi += 1
	_sub_t = 0.0
	_open_tries = 0
	_pulsed = false
	_stuck_t = 0.0
	_bias_t = 0.0
	_state = ST_GOTO

func _build_visits() -> void:
	var lay: Node = get_parent().get("_layout") as Node
	if lay == null:
		_finish("no_layout")
		return
	_add_visit(lay, "loadout_crystal", "Crystal", false)
	_add_visit(lay, "anvil", "Anvil", false)
	_add_visit(lay, "vendor", "Vendor", false)
	_add_visit(lay, "quest_board", "Board", false)
	var rec: Vector3 = _call_vec(lay, "reception_pos", "")
	_push_visit("receptionist", rec, false)
	_add_visit(lay, "dummy", "Dummy", true)

func _add_visit(lay: Node, id: String, spot: String, strike: bool) -> void:
	_push_visit(id, _call_vec(lay, "spot_pos", spot), strike)

func _push_visit(id: String, look: Vector3, strike: bool) -> void:
	var at: Vector3 = look
	if strike:
		at += Vector3(1.05, 0.0, 0.0)
	else:
		at += Vector3(0.0, 0.0, 0.8)
	_visits.append({"id": id, "at": at, "look": look, "strike": strike})

func _call_vec(lay: Node, method: String, arg: String) -> Vector3:
	var v: Variant = lay.call(method) if arg == "" else lay.call(method, arg)
	if v is Vector3:
		return v as Vector3
	return Vector3.ZERO

func _steer(actor: Node3D, at: Vector3, look: Vector3, delta: float) -> void:
	var flat: Vector2 = Vector2(at.x - actor.global_position.x, at.z - actor.global_position.z)
	var dist: float = flat.length()
	var dir: Vector2 = Vector2.ZERO
	if dist > 0.12:
		dir = flat / dist
	if actor.global_position.distance_to(_stuck_from) < 0.04:
		_stuck_t += delta
	else:
		_stuck_t = 0.0
		_stuck_from = actor.global_position
	if _stuck_t > 0.7:
		_bias_t = 0.45
		_stuck_t = 0.0
	if _bias_t > 0.0 and dir.length() > 0.1:
		_bias_t -= delta
		dir = Vector2(-dir.y, dir.x)
	App.playtest.move = dir if dist > 0.45 else Vector2.ZERO
	_aim_at(actor, look)

func _aim_at(actor: Node3D, look: Vector3) -> void:
	var d: Vector2 = Vector2(look.x - actor.global_position.x, look.z - actor.global_position.z)
	if d.length() > 0.05:
		App.playtest.aim = d.normalized()

func _xz(at: Vector3, look: Vector3) -> float:
	return Vector2(look.x - at.x, look.z - at.z).length()

func _actor() -> Node3D:
	var n: Node = get_tree().get_first_node_in_group("player") if get_tree() != null else null
	if n is Node3D:
		return n as Node3D
	return null

func _sample(actor: Node3D) -> void:
	var loco: int = int(actor.get("loc_state"))
	var moving: bool = loco == 1 or loco == 2
	if moving and not _was_moving:
		_to_walk = true
	if (not moving) and _was_moving:
		_to_idle = true
	_was_moving = moving
	if loco == 2:
		_faces[str(actor.get("facing_key"))] = true

func _blank() -> void:
	App.playtest.move = Vector2.ZERO
	App.playtest.just = {}
	App.playtest.attack = false
	App.playtest.special = false

func _close_ui() -> void:
	var camp: Node = get_parent()
	var ui_v: Variant = camp.get("ui") if camp != null else null
	if ui_v is Node and (ui_v as Node).has_method("close_ui") and bool((ui_v as Node).get("open")):
		(ui_v as Node).call("close_ui")
	App.ui_open = false
	var tree: SceneTree = get_tree()
	if tree != null:
		tree.paused = false

func _visits_done() -> bool:
	return _state == ST_FILL or (_visits.size() > 0 and _vi >= _visits.size())

func _faces_done() -> bool:
	if not _to_walk or not _to_idle:
		return false
	for face_name: String in _face_names:
		if not bool(_faces.get(face_name, false)):
			return false
	for need: String in _need:
		if not bool(_got.get(need, false)):
			return false
	return true

func _finish(extra: String) -> void:
	if _done:
		return
	_done = true
	if App.playtest != null:
		App.playtest.ai_on = false
		App.playtest.move = Vector2.ZERO
		App.playtest.attack = false
	if _saved_zoom >= 0.0:
		App.set_zoom(_saved_zoom)
	var missing: PackedStringArray = PackedStringArray()
	if extra != "":
		missing.append(extra)
	if not _to_walk:
		missing.append("idle_to_walk")
	if not _to_idle:
		missing.append("walk_to_idle")
	for face_name: String in _face_names:
		if not bool(_faces.get(face_name, false)):
			missing.append("face_" + face_name)
	for need: String in _need:
		if not bool(_got.get(need, false)):
			missing.append(need)
	var ok: bool = missing.is_empty()
	var miss: String = "-" if ok else ",".join(missing)
	_hb("HB: sec=%.1f hitches=%d frames=%d slow=%d pause_slow=%d fps_pct=%.1f worst=%.1f %s path=%s" % [_clock, HitchLog.hitch_n, HitchLog.frame_n, HitchLog.slow_n, HitchLog.pause_slow_n, HitchLog.fps_pct(), HitchLog.worst_ms, HitchLog.present_text(), HitchLog.file_path])
	_hb("HB: missing=%s" % miss)
	_hb("HB: ok=%d" % (1 if ok else 0))
	HitchLog.bench_done(_clock, ok, miss)
	var tree: SceneTree = get_tree()
	if tree != null:
		tree.quit(0 if ok else 1)
