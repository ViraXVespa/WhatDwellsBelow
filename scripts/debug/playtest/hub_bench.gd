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
const ST_ISO := 8
const ISO_FLAG := "--wdb-hub-isolate"

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
	var scr: GDScript = load("res://scripts/debug/playtest/hub_bench.gd") as GDScript
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
var _iso_all: Array[Node] = []
var _iso_on: Array[bool] = []
var _iso_tag: PackedStringArray = PackedStringArray()
var _iso_lits: Array[Node] = []

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
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

func _process(delta: float) -> void:
	HitchLog.set_phase(_phase_name())
	HitchLog.set_play_s(_clock)
	_post_t += delta
	if _post_t >= 0.5:
		_post_t = 0.0
		HitchLog.flush_web()
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
	elif _state == ST_ISO:
		_isolate(actor, delta)
	if not _done and _state != ST_WAIT and _state != ST_HOLD and _state != ST_ISO and _visits_done() and _faces_done() and _clock >= PLAY_SEC:
		_finish("")

func _wait(delta: float) -> void:
	var iso: bool = CliArgs.has(ISO_FLAG)
	if bool(App.get("_menu_loading")) or _actor() == null or (iso and not _hub_up()):
		_wait_t += delta
		if _wait_t >= _wait_hb and _wait_t <= 45.0:
			_wait_hb += 2.0
			_hb("HB: wait t=%.1f loading=%s actor=%s hub=%s" % [_wait_t, str(bool(App.get("_menu_loading"))), str(_actor() != null), str(_hub_up())])
		if _wait_t > 45.0:
			_finish("stall")
		return
	App.playtest.ai_on = true
	pin_zoom()
	_state = ST_ISO if iso else ST_FACE
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
	if _clock >= PLAY_SEC:
		_finish("")
		return
	# Walk out and back on each facing. A one-way shove from the last station
	# slides on the fence and the web present stays at two refreshes.
	var leg: int = int(_fill_i / 2.0) % _dirs.size()
	var dir: Vector2 = _dirs[leg]
	if _fill_i % 2 == 1:
		dir = -dir
	App.playtest.move = dir
	App.playtest.aim = dir
	_sub_t += delta
	if _sub_t < 0.8:
		return
	_sub_t = 0.0
	_fill_i += 1

func _next_visit() -> void:
	_vi += 1
	_sub_t = 0.0
	_open_tries = 0
	_pulsed = false
	_stuck_t = 0.0
	_bias_t = 0.0
	_state = ST_GOTO

func _camp() -> Node:
	var tree: SceneTree = get_tree()
	if tree == null:
		return null
	var scene: Node = tree.current_scene
	if scene != null and scene.get("_layout") != null:
		return scene
	return null

func _build_visits() -> void:
	var camp: Node = _camp()
	var lay: Node = null
	if camp != null:
		lay = camp.get("_layout") as Node
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
	var camp: Node = _camp()
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

func _hub_up() -> bool:
	var loader_v: Variant = App.get("loader")
	if loader_v is Node:
		var loader: Node = loader_v as Node
		if bool(loader.get("open")) or bool(loader.get("visible")):
			return false
	var tree: SceneTree = get_tree()
	if tree == null or tree.current_scene == null:
		return false
	var scene: Node = tree.current_scene
	if str(scene.name) == "Camp":
		return true
	return str(scene.scene_file_path).find("camp") >= 0

func _iso_kinds() -> PackedStringArray:
	return PackedStringArray([
		"warm", "base", "fence", "ground", "build", "sprites", "marks", "hud", "bare",
	])

func _iso_gather() -> void:
	_iso_all.clear()
	_iso_on.clear()
	_iso_lits.clear()
	_iso_tag = PackedStringArray()
	var tree: SceneTree = get_tree()
	if tree == null or tree.root == null:
		return
	var stack: Array[Node] = [tree.root]
	while stack.size() > 0:
		var n: Node = stack.pop_back()
		var tag: String = ""
		if n.is_in_group("hub_fence"):
			tag = "fence"
		elif n.is_in_group("hub_ground"):
			tag = "ground"
		elif n.is_in_group("hub_build"):
			tag = "build"
		elif n is Sprite3D:
			tag = "sprites"
		elif str(n.name) == "ActorLit":
			_iso_lits.append(n)
			var kids: Array = n.get_children()
			var k: int = 0
			while k < kids.size():
				var mark_child: Node = kids[k]
				if mark_child is Node3D:
					var mark: Node3D = mark_child as Node3D
					_iso_all.append(mark)
					_iso_on.append(mark.visible)
					_iso_tag.append("marks")
				k += 1
		if n is Node3D and tag != "":
			var body: Node3D = n as Node3D
			_iso_all.append(body)
			_iso_on.append(body.visible)
			_iso_tag.append(tag)
		elif n is CanvasLayer:
			var layer: CanvasLayer = n as CanvasLayer
			_iso_all.append(layer)
			_iso_on.append(layer.visible)
			_iso_tag.append("hud")
		for c in n.get_children():
			stack.append(c)

