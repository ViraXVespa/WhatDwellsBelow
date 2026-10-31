extends Object

## Split from sim.gd: one_run, finish_job, stop_live....

const Store := preload("res://scripts/data/save_store.gd")
const LiveSmoke := preload("res://scripts/debug/playtest/live_smoke.gd")
const PlaytestDb := preload("res://scripts/debug/playtest_db.gd")
const PlaytestHub := preload("res://scripts/debug/playtest_hub/forge_pass.gd")
const PlaytestLog := preload("res://scripts/debug/playtest_log.gd")
const PlaytestLogBatch := preload("res://scripts/debug/playtest_log/batch.gd")
const WebHook := preload("res://scripts/debug/web_hook.gd")

static func one_run(pt: Node, kind: String, progressed: bool, wpn: String, tw: Dictionary) -> void:
	var snap: Dictionary = pt._snap_bal()
	for k: Variant in tw.keys():
		App.bal.setv(str(k), float(tw[k]))
	if progressed:
		Store.fresh_delver()
		for id: String in App.prog.SKILLS:
			App.prog.skills_perm[id] = 400.0
		Store.save_slot("progressed")
		Store.load_slot("progressed")
	else:
		Store.wipe_slot("fresh")
		Store.fresh_delver()
		Store.save_slot("fresh")
		Store.load_slot("fresh")
	App.prog.pick_weapon = wpn
	App.prog.tool_type = "pickaxe"
	App.weapon = wpn
	App.character_type = "male"
	App.prog.begin_run_loadout()
	App.tel.reset(kind, true)
	App.tel.start_weapon = wpn
	App.floor_n = 1
	var dmg: float = App.bal.axe_damage
	if wpn == "staff":
		dmg = App.bal.staff_damage
	elif wpn == "longbow":
		dmg = App.bal.bow_damage
	dmg += App.prog.gear_dmg()
	var hp: float = App.bal.dummy_hp * App.bal.enemy_hp_mult
	var kills: int = 0
	var t: float = 0.0
	while kills < 6 and t < 90.0:
		t += 0.4
		App.tel.tick(0.4, true)
		var hit: float = dmg * 0.9
		App.tel.note_damage_dealt(hit, false)
		hp -= hit
		if hp <= 0.0:
			kills += 1
			App.on_kill()
			App.tel.note_kill()
			hp = App.bal.dummy_hp * App.bal.enemy_hp_mult
	App.gold += 12
	App.ore += 8
	App.wood += 4
	App.tel.mine_hits = 8
	App.tel.mine_ok = 5
	App.tel.gold_gained = 12
	App.tel.note_extract(App.gold, App.ore, App.wood)
	App.prog.extract_all("patty")
	if App.tel.clerk_t < 0.0:
		App.tel.clerk_t = 8.0
	App.prog.keep_fragments()
	App.tel.recap_drain = true
	App.tel.note_end("extraction", "")
	pt.history.append(App.tel.to_dict())
	pt._restore_bal(snap)

static func finish_job(pt: Node, cond: String, force_end: bool) -> void:
	if not pt.live_running:
		return
	if force_end and App.tel and App.tel.end_cond == "":
		App.tel.note_end(cond, "")
	if App.extracted and App.tel.end_cond == "":
		App.tel.note_end("extraction", "")
	var end_s: String = cond
	if end_s == "" and App.tel:
		end_s = str(App.tel.end_cond)
	var fail_s: String = end_s
	if end_s == "interrupted playtest" and not App.extracted:
		fail_s = "time_limit"
	PlaytestLog.finish(pt, end_s, fail_s)
	PlaytestLogBatch.note_run()
	if App.tel:
		PlaytestDb.append_finish(App.tel, "", true)
	if str(pt.slot) == "campaign":
		if not pt.interrupted and end_s != "stalled":
			Engine.time_scale = 1.0
			var follow: Dictionary = _campaign_follow(pt)
			App.prog.pick_weapon = str(follow.get("weapon", App.prog.pick_weapon))
			var tool_id: String = str(follow.get("tool", "pickaxe"))
			if tool_id == "":
				tool_id = "pickaxe"
			App.prog.tool_type = tool_id
			var hub_uid: int = PlaytestHub.run_hub()
			if hub_uid > 0:
				follow["hub_equip_uid"] = hub_uid
			Store.save_slot("campaign")
			pt.enqueue(follow)
		else:
			Store.save_slot("campaign")
	else:
		pt.history.append(App.tel.to_dict())
		pt._save_history()
	if App.tel:
		WebHook.publish(App.tel.to_dict())
		LiveSmoke.report(App.tel.to_dict())
	reset_ai_state(pt)
	if pt.queue.is_empty() or pt.interrupted:
		pt._stop_live()
		return
	pt._start_next()

