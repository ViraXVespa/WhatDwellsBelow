extends Object

## Split from hitch_log.gd: tick, _note, _note_paused....

const Ctx := preload("res://scripts/debug/hitch_log/ctx.gd")
const Present := preload("res://scripts/debug/hitch_log/log_present.gd")
const Rows := preload("res://scripts/debug/hitch_log/rows.gd")
const Run := preload("res://scripts/debug/hitch_log/log_run.gd")
const LogFile := preload("res://scripts/debug/hitch_log/log_file.gd")

const CAP := 256

static func tick(host: Node, delta: float) -> void:
	var rt: Variant = load("res://scripts/debug/hitch_log.gd")
	if not rt.enabled():
		return
	Rows.stamp_edge(Time.get_ticks_usec())
	if not Rows.started:
		rt.begin(host)
	if not Rows.started:
		return
	if Engine.time_scale != 1.0:
		return
	# Harness credit is the previous iteration's playtest tick. Rotate on every
	# real-time tick so a paused or loader frame does not apply it one frame late.
	var scored: float = delta
	if Rows.harness_on():
		scored = delta - Rows.rotate_harness()
		if scored < 0.0:
			scored = 0.0
	Rows._sample_proc()
	if rt._skip_gap:
		rt._skip_gap = false
		Run._break_run()
		Rows._write_gap(scored, "skip_gap")
		return
	var tree: SceneTree = host.get_tree()
	if tree != null and tree.paused:
		Run._break_run()
		if Present._over_budget(scored):
			rt.pause_slow_n += 1
			_note_paused(host, scored)
		return
	# The 99% bar is the whole time the scored scene is on screen (hub camp, or
	# the dungeon when the dungeon bench set that). Loader-up frames are not it.
	if not Ctx._score_on_screen(host):
		Run._break_run()
		if Present._over_budget(scored):
			rt.bar_slow_n += 1
			Rows._note_bar(host, scored)
		return
	# The sweep's hidden-group window is on screen and must stay out of fps_pct.
	if Rows.unscored():
		Run._break_run()
		return
	rt.frame_n += 1
	var dt_ms: float = snappedf(scored * 1000.0, 0.1)
	if Rows._keep_all:
		Present._dts.append(dt_ms)
		if Rows.harness_on():
			Present._pts.append(Rows.pt_ms())
	var slow: bool = Present._over_budget(scored)
	Run._track_run(dt_ms, slow)
	if not slow:
		return
	rt.slow_n += 1
	_note(host, scored)

static func _note(host: Node, delta: float) -> void:
	var rt: Variant = load("res://scripts/debug/hitch_log.gd")
	var dt_ms: float = snappedf(delta * 1000.0, 0.1)
	var fresh: bool = dt_ms > rt.worst_ms
	if fresh:
		rt.worst_ms = dt_ms
	rt.hitch_n += 1
	# The counters above are the 99% bar. Building the row on every miss costs
	# another present on web, so a single stall becomes the rest of the walk.
	var now: int = Time.get_ticks_msec()
	if not fresh and now - rt._emit_at < 100:
		return
	rt._emit_at = now
	Rows._write_row(Rows._hitch_row(host, dt_ms))
	Rows.why = ""
	Rows.gx = 0
	Rows.gy = 0
	Rows._whys.clear()
	Rows._mark_ms = 0
	if rt.hitch_n > CAP and not Rows._keep_all:
		Rows._close()
		LogFile._trim_file()
		Rows._fh = FileAccess.open(rt.file_path, FileAccess.READ_WRITE)
		if Rows._fh == null:
			Rows._fh = FileAccess.open(rt.file_path, FileAccess.WRITE_READ)
		if Rows._fh != null:
			Rows._fh.seek_end()
		rt.hitch_n = LogFile._count_hitches()

static func _note_paused(host: Node, delta: float) -> void:
	var rt: Variant = load("res://scripts/debug/hitch_log.gd")
	var dt_ms: float = snappedf(delta * 1000.0, 0.1)
	var row: Dictionary = Rows._hitch_row(host, dt_ms)
	row["paused"] = 1
	rt.hitch_n += 1
	Rows._write_row(row)
	Rows.why = ""
	Rows.gx = 0
	Rows.gy = 0
	Rows._whys.clear()
	Rows._mark_ms = 0
