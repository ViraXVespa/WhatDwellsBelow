extends Object

const Store := preload("res://scripts/data/save_store.gd")
const Kit := preload("res://scripts/data/gear_rules/rules_kit.gd")
const WebHook := preload("res://scripts/debug/web_hook.gd")
const LiveSmoke := preload("res://scripts/debug/playtest/live_smoke.gd")
const Recs := preload("res://scripts/debug/playtest/recs.gd")
const PlaytestLog := preload("res://scripts/debug/playtest_log.gd")
const PlaytestDb := preload("res://scripts/debug/playtest_db.gd")
const PlaytestHub := preload("res://scripts/debug/playtest_hub/forge_pass.gd")
const PlaytestLogBatch := preload("res://scripts/debug/playtest_log/batch.gd")

const Finish := preload("res://scripts/debug/playtest/sim_finish.gd")
static func reset_ai_state(pt: Node) -> void:
	Finish.reset_ai_state(pt)

static func start_next(pt: Node) -> void:
	if pt.interrupted or pt.queue.is_empty():
		pt._stop_live()
		return
	if not pt.live_running:
		pt.live_backup = Store.collect()
		pt.bal_backup = pt._snap_bal()
		pt.scale_backup = Engine.time_scale
		PlaytestLogBatch.begin()
	pt.job = pt.queue.pop_front()
	pt.live_running = true
	pt.running = true
	reset_ai_state(pt)
	pt.slot = str(pt.job.get("save", "fresh"))
	pt._prep_slot()
	if pt.slot == "campaign" and str(pt.job.get("weapon", "")) == "":
		var picked: String = PlaytestDb.pick_weapon(PlaytestDb.owned_levels(), "")
		pt.job["weapon"] = picked
		if picked == "staff":
			pt.job["tool"] = "hatchet"
	var cfg: Dictionary = pt.job.get("cfg", {})
	for k: Variant in cfg.keys():
		App.bal.setv(str(k), float(cfg[k]))
	App.set_character(str(pt.job.get("gender", "male")))
	App.prog.pick_weapon = str(pt.job.get("weapon", "great_axe"))
	App.prog.tool_type = str(pt.job.get("tool", "pickaxe"))
	App.weapon = App.prog.pick_weapon
	var hub_uid: int = int(pt.job.get("hub_equip_uid", 0))
	if pt.slot == "campaign" and hub_uid <= 0:
		_wear_campaign_weapon()
	if hub_uid > 0:
		App.tel.reset(pt.slot, true)
		App.tel.start_weapon = App.weapon
		PlaytestHub.equip_pending(hub_uid)
		if pt.slot == "campaign":
			_wear_campaign_weapon()
		App.prog.begin_run_loadout()
	else:
		App.prog.begin_run_loadout()
		App.tel.reset(pt.slot, true)
		App.tel.start_weapon = App.weapon
	Engine.time_scale = 1.0  # the job scale only applies once the AI is acting (playtest_api _tick), never during loads
	if App.debug and bool(App.debug.get("open")):
		App.debug.hide_menu()
	if App.pause_menu and bool(App.pause_menu.get("open")):
		App.pause_menu.close_ui()
	App.ui_open = false
	PlaytestLog.begin(pt)
	App.begin_run()

static func prep_slot(pt: Node) -> void:
	if pt.slot == "campaign":
		if Store.load_slot("campaign") == "fresh":
			Store.save_slot("campaign")
		return
	if pt.slot == "progressed":
		Store.fresh_delver()
		for id: String in App.prog.SKILLS:
			App.prog.skills_perm[id] = 400.0
		App.prog.deepest = 8
		App.bank_gold = 80
		App.bank_ore = 20
		App.bank_wood = 12
		App.character_chosen = true
		Store.save_slot("progressed")
		Store.load_slot("progressed")
	else:
		Store.wipe_slot("fresh")
		Store.fresh_delver()
		Store.save_slot("fresh")
		Store.load_slot("fresh")

static func _wear_campaign_weapon() -> void:
	var wpn: String = str(App.prog.pick_weapon)
	App.prog.hold_pick["weapon"] = _best_weapon_hold(wpn)

static func _best_weapon_hold(wpn: String) -> int:
	var raw: Variant = App.prog.holds.get("weapon", [])
	if not (raw is Array):
		return -1
	var best_i: int = -1
	var best_lv: int = -1
	var best_aff: float = -1.0
	var i: int = 0
	for piece: Variant in raw:
		if piece is Dictionary:
			var it: Dictionary = piece
			if str(it.get("weapon", "")) == wpn:
				var lv: int = int(it.get("ilvl", 0))
				var aff: float = _affix_sum(it)
				if best_i < 0 or lv > best_lv or (lv == best_lv and aff > best_aff):
					best_i = i
					best_lv = lv
					best_aff = aff
		i += 1
	return best_i

static func _affix_sum(it: Dictionary) -> float:
	var raw: Variant = it.get("affixes", [])
	if not (raw is Array):
		return 0.0
	var total: float = 0.0
	for one: Variant in raw:
		if one is Dictionary:
			total += float((one as Dictionary).get("value", 0.0))
	return total

static func finish_job(pt: Node, cond: String, force_end: bool) -> void:
	Finish.finish_job(pt, cond, force_end)

static func stop_live(pt: Node) -> void:
	Finish.stop_live(pt)

static func sim_save(pt: Node, kind: String, progressed: bool) -> void:
	var weapons: PackedStringArray = PackedStringArray(Kit.BUILTIN_WEAPONS)
	var tweaks: Array = [
		{},
		{"axe_damage": App.bal.axe_damage * 1.2},
		{"staff_damage": App.bal.staff_damage * 1.2},
		{"bow_damage": App.bal.bow_damage * 1.2},
		{"enemy_hp_mult": App.bal.enemy_hp_mult * 0.8},
		{"mine_chance": pt.mini_f(0.95, App.bal.mine_chance + 0.15)},
	]
	for w: String in weapons:
		for tw: Dictionary in tweaks:
			if pt.interrupted:
				return
			pt._one_run(kind, progressed, w, tw)

static func one_run(pt: Node, kind: String, progressed: bool, wpn: String, tw: Dictionary) -> void:
	Finish.one_run(pt, kind, progressed, wpn, tw)

static func compute_coefs(pt: Node) -> void:
	Recs.compute_coefs(pt)

static func weapon_aware_nudge(pt: Node) -> void:
	Recs.weapon_aware_nudge(pt)

static func cfg_proxy(key: String, row: Dictionary) -> float:
	return Recs.cfg_proxy(key, row)

static func corr(xs: Array, ys: Array) -> float:
	return Recs.corr(xs, ys)

static func build_recs(pt: Node) -> void:
	Recs.build_recs(pt)

static func merge(base: Dictionary, extra: Dictionary) -> Dictionary:
	return Recs.merge(base, extra)

static func snap_bal() -> Dictionary:
	return Recs.snap_bal()

static func restore_bal(d: Dictionary) -> void:
	Recs.restore_bal(d)

static func format_summary(pt: Node) -> String:
	return Recs.format_summary(pt)

static func success_report(pt: Node) -> String:
	return Recs.success_report(pt)

static func save_history(pt: Node) -> void:
	Recs.save_history(pt)

static func load_history(pt: Node) -> void:
	Recs.load_history(pt)

static func save_coefs(pt: Node) -> void:
	Recs.save_coefs(pt)

static func load_coefs(pt: Node) -> void:
	Recs.load_coefs(pt)
