extends Object

## Split from hub_bench.gd: _wait, _face, _goto....

const CliArgs := preload("res://scripts/debug/cli_args.gd")
const HitchLog := preload("res://scripts/debug/hitch_log.gd")
const End := preload("res://scripts/debug/playtest_bench/hub_bench_end.gd")
const Visit := preload("res://scripts/debug/playtest_bench/hub_bench_visit.gd")

static func _wait(host: Node, delta: float) -> void:
	var iso: bool = CliArgs.has(host.ISO_FLAG)
	if bool(App.get("_menu_loading")) or host._actor() == null or (iso and not End._hub_up(host)):
		host._wait_t += delta
		if host._wait_t >= host._wait_hb and host._wait_t <= 45.0:
			host._wait_hb += 2.0
			host._hb("HB: wait t=%.1f loading=%s actor=%s hub=%s" % [host._wait_t, str(bool(App.get("_menu_loading"))), str(host._actor() != null), str(End._hub_up(host))])
		if host._wait_t > 45.0:
			End._finish(host, "stall")
		return
	App.playtest.ai_on = true
	host.pin_zoom()
	host._state = host.ST_ISO if iso else host.ST_FACE
	host._sub_t = 0.0
	host._hb("HB: begin mult=%.2f zoom=1.0 was=%.2f %s" % [HitchLog.mult(), host._saved_zoom, HitchLog.present_text()])

static func _face(host: Node, delta: float) -> void:
	var dir: Vector2 = host._dirs[host._face_i]
	App.playtest.aim = dir
	host._sub_t += delta
	if not host._face_idle:
		App.playtest.move = dir
		var key: String = host._face_names[host._face_i]
		var seen: bool = bool(host._faces.get(key, false))
		if (seen and host._sub_t > 0.45) or host._sub_t > 1.6:
			host._face_idle = true
			host._sub_t = 0.0
			host._hb("HB: face=%s loop=%d" % [key, 1 if seen else 0])
		return
	if host._sub_t < 0.05:
		return
	host._face_i += 1
	host._face_idle = false
	host._sub_t = 0.0
	host._stuck_t = 0.0
	if host._face_i >= host._dirs.size():
		Visit._build_visits(host)
		if host._done:
			return
		host._state = host.ST_GOTO
		host._vi = 0
		host._open_tries = 0

static func _goto(host: Node, actor: Node3D, delta: float) -> void:
	if host._vi >= host._visits.size():
		host._state = host.ST_FILL
		host._sub_t = 0.0
		host._fill_i = 0
		return
	var row: Dictionary = host._visits[host._vi]
	var at: Vector3 = row["at"] as Vector3
	var look: Vector3 = row["look"] as Vector3
	Visit._steer(host, actor, at, look, delta)
	host._sub_t += delta
	var nd: float = Visit._xz(actor.global_position, look)
	var strike: bool = bool(row["strike"])
	var close: bool = nd <= 1.15 or (nd <= 1.45 and host._sub_t > 3.0)
	if not close and host._sub_t <= 12.0:
		return
	if strike:
		if nd > 2.2:
			host._hb("HB: miss=%s" % str(row["id"]))
			_next_visit(host)
			return
		host._state = host.ST_STRIKE
		host._sub_t = 0.0
		return
	if nd > 1.45:
		host._hb("HB: miss=%s" % str(row["id"]))
		_next_visit(host)
		return
	host._state = host.ST_OPEN
	host._pulsed = false
	host._sub_t = 0.0

static func _open(host: Node, actor: Node3D, delta: float) -> void:
	var row: Dictionary = host._visits[host._vi]
	var look: Vector3 = row["look"] as Vector3
	var id: String = str(row["id"])
	Visit._aim_at(actor, look)
	if not host._pulsed:
		App.playtest.just = {"interact": true}
		host._pulsed = true
		return
	# This delta is the interact frame. A paused menu would hide it from App's tick.
	HitchLog.note_span(host, "ui_span_" + id, delta)
	host._pulsed = false
	if App.ui_open:
		HitchLog.skip_gap()
		host._got[id] = true
		host._hb("HB: open=%s" % id)
		host._state = host.ST_HOLD
		host._sub_t = 0.0
		return
	host._open_tries += 1
	if host._open_tries >= 3:
		host._hb("HB: miss=%s" % id)
		_next_visit(host)
		return
	host._state = host.ST_GOTO

static func _hold(host: Node, delta: float) -> void:
	host._sub_t += delta
	if host._sub_t < 0.55:
		return
	var t0: int = Time.get_ticks_usec()
	Visit._close_ui(host)
	var sec: float = float(Time.get_ticks_usec() - t0) / 1000000.0
	HitchLog.note_span(host, "ui_close_span", sec)
	host._state = host.ST_GAP
	host._sub_t = 0.0

static func _gap(host: Node, delta: float) -> void:
	host._sub_t += delta
	if host._sub_t < 0.2:
		return
	_next_visit(host)

static func _strike(host: Node, actor: Node3D, delta: float) -> void:
	var row: Dictionary = host._visits[host._vi]
	var look: Vector3 = row["look"] as Vector3
	Visit._aim_at(actor, look)
	App.playtest.attack = true
	host._sub_t += delta
	if int(actor.get("atk_state")) != 0:
		host._got["dummy"] = true
	if host._sub_t < 0.8:
		return
	if bool(host._got.get("dummy", false)):
		host._hb("HB: strike=dummy")
	else:
		host._hb("HB: miss=dummy")
	_next_visit(host)

static func _fill(host: Node, delta: float) -> void:
	if host._clock >= host.PLAY_SEC:
		End._finish(host, "")
		return
	# Walk out and back on each facing. A one-way shove from the last station
	# slides on the fence and the web present stays at two refreshes.
	var leg: int = int(host._fill_i / 2.0) % host._dirs.size()
	var dir: Vector2 = host._dirs[leg]
	if host._fill_i % 2 == 1:
		dir = -dir
	App.playtest.move = dir
	App.playtest.aim = dir
	host._sub_t += delta
	if host._sub_t < 0.8:
		return
	host._sub_t = 0.0
	host._fill_i += 1

static func _next_visit(host: Node) -> void:
	host._vi += 1
	host._sub_t = 0.0
	host._open_tries = 0
	host._pulsed = false
	host._stuck_t = 0.0
	host._bias_t = 0.0
	host._state = host.ST_GOTO
