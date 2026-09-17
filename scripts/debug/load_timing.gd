extends Object

## Title → Placeholdia: --wdb-load-timing-smoke
## Placeholdia → Dungeon: --wdb-dungeon-load-timing-smoke
## Lines: LOAD: mark=<id> t=<ms> dt=<ms>  and LOAD: key=value

const FLAG := "--wdb-load-timing-smoke"
const DUNGEON_FLAG := "--wdb-dungeon-load-timing-smoke"

static var _hub := -1
static var _dungeon := -1
static var t0 := 0
static var last := 0


static func _has_flag(flag: String) -> bool:
	var user: PackedStringArray = OS.get_cmdline_user_args()
	if user.size() > 0:
		return flag in user
	return flag in OS.get_cmdline_args()


static func hub_active() -> bool:
	if _hub < 0:
		_hub = 1 if _has_flag(FLAG) else 0
	return _hub == 1


static func dungeon_active() -> bool:
	if _dungeon < 0:
		_dungeon = 1 if _has_flag(DUNGEON_FLAG) else 0
	return _dungeon == 1


static func active() -> bool:
	return hub_active() or dungeon_active()


static func mark(id: String) -> void:
	if not hub_active():
		return
	_emit_mark(id)


static func dmark(id: String) -> void:
	if not dungeon_active():
		return
	_emit_mark(id)


static func note(key: String, val: String) -> void:
	if not hub_active():
		return
	printerr("LOAD: %s=%s" % [key, val])


static func dnote(key: String, val: String) -> void:
	if not dungeon_active():
		return
	printerr("LOAD: %s=%s" % [key, val])


static func finish() -> void:
	if not active():
		return
	var total: int = 0
	if t0 > 0:
		total = Time.get_ticks_msec() - t0
	printerr("LOAD: total_ms=%d" % total)
	printerr("LOAD: ok=true")
	if App:
		App.get_tree().create_timer(0.2).timeout.connect(func(): App.get_tree().quit())


static func _emit_mark(id: String) -> void:
	var now: int = Time.get_ticks_msec()
	if t0 == 0:
		t0 = now
		last = now
	var elapsed: int = now - t0
	var dt: int = now - last
	last = now
	printerr("LOAD: mark=%s t=%d dt=%d" % [id, elapsed, dt])
