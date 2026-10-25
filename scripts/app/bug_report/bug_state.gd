extends Object

## The game's own state report for Report Bug: only the relay's STATE_KEYS (tools/relay/src/report.js), no logs,
## no names, paths or other user data. Version is the label plus the week-open commit from version.json.

const GameVer := preload("res://scripts/data/game_ver.gd")
const LocS := preload("res://scripts/app/app_loc.gd")
const KEYS: Array = ["version", "platform", "build", "scene", "floor", "seed", "pos", "loadout", "recent", "perf",
	"settings", "run", "uptime_s"]

static func build() -> Dictionary:
	var tree: SceneTree = App.get_tree()
	var scn: Node = tree.current_scene if tree else null
	var pl: Node3D = tree.get_first_node_in_group("player") as Node3D if tree else null
	var prog: Object = App.prog
	return {
		"version": version(),
		"platform": platform(),
		"build": build_kind(),
		"scene": str(scn.scene_file_path).get_file() if scn else "",
		"floor": App.floor_n if App.in_dungeon else 0,
		"seed": App.run_seed if App.in_dungeon else 0,
		"pos": [snappedf(pl.global_position.x, 0.1), snappedf(pl.global_position.y, 0.1), snappedf(pl.global_position.z, 0.1)] if pl else [],
		"loadout": loadout(prog),
		"recent": {"toast": str(App.toast_msg).left(120), "where": where()},
		"perf": {"fps": Engine.get_frames_per_second(), "renderer": RenderingServer.get_current_rendering_method(),
			"gpu": RenderingServer.get_video_adapter_name(), "window": str(DisplayServer.window_get_size()),
			"render_scale": App.render_scale},
		"settings": {"zoom": App.cam_zoom, "hud_scale": App.hud_scale, "sprite_filter": App.sprite_filter,
			"display": App.display_mode, "locale": LocS.current, "target_lock": App.target_lock_pref},
		"run": {"in_dungeon": App.in_dungeon, "boss_dead": App.boss_dead, "deepest": int(prog.get("deepest")) if prog else 0,
			"kills": int(App.tel.kills) if App.tel else 0},
		"uptime_s": int(Time.get_ticks_msec() / 1000.0),
	}

static func version() -> String:
	var txt: String = FileAccess.get_file_as_string(GameVer.VERSION_PATH)
	var d: Variant = JSON.parse_string(txt) if txt != "" else null
	var commit: String = str((d as Dictionary).get("open_commit", "")).left(8) if d is Dictionary else ""
	return GameVer.label() + (" @" + commit if commit != "" else "")

static func platform() -> String:
	if OS.has_feature("web"):
		return "web"
	match OS.get_name():
		"Windows":
			return "windows"
		"macOS":
			return "macos"
		"Android":
			return "android"
		"iOS":
			return "ios"
	return "linux"

static func build_kind() -> String:
	if OS.has_feature("editor"):
		return "dev"
	return "debug" if OS.is_debug_build() else "release"

## Door context of where the player is (routes.yaml door keys).
static func where() -> String:
	if App.in_dungeon:
		return "dungeon"
	var tree: SceneTree = App.get_tree()
	var path: String = str(tree.current_scene.scene_file_path) if tree and tree.current_scene else ""
	if path.find("title") >= 0:
		return "ui.title_web"
	return "hub" if path.find("camp") >= 0 else "triage"

static func loadout(prog: Object) -> Dictionary:
	var out := {"weapon": App.weapon}
	if prog == null:
		return out
	out["tool"] = str(prog.get("tool_type"))
	var slots: Variant = prog.get("slots")
	if slots is Dictionary:
		for k: Variant in slots:
			var it: Variant = slots[k]
			if it is Dictionary and not (it as Dictionary).is_empty():
				out[str(k)] = str((it as Dictionary).get("rarity", "")) + " " + str((it as Dictionary).get("id", (it as Dictionary).get("slot", "")))
	return out
