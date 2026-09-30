extends RefCounted

## Phase smoke tests. Live scenes call attach_* / route_boot / active / hold_player.
## CLI: --wdb-phaseN-smoke  (N = 1..9)
## Load timing: --wdb-load-timing-smoke (Title → Placeholdia; not a numbered phase)
## Dungeon load timing: --wdb-dungeon-load-timing-smoke (Placeholdia → Dungeon; not a numbered phase)
## Dungeon map: --wdb-dungeon-map-smoke (floor dump; not a numbered phase)
## Postcard shot: --wdb-shot (play-camera PNG; not a numbered phase)

const Early := preload("res://scripts/debug/smoke_early.gd")
const Late := preload("res://scripts/debug/smoke_late.gd")
const LoadTiming := preload("res://scripts/debug/load_timing.gd")
const DungeonMap := preload("res://scripts/debug/dungeon_map.gd")
const ShotTool := preload("res://scripts/debug/shot_tool.gd")

static var enter_flag: bool = false


static func args() -> PackedStringArray:
	# Prefer user args (after --). Fall back to full cmdline so Steam/redirected
	# launches still see --wdb-phaseN-smoke when user-args arrive empty.
	var user: PackedStringArray = OS.get_cmdline_user_args()
	if user.size() > 0:
		return user
	return OS.get_cmdline_args()


static func active() -> bool:
	for a: String in args():
		var s: String = str(a)
		if s.begins_with("--wdb-phase") and s.find("smoke") >= 0:
			return true
		if s == LoadTiming.FLAG:
			return true
		if s == LoadTiming.DUNGEON_FLAG:
			return true
		if s == DungeonMap.FLAG:
			return true
		if s == ShotTool.FLAG:
			return true
	return false


static func phase(n: int) -> bool:
	return ("--wdb-phase%d-smoke" % n) in args()


static func hold_player() -> bool:
	return phase(3) or phase(4) or phase(5) or phase(7)


static func route_boot() -> bool:
	if "--wdb-bake-camp" in args():
		App.call_deferred("_bake_camp")
		return true
	if LoadTiming.hub_active():
		App.character_type = "male"
		App.character_chosen = true
		App.call_deferred("play_from_menu")
		return true
	if LoadTiming.dungeon_active():
		App.character_type = "male"
		App.character_chosen = true
		App.call_deferred("_dungeon_load_timing_async")
		return true
	if DungeonMap.active():
		App.character_type = "male"
		App.character_chosen = true
		App.begin_run()
		App.floor_n = DungeonMap.floor_n()
		App.run_seed = DungeonMap.run_seed()
		return true
	if ShotTool.active():
		App.character_type = "male"
		App.character_chosen = true
		ShotTool.hide_window()
		if ShotTool.scene_name() == "camp":
			App.go_camp()
		else:
			App.begin_run()
			App.floor_n = ShotTool.floor_n()
			App.run_seed = ShotTool.run_seed()
		return true
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
	if DungeonMap.active():
		DungeonMap.dump_floor(host)
		return
	if ShotTool.active():
		host.call("_stream_force_all")
		ShotTool.attach_dungeon(host)
		return
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
	if ShotTool.active():
		ShotTool.attach_dungeon(host)
	if phase(6):
		Late.p6(host)
	if phase(8):
		Late.p8(host)


static func tree(host: Node) -> SceneTree:
	return host.get_tree()


static func quit_in(host: Node, sec: float) -> void:
	tree(host).create_timer(sec).timeout.connect(func(): tree(host).quit())
