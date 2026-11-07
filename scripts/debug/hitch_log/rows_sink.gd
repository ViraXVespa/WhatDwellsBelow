extends Object

## Split from rows.gd: _write_mark, _write_gap, _write_row....

const Web := preload("res://scripts/debug/hitch_log/log_web.gd")
const Present := preload("res://scripts/debug/hitch_log/log_present.gd")

static func _write_mark(reason: String, gap_ms: int) -> void:
	var rt: Variant = load("res://scripts/debug/hitch_log/rows.gd")
	var row: Dictionary = {
		"ev": "mark",
		"why": reason,
		"dt_ms": gap_ms,
		"t": rt._t_sec(),
		"play_s": snappedf(rt._play_s, 0.1),
	}
	if rt._phase != "":
		row["phase"] = rt._phase
	_write_row(row)

static func _write_gap(delta: float, reason: String) -> void:
	var rt: Variant = load("res://scripts/debug/hitch_log/rows.gd")
	var row: Dictionary = {
		"ev": "gap",
		"why": reason,
		"dt_ms": snappedf(delta * 1000.0, 0.1),
		"t": rt._t_sec(),
		"play_s": snappedf(rt._play_s, 0.1),
	}
	if rt._phase != "":
		row["phase"] = rt._phase
	_write_row(row)

static func _write_row(row: Dictionary) -> void:
	var rt: Variant = load("res://scripts/debug/hitch_log/rows.gd")
	row["bench_gen"] = rt._bench_gen
	var line: String = JSON.stringify(row)
	# Post before the file write. A web user:// write on the stall frame held
	# the next present. The sink is what the web runner reads.
	Web._post(line)
	if OS.has_feature("web") or rt._fh == null:
		return
	rt._fh.store_line(line)
	rt._fh.flush()

static func _note_bar(host: Node, delta: float) -> void:
	var rt: Variant = load("res://scripts/debug/hitch_log/rows.gd")
	var dt_ms: float = snappedf(delta * 1000.0, 0.1)
	var row: Dictionary = rt._hitch_row(host, dt_ms)
	row["bar"] = 1
	_write_row(row)
	rt.why = ""
	rt.gx = 0
	rt.gy = 0
	rt._whys.clear()
	rt._mark_ms = 0

static func _close() -> void:
	var rt: Variant = load("res://scripts/debug/hitch_log/rows.gd")
	if rt._fh != null:
		rt._fh.flush()
		rt._fh.close()
		rt._fh = null

static func mark(reason: String, origin: Vector2i = Vector2i.ZERO) -> void:
	var rt: Variant = load("res://scripts/debug/hitch_log/rows.gd")
	var now: int = Time.get_ticks_msec()
	var frame: int = int(Engine.get_process_frames())
	var gap: int = 0
	if rt._mark_ms > 0:
		gap = now - rt._mark_ms
	var dt: int = 0
	if frame != rt._mark_frame:
		rt._whys.clear()
		rt._mark_frame = frame
	elif rt._mark_ms > 0:
		dt = gap
	rt._mark_ms = now
	rt.why = reason
	rt.gx = int(origin.x)
	rt.gy = int(origin.y)
	if rt._whys.size() >= 16:
		rt._whys.remove_at(0)
	rt._whys.append("%s:%d" % [reason, dt])
	# A bench frame can run for a long time before the next tick. Post the mark
	# now so a hung load still names the last step.
	if rt._keep_all and rt.started:
		_write_mark(reason, gap)

## The bench row (hitch_log.gd bench_done): stats, generation, then the file or the localhost sink.
static func emit_bench(row: Dictionary) -> void:
	var rt: Variant = load("res://scripts/debug/hitch_log/rows.gd")
	Present.bench_stats(row)
	row["bench_gen"] = rt._bench_gen
	if rt.started and rt._fh != null:
		_write_row(row)
	else:
		Web._post(JSON.stringify(row))
	Web._flush_web()