func _iso_counts() -> String:
	var fence_n: int = 0
	var ground_n: int = 0
	var build_n: int = 0
	var sprite_n: int = 0
	var mark_n: int = 0
	var hud_n: int = 0
	var i: int = 0
	while i < _iso_tag.size():
		var tag: String = _iso_tag[i]
		if tag == "fence":
			fence_n += 1
		elif tag == "ground":
			ground_n += 1
		elif tag == "build":
			build_n += 1
		elif tag == "sprites":
			sprite_n += 1
		elif tag == "marks":
			mark_n += 1
		elif tag == "hud":
			hud_n += 1
		i += 1
	return "fence=%d ground=%d build=%d sprites=%d marks=%d hud=%d" % [fence_n, ground_n, build_n, sprite_n, mark_n, hud_n]

func _iso_restore() -> void:
	var i: int = 0
	while i < _iso_all.size():
		var n: Node = _iso_all[i]
		var on: bool = _iso_on[i]
		if n is Node3D:
			(n as Node3D).visible = on
		elif n is CanvasLayer:
			(n as CanvasLayer).visible = on
		i += 1

func _iso_hide(tag: String) -> void:
	var i: int = 0
	while i < _iso_all.size():
		if tag == "bare" or _iso_tag[i] == tag:
			var n: Node = _iso_all[i]
			if n is Node3D:
				(n as Node3D).visible = false
			elif n is CanvasLayer:
				(n as CanvasLayer).visible = false
		i += 1

func _iso_apply(kind: String) -> void:
	_iso_restore()
	var pause_lits: bool = kind == "marks" or kind == "bare"
	for lit: Node in _iso_lits:
		lit.set_process(not pause_lits)
	if kind == "bare":
		_iso_hide("bare")
	elif kind != "warm" and kind != "base":
		_iso_hide(kind)

func _iso_stand(actor: Node3D) -> void:
	if _iso_spot == Vector3.ZERO:
		_iso_spot = Vector3(8.5, 0.0, 15.5)
		var camp: Node = _camp()
		if camp != null:
			var dummy_v: Variant = camp.get("dummy")
			if dummy_v is Node3D:
				_iso_spot = (dummy_v as Node3D).global_position
	if actor.global_position.distance_squared_to(_iso_spot) > 0.16:
		actor.global_position = _iso_spot
	if "velocity" in actor:
		actor.set("velocity", Vector3.ZERO)
	App.playtest.move = Vector2.ZERO
	App.playtest.aim = Vector2(-1.0, 0.0)
	App.playtest.attack = false

func _iso_mid(vals: Array[float]) -> float:
	if vals.is_empty():
		return 0.0
	var ordered: Array[float] = vals.duplicate()
	ordered.sort()
	var at: int = int(round(float(ordered.size() - 1) * 0.5))
	return ordered[at]

func _iso_report(kind: String) -> void:
	var n: int = _iso_dts.size()
	var good: int = 0
	for dt: float in _iso_dts:
		if dt <= 0.020:
			good += 1
	var pct: float = 0.0
	if n > 0:
		pct = 100.0 * float(good) / float(n)
	var draws: int = int(Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME))
	_hb("HB: isolate layer=%s n=%d p50=%.1f p95=%.1f fps=%.1f draw=%d proc=%.1f" % [
		kind, n, _iso_mid(_iso_dts) * 1000.0, _iso_p95() * 1000.0, pct, draws, _iso_mid(_iso_proc),
	])

func _iso_p95() -> float:
	if _iso_dts.is_empty():
		return 0.0
	var ordered: Array[float] = _iso_dts.duplicate()
	ordered.sort()
	var at: int = int(round(float(ordered.size() - 1) * 0.95))
	return ordered[at]

func _isolate(actor: Node3D, delta: float) -> void:
	if not _iso_ready:
		_iso_gather()
		_iso_ready = true
		_hb("HB: isolate counts %s" % _iso_counts())
	_iso_stand(actor)
	var kinds: PackedStringArray = _iso_kinds()
	if _iso_i >= kinds.size():
		_finish("isolate")
		return
	var kind: String = kinds[_iso_i]
	if _iso_applied != _iso_i:
		_iso_applied = _iso_i
		_iso_t = 0.0
		_iso_dts.clear()
		_iso_proc.clear()
	_iso_apply(kind)
	if _iso_t >= 0.35:
		_iso_dts.append(delta)
		_iso_proc.append(float(Performance.get_monitor(Performance.TIME_PROCESS)) * 1000.0)
	_iso_t += delta
	var hold: float = 1.5 if kind == "warm" else 2.5
	if _iso_t < hold:
		return
	_iso_report(kind)
	_iso_i += 1
	_iso_applied = -1
	if _iso_i >= kinds.size():
		_finish("isolate")

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
