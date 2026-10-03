extends Object

## --wdb-playtest-live-smoke: boots straight into one live AI run on floor 1, prints `PT:` lines, quits.
## Args (after --): --wdb-seed=N (run seed), --wdb-pt-weapon=great_axe|staff|longbow, --wdb-pt-sec=S (sim seconds), --wdb-pt-scale=X (time scale while acting; only with --wdb-pt-fast, else 1.0).
## Debug only: run `godot --headless --path . -- --wdb-playtest-live-smoke --wdb-seed=42`.

const CliArgs := preload("res://scripts/debug/cli_args.gd")
const FLAG := "--wdb-playtest-live-smoke"

static func active() -> bool:
	return CliArgs.has(FLAG)

static func _str(key: String, fallback: String) -> String:
	for a: String in CliArgs.args():
		if a.begins_with(key + "="):
			return a.substr(key.length() + 1)
	return fallback

static func start() -> void:
	App.character_type = "male"
	App.character_chosen = true
	var sec: float = float(_str("--wdb-pt-sec", "30"))
	var wpn: String = _str("--wdb-pt-weapon", "great_axe")
	var scale: float = float(_str("--wdb-pt-scale", "1"))
	App.playtest.enqueue({"save": "fresh", "weapon": wpn, "tool": "hatchet" if wpn == "staff" else "pickaxe", "gender": "male", "scale": scale, "limit": sec, "cfg": {}})
	App.get_tree().create_timer(sec * 2.0 / maxf(1.0, scale) + 90.0, true, false, true).timeout.connect(func() -> void:
		printerr("PT: timeout=1 sim_t=%.1f act_t=%.1f live=%s" % [App.playtest.sim_t, App.playtest.act_t, str(App.playtest.live_running)])
		App.get_tree().quit()
	)

static func report(d: Dictionary) -> void:
	if not active():
		return
	for k: String in ["end_cond", "kills", "crits", "dmg_dealt", "dmg_taken", "dash_n", "spec_n", "combat_t", "near_death", "duration", "deepest"]:
		printerr("PT: %s=%s" % [k, str(snappedf(float(d[k]), 0.01)) if d.get(k) is float else str(d.get(k))])
	var perf: Dictionary = App.playtest.perf_report()
	for k: String in perf:
		printerr("PT: %s=%s" % [k, str(perf[k])])
	printerr("PT: stuck_t=%.1f seed=%d moved=%s" % [App.playtest.stuck_t, App.run_seed, str(App.playtest.moved)])
	printerr("PT: done=1")
	App.get_tree().quit()
