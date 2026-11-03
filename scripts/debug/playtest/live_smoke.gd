extends Object

## --wdb-playtest-live-smoke: boots straight into one live AI run on floor 1, prints `PT:` lines, quits.
## --wdb-pt-campaign: boots one campaign series on the kept slot. A dive has no acting-time end. It returns to the hub and enters again through the crystal until every weapon has cleared floor 5. Interrupt or a stall stops it. --wdb-pt-gather=N stops it after this process has saved at least N decide rows.
## Args (after --): --wdb-seed=N (run seed), --wdb-pt-weapon=great_axe|staff|longbow, --wdb-pt-sec=S (sim seconds), --wdb-pt-scale=X (time scale while acting; only with --wdb-pt-fast, else 1.0).
## Debug only: run `godot --headless --path . -- --wdb-playtest-live-smoke --wdb-seed=42`.

const CliArgs := preload("res://scripts/app/cli_args.gd")
const Trial := preload("res://scripts/debug/playtest/trial_bal.gd")
const FLAG := "--wdb-playtest-live-smoke"
const CAMPAIGN_FLAG := "--wdb-pt-campaign"
const GATHER_FLAG := "--wdb-pt-gather"
static var gather_n: int = 0

static func active() -> bool:
	return CliArgs.has(FLAG) or CliArgs.has(CAMPAIGN_FLAG)

static func campaign_active() -> bool:
	return CliArgs.has(CAMPAIGN_FLAG)

static func _str(key: String, fallback: String) -> String:
	for a: String in CliArgs.args():
		if a.begins_with(key + "="):
			return a.substr(key.length() + 1)
	return fallback

static func start() -> void:
	Trial.apply()
	App.character_type = "male"
	App.character_chosen = true
	var sec: float = float(_str("--wdb-pt-sec", "30"))
	var wpn: String = _str("--wdb-pt-weapon", "great_axe")
	var scale: float = float(_str("--wdb-pt-scale", "1"))
	if campaign_active():
		App.playtest.enqueue({"save": "campaign", "weapon": "", "tool": "pickaxe", "gender": "male", "scale": scale, "limit": sec, "cfg": {}})
		return
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
	if campaign_active():
		return
	printerr("PT: done=1")
	App.get_tree().quit()

static func gather_limit() -> int:
	var raw: String = _str(GATHER_FLAG, "")
	if raw == "" or not raw.is_valid_int():
		return 0
	return maxi(0, int(raw))


static func note_gather(events: Array) -> void:
	if gather_limit() <= 0:
		return
	for ev: Variant in events:
		if ev is Dictionary and str((ev as Dictionary).get("ev", "")) == "decide":
			gather_n += 1


static func gather_full() -> bool:
	var lim: int = gather_limit()
	return lim > 0 and gather_n >= lim


static func campaign_stop(why: String) -> void:
	if not campaign_active():
		return
	if why == "cleared":
		printerr("PT: campaign_done=1")
		printerr("PT: done=1")
	elif why == "gather":
		printerr("PT: campaign_stop=gather")
		printerr("PT: gather_rows=%d" % gather_n)
		printerr("PT: done=1")
	else:
		printerr("PT: campaign_stop=%s" % why)
	var tree: SceneTree = App.get_tree()
	if tree:
		tree.quit()
