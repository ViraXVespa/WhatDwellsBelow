extends Object

const Store := preload("res://scripts/data/save_store.gd")
const Recs := preload("res://scripts/debug/playtest_recs.gd")


static func start_next(pt: Node) -> void:
	if pt.interrupted or pt.queue.is_empty():
		pt._stop_live()
		return
	if not pt.live_running:
		pt.live_backup = Store.collect()
		pt.bal_backup = pt._snap_bal()
		pt.scale_backup = Engine.time_scale
	pt.job = pt.queue.pop_front()
	pt.live_running = true
	pt.running = true
	pt.ai_on = false
	pt.sim_t = 0.0
	pt.stuck_t = 0.0
	pt.wander_t = 0.0
	pt.moved = false
	pt.recap_taken = false
	pt.path.clear()
	pt.path_i = 0
	pt.path_goal = null
	pt.slot = str(pt.job.get("save", "fresh"))
	pt._prep_slot()
	var cfg: Dictionary = pt.job.get("cfg", {})
	for k: Variant in cfg.keys():
		App.bal.setv(str(k), float(cfg[k]))
	App.set_character(str(pt.job.get("gender", "male")))
	App.prog.pick_weapon = str(pt.job.get("weapon", "great_axe"))
	App.prog.tool_type = str(pt.job.get("tool", "pickaxe"))
	App.weapon = App.prog.pick_weapon
	App.prog.begin_run_loadout()
	App.tel.reset(pt.slot, true)
	App.tel.start_weapon = App.weapon
	Engine.time_scale = maxf(1.0, float(pt.job.get("scale", App.bal.playtest_scale)))
	if App.debug and bool(App.debug.get("open")):
		App.debug.hide_menu()
	if App.pause_menu and bool(App.pause_menu.get("open")):
		App.pause_menu.close_ui()
	App.begin_run()


static func prep_slot(pt: Node) -> void:
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


static func finish_job(pt: Node, cond: String, force_end: bool) -> void:
	if not pt.live_running:
		return
	if force_end and App.tel and App.tel.end_cond == "":
		App.tel.note_end(cond, "")
	if App.extracted and App.tel.end_cond == "":
		App.tel.note_end("extraction", "")
	pt.history.append(App.tel.to_dict())
	pt._save_history()
	pt.ai_on = false
	pt.path.clear()
	pt.path_goal = null
	if pt.queue.is_empty() or pt.interrupted:
		pt._stop_live()
		return
	pt._start_next()


static func stop_live(pt: Node) -> void:
	pt.ai_on = false
	pt.live_running = false
	pt.running = false
	pt.smoke_mode = false
	pt.path.clear()
	pt.path_goal = null
	Engine.time_scale = pt.scale_backup if pt.scale_backup > 0.0 else 1.0
	pt._restore_bal(pt.bal_backup)
	if not pt.live_backup.is_empty():
		Store.apply(pt.live_backup)
	pt._compute_coefs()
	pt._build_recs()
	pt._save_coefs()
	pt.last_summary = pt._format()


static func sim_save(pt: Node, kind: String, progressed: bool) -> void:
	var weapons: PackedStringArray = PackedStringArray(["great_axe", "staff", "longbow"])
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
