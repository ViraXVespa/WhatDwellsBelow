extends RefCounted

## Phase smoke tests. Live scenes call attach_* / route_boot / active / hold_player.
## CLI: --wdb-phaseN-smoke  (N = 1..9)

const Early := preload("res://scripts/debug/smoke_early.gd")
const Late := preload("res://scripts/debug/smoke_late.gd")

static var enter_flag: bool = false


static func args() -> PackedStringArray:
	return OS.get_cmdline_user_args()


static func active() -> bool:
	for a: String in args():
		var s: String = str(a)
		if s.begins_with("--wdb-phase") and s.find("smoke") >= 0:
			return true
	return false


static func phase(n: int) -> bool:
	return ("--wdb-phase%d-smoke" % n) in args()


static func hold_player() -> bool:
	return phase(3) or phase(4) or phase(5) or phase(7)


static func route_boot() -> bool:
	if phase(1) or phase(2):
		App.go_foundation()
		return true
	if phase(3) or phase(4) or phase(5) or phase(7) or phase(9):
		App.begin_run()
		return true
	if phase(6) or phase(8):
		App.go_camp()
		return true
	return false


static func attach_foundation(host: Node) -> void:
	if phase(1) or phase(2):
		Early.p12(host)


static func attach_dungeon(host: Node) -> void:
	if phase(3) or phase(4):
		host.call("_stream_force_all")
	if phase(3):
		Early.p3(host)
	if phase(4):
		Early.p4(host)
	if phase(5):
		Late.p5(host)
	if phase(7):
		Late.p7(host)
	if phase(9):
		Late.p9(host)


static func attach_camp(host: Node) -> void:
	if phase(6):
		Late.p6(host)
	if phase(8):
		Late.p8(host)


static func tree(host: Node) -> SceneTree:
	return host.get_tree()


static func quit_in(host: Node, sec: float) -> void:
	tree(host).create_timer(sec).timeout.connect(func(): tree(host).quit())