static func stop_live(pt: Node) -> void:
	reset_ai_state(pt)
	pt.live_running = false
	pt.running = false
	pt.smoke_mode = false
	Engine.time_scale = pt.scale_backup if pt.scale_backup > 0.0 else 1.0
	pt._restore_bal(pt.bal_backup)
	if not pt.live_backup.is_empty():
		Store.apply(pt.live_backup)
	pt._compute_coefs()
	pt._build_recs()
	pt._save_coefs()
	pt.last_summary = pt._format()
	if PlaytestLog.file_name != "" and not PlaytestLog.off():
		pt.last_summary += "\nLog: " + PlaytestLog._dir().path_join(PlaytestLog.file_name)
	var bundle: PackedStringArray = PlaytestLogBatch.close()
	for pth: String in bundle:
		pt.last_summary += "\nBatch: " + pth

static func _campaign_follow(pt: Node) -> Dictionary:
	var wpn: String = PlaytestDb.pick_weapon(PlaytestDb.owned_levels(), "")
	var tool: String = str(pt.job.get("tool", "pickaxe"))
	if tool == "":
		tool = "hatchet" if wpn == "staff" else "pickaxe"
	var cfg_v: Variant = pt.job.get("cfg", {})
	var cfg: Dictionary = {}
	if cfg_v is Dictionary:
		cfg = cfg_v
	return {
		"save": "campaign",
		"weapon": wpn,
		"tool": tool,
		"gender": str(pt.job.get("gender", "male")),
		"scale": float(pt.job.get("scale", 1.0)),
		"limit": float(pt.job.get("limit", App.bal.playtest_limit)),
		"cfg": cfg,
	}

static func reset_ai_state(pt: Node) -> void:
	pt.ai_on = false
	pt.sim_t = 0.0
	pt.act_t = 0.0
	pt.reset_perf()
	pt.hum = {}
	pt.stuck_t = 0.0
	pt.wander_t = 0.0
	pt.wander_dir = Vector2.ZERO
	pt.move = Vector2.ZERO
	pt.aim = Vector2.DOWN
	pt.attack = false
	pt.special = false
	pt.interact = false
	pt.dash = false
	pt.potion = false
	pt.spec_cd = 0.0
	pt.moved = false
	pt.hit_something = false
	pt.recap_taken = false
	pt.strafe_sign = 1.0
	pt.last_pos = Vector3.ZERO
	pt.last_beat_t = -1.0
	pt.last_wait_t = -9.0
	pt.path.clear()
	pt.path_i = 0
	pt.path_goal = null
	pt.just.clear()
	if "last_think_t" in pt:
		pt.last_think_t = -1.0
	App.extracted = false
	App.ui_open = false
	for key: String in [
		"lock_n", "lock_t", "cell_t", "skip_list", "seen_map", "decide_why",
		"log_gather_d", "log_clerk_d", "log_threat_d", "log_gather_k",
		"trail", "stuck_cell", "wander_hold", "dash_cd", "flee_c",
	]:
		if pt.has_meta(key):
			pt.remove_meta(key)
