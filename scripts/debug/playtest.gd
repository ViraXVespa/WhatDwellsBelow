extends Node

## Full-target Automated Playtest. Drives the live player, combat, gather,
## clerks, recap, and isolated saves. Medium-bar fast seed remains for coefs.

const Store := preload("res://scripts/data/save_store.gd")
const TelS := preload("res://scripts/debug/telemetry.gd")

var history: Array = []
var recs: Dictionary = {"fresh": [], "progressed": []}
var coefs: Dictionary = {}
var last_summary := ""
var interrupted := false
var running := false
var live_running := false
var ai_on := false
var queue: Array = []
var job: Dictionary = {}
var slot := "fresh"
var live_backup: Dictionary = {}
var bal_backup: Dictionary = {}
var scale_backup := 1.0
var sim_t := 0.0
var stuck_t := 0.0
var last_pos := Vector3.ZERO
var wander_t := 0.0
var wander_dir := Vector2.ZERO
var spec_cd := 0.0
var just: Dictionary = {}
var move := Vector2.ZERO
var aim := Vector2.DOWN
var attack := false
var special := false
var interact := false
var dash := false
var potion := false
var smoke_mode := false
var moved := false
var hit_something := false
var recap_taken := false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	process_priority = -80
	_load_history()
	_load_coefs()
	if not recs["fresh"].is_empty() or not history.is_empty():
		_build_recs()


func interrupt() -> void:
	interrupted = true
	if live_running:
		_finish_job("interrupted playtest", true)


func queue_batch() -> String:
	interrupted = false
	var weapons := ["great_axe", "staff", "longbow"]
	var tools := ["pickaxe", "hatchet", "pickaxe"]
	var genders := ["male", "female", "male"]
	for kind in ["fresh", "progressed"]:
		for i in 3:
			enqueue({
				"save": kind,
				"weapon": weapons[i],
				"tool": tools[i],
				"gender": genders[i],
				"scale": App.bal.playtest_scale,
				"limit": App.bal.playtest_limit,
				"cfg": {},
			})
	return "Queued %d live runs." % queue.size()


func enqueue(j: Dictionary) -> void:
	queue.append(j)
	if not live_running:
		_start_next()


func begin_smoke() -> void:
	smoke_mode = true
	interrupted = false
	moved = false
	hit_something = false
	ai_on = true
	live_running = true
	running = true
	sim_t = 0.0
	slot = "fresh"
	job = {"save": "fresh", "weapon": App.weapon, "tool": App.prog.tool_type, "limit": 8.0, "scale": 1.0, "cfg": {}}
	App.tel.reset("fresh", true)
	App.tel.start_weapon = App.weapon


func run_medium() -> String:
	running = true
	interrupted = false
	var snapshot: Dictionary = _snap_bal()
	var live: Dictionary = Store.collect()
	_sim_save("fresh", false)
	if interrupted:
		_restore_bal(snapshot)
		Store.apply(live)
		running = false
		return "Interrupted. Rows kept: %d" % history.size()
	_sim_save("progressed", true)
	_compute_coefs()
	_build_recs()
	_save_coefs()
	_save_history()
	_restore_bal(snapshot)
	Store.apply(live)
	running = false
	last_summary = _format()
	return last_summary


func apply_rec(save_kind: String, i: int) -> String:
	var arr: Array = recs.get(save_kind, [])
	if i < 0 or i >= arr.size():
		return "No recommendation."
	var cfg: Dictionary = arr[i].cfg
	for k in cfg.keys():
		App.bal.setv(str(k), float(cfg[k]))
	return "Applied %s rec %d." % [save_kind, i + 1]


func ideal_for(name: String, save_kind: String) -> float:
	var arr: Array = recs.get(save_kind, [])
	if arr.is_empty():
		return App.bal.getv(name)
	var cfg: Dictionary = arr[0].cfg
	if cfg.has(name):
		return float(cfg[name])
	return App.bal.getv(name)


func reset_progressed_template() -> String:
	var live: Dictionary = Store.collect()
	Store.fresh_delver()
	for id in App.prog.SKILLS:
		App.prog.skills_perm[id] = 400.0
	App.prog.deepest = 8
	App.bank_gold = 80
	App.bank_ore = 24
	App.bank_wood = 16
	App.character_chosen = true
	Store.save_slot("progressed")
	Store.apply(live)
	return "Progressed template reset (isolated slot)."


func consume_recap() -> bool:
	if not live_running or recap_taken:
		return false
	recap_taken = true
	App.tel.recap_drain = true
	_finish_job(str(App.tel.end_cond), false)
	return true


func _physics_process(delta: float) -> void:
	if not live_running or not ai_on:
		return
	just.clear()
	attack = false
	special = false
	interact = false
	dash = false
	potion = false
	move = Vector2.ZERO
	spec_cd = maxf(0.0, spec_cd - delta)
	sim_t += delta
	if App.recap and bool(App.recap.get("open")):
		if bool(App.recap.get("draining")):
			App.recap.skip_drain()
		elif not recap_taken:
			App.recap._finish()
		return
	if App.ui_open and App.prog:
		_try_close_extract()
		return
	var p := get_tree().get_first_node_in_group("player")
	if p == null or not is_instance_valid(p):
		return
	if smoke_mode and sim_t >= 8.0:
		_finish_job("interrupted playtest", true)
		return
	var limit := float(job.get("limit", App.bal.playtest_limit))
	if not smoke_mode and sim_t >= limit:
		_finish_job("interrupted playtest", true)
		return
	_think(p, delta)


func _think(p: Node, _delta: float) -> void:
	var pos: Vector3 = (p as Node3D).global_position
	if last_pos.distance_to(pos) > 0.08:
		moved = true
		stuck_t = 0.0
	else:
		stuck_t += _delta
	last_pos = pos
	if p.get("hp") != null and float(p.hp) / maxf(1.0, float(p.max_hp)) < 0.35:
		potion = true
		just["potion"] = true
	var enemy := _nearest(p, "enemies")
	var clerk := _nearest_kind(p, "clerk")
	var node := _nearest(p, "gather")
	if wander_t > 0.0:
		wander_t -= _delta
		move = wander_dir
		aim = wander_dir if wander_dir.length() > 0.1 else aim
		return
	if randf() < 0.08:
		wander_t = 0.35
		wander_dir = Vector2(randf() * 2.0 - 1.0, randf() * 2.0 - 1.0).normalized()
		move = wander_dir
		return
	if enemy and _dist(p, enemy) < 5.2:
		aim = _xz_to(p, enemy)
		move = aim
		attack = true
		if _dist(p, enemy) < 2.4 and spec_cd <= 0.0 and randf() < 0.35:
			special = true
			just["special"] = true
			spec_cd = 1.1
		if stuck_t > 0.45 or _crowd(p) >= 3:
			dash = true
			just["dash"] = true
		if App.tel and App.tel.dmg_dealt > 0.0:
			hit_something = true
		return
	if App.extracted:
		just["pause"] = false
		App.end_run("dispel", "")
		return
	if clerk and (App.ore + App.gold + App.wood >= 2 or App.extracted):
		aim = _xz_to(p, clerk)
		move = _steer(p, clerk)
		if _dist(p, clerk) < 1.15:
			interact = true
			just["interact"] = true
			_try_extract(clerk)
		return
	if node and str(App.prog.tool_type) == _tool_for(node) and App.ore + App.wood < 6:
		aim = _xz_to(p, node)
		move = _steer(p, node)
		if _dist(p, node) < 1.2:
			interact = true
			just["interact"] = true
		return
	var dest: Node = clerk if clerk else node
	if dest == null:
		dest = _nearest_kind(p, "stairs")
	if dest:
		move = _steer(p, dest)
		aim = move if move.length() > 0.1 else aim
	else:
		move = Vector2(0.0, 1.0)
	if stuck_t > 0.55:
		dash = true
		just["dash"] = true
		move = move.rotated(1.2)


func _try_extract(clerk: Node) -> void:
	var role := "gather"
	var k := str(clerk.get("kind"))
	if k.find("misc") >= 0:
		role = "misc"
	elif k.find("patty") >= 0:
		role = "patty"
	App.note_clerk()
	App.prog.extract_all(role)
	if App.ui_open:
		var ui := get_tree().get_first_node_in_group("world_ui")
		if ui and ui.has_method("close_ui"):
			ui.close_ui()


func _try_close_extract() -> void:
	var ui := get_tree().current_scene
	if ui and ui.has_method("world_ui"):
		var w: Node = ui.world_ui()
		if w and w.has_method("close_ui"):
			if str(w.get("mode")) == "extract":
				App.prog.extract_all(str(w.get("extract_role")))
			w.close_ui()


func _tool_for(node: Node) -> String:
	return "hatchet" if str(node.get("kind")) == "wood" else "pickaxe"


func _nearest(p: Node, group: String) -> Node:
	var best: Node = null
	var best_d := 80.0
	var tree := get_tree()
	if tree == null:
		return null
	for n in tree.get_nodes_in_group(group):
		if n == null or not is_instance_valid(n):
			continue
		if n.has_method("is_alive") and not n.is_alive():
			continue
		var d := _dist(p, n)
		if d < best_d:
			best_d = d
			best = n
	return best


func _nearest_kind(p: Node, prefix: String) -> Node:
	var best: Node = null
	var best_d := 80.0
	var tree := get_tree()
	if tree == null:
		return null
	for n in tree.get_nodes_in_group("interact"):
		if n == null or not is_instance_valid(n):
			continue
		if str(n.get("kind")).find(prefix) < 0:
			continue
		var d := _dist(p, n)
		if d < best_d:
			best_d = d
			best = n
	return best


func _crowd(p: Node) -> int:
	var n := 0
	for e in get_tree().get_nodes_in_group("enemies"):
		if e and is_instance_valid(e) and _dist(p, e) < 2.4:
			n += 1
	return n


func _dist(a: Node, b: Node) -> float:
	if a is Node3D and b is Node3D:
		var pa: Vector3 = (a as Node3D).global_position
		var pb: Vector3 = (b as Node3D).global_position
		return Vector2(pb.x - pa.x, pb.z - pa.z).length()
	return 999.0


func _xz_to(a: Node, b: Node) -> Vector2:
	var pa: Vector3 = (a as Node3D).global_position
	var pb: Vector3 = (b as Node3D).global_position
	var d := Vector2(pb.x - pa.x, pb.z - pa.z)
	if d.length() < 0.001:
		return Vector2.DOWN
	return d.normalized()


func _steer(p: Node, dest: Node) -> Vector2:
	var n := _xz_to(p, dest)
	var from: Vector3 = (p as Node3D).global_position + Vector3(0, 0.4, 0)
	if _clear(from, n):
		return n
	for a in [0.6, -0.6, 1.1, -1.1, 1.7, -1.7]:
		var r := n.rotated(a)
		if _clear(from, r):
			return r
	return n.rotated(0.9)


func _clear(from: Vector3, dir: Vector2) -> bool:
	var tree := get_tree()
	if tree == null or tree.root == null:
		return true
	var w3 := tree.root.get_viewport().world_3d
	if w3 == null:
		return true
	var to := from + Vector3(dir.x, 0.0, dir.y) * 0.85
	var q := PhysicsRayQueryParameters3D.create(from, to)
	q.collision_mask = 1
	return w3.direct_space_state.intersect_ray(q).is_empty()


func _start_next() -> void:
	if interrupted or queue.is_empty():
		_stop_live()
		return
	if not live_running:
		live_backup = Store.collect()
		bal_backup = _snap_bal()
		scale_backup = Engine.time_scale
	job = queue.pop_front()
	live_running = true
	running = true
	ai_on = true
	sim_t = 0.0
	stuck_t = 0.0
	wander_t = 0.0
	moved = false
	recap_taken = false
	slot = str(job.get("save", "fresh"))
	_prep_slot()
	var cfg: Dictionary = job.get("cfg", {})
	for k in cfg.keys():
		App.bal.setv(str(k), float(cfg[k]))
	App.set_character(str(job.get("gender", "male")))
	App.prog.pick_weapon = str(job.get("weapon", "great_axe"))
	App.prog.tool_type = str(job.get("tool", "pickaxe"))
	App.weapon = App.prog.pick_weapon
	App.prog.begin_run_loadout()
	App.tel.reset(slot, true)
	App.tel.start_weapon = App.weapon
	Engine.time_scale = maxf(1.0, float(job.get("scale", App.bal.playtest_scale)))
	if App.debug and bool(App.debug.get("open")):
		App.debug.hide_menu()
	if App.pause_menu and bool(App.pause_menu.get("open")):
		App.pause_menu.close_ui()
	App.begin_run()


func _prep_slot() -> void:
	if slot == "progressed":
		Store.fresh_delver()
		for id in App.prog.SKILLS:
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


func _finish_job(cond: String, force_end: bool) -> void:
	if not live_running:
		return
	if force_end and App.tel and App.tel.end_cond == "":
		App.tel.note_end(cond, "")
	if App.extracted and App.tel.end_cond == "":
		App.tel.note_end("extraction", "")
	history.append(App.tel.to_dict())
	_save_history()
	ai_on = false
	if queue.is_empty() or interrupted:
		_stop_live()
		return
	_start_next()


func _stop_live() -> void:
	ai_on = false
	live_running = false
	running = false
	smoke_mode = false
	Engine.time_scale = scale_backup if scale_backup > 0.0 else 1.0
	_restore_bal(bal_backup)
	if not live_backup.is_empty():
		Store.apply(live_backup)
	_compute_coefs()
	_build_recs()
	_save_coefs()
	last_summary = _format()


func _sim_save(kind: String, progressed: bool) -> void:
	var weapons := ["great_axe", "staff", "longbow"]
	var tweaks := [
		{},
		{"axe_damage": App.bal.axe_damage * 1.2},
		{"staff_damage": App.bal.staff_damage * 1.2},
		{"bow_damage": App.bal.bow_damage * 1.2},
		{"enemy_hp_mult": App.bal.enemy_hp_mult * 0.8},
		{"mine_chance": mini_f(0.95, App.bal.mine_chance + 0.15)},
	]
	for w in weapons:
		for tw in tweaks:
			if interrupted:
				return
			_one_run(kind, progressed, w, tw)


func mini_f(a: float, b: float) -> float:
	return a if a < b else b


func _one_run(kind: String, progressed: bool, wpn: String, tw: Dictionary) -> void:
	var snap: Dictionary = _snap_bal()
	for k in tw.keys():
		App.bal.setv(str(k), float(tw[k]))
	if progressed:
		Store.fresh_delver()
		for id in App.prog.SKILLS:
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
	var hp := App.bal.dummy_hp * App.bal.enemy_hp_mult
	var kills := 0
	var t := 0.0
	while kills < 6 and t < 90.0:
		t += 0.4
		App.tel.tick(0.4, true)
		var hit := dmg * 0.9
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
	history.append(App.tel.to_dict())
	_restore_bal(snap)


func _compute_coefs() -> void:
	coefs.clear()
	for key in ["axe_damage", "staff_damage", "bow_damage", "enemy_hp_mult", "mine_chance"]:
		var xs: Array = []
		var ys: Array = []
		for row in history:
			xs.append(_cfg_proxy(key, row))
			ys.append(float(row.get("dmg_dealt", 0)) + 1.0 / maxf(0.2, float(row.get("duration", 1.0))))
		coefs[key] = _corr(xs, ys)
	_weapon_aware_nudge()


func _weapon_aware_nudge() -> void:
	var dmg := {"great_axe": 0.0, "staff": 0.0, "longbow": 0.0}
	for row in history:
		var wv: Variant = row.get("wpn", {})
		var w: Dictionary = wv if wv is Dictionary else {}
		for id in dmg.keys():
			var dv: Variant = w.get(id, {})
			var wd: Dictionary = dv if dv is Dictionary else {}
			dmg[id] = float(dmg[id]) + float(wd.get("dmg", 0))
	var mx := maxf(dmg["great_axe"], maxf(dmg["staff"], dmg["longbow"]))
	if mx <= 1.0:
		return
	if dmg["staff"] < mx * 0.55:
		coefs["staff_damage"] = maxf(float(coefs.get("staff_damage", 0.0)), 0.35)
	if dmg["longbow"] < mx * 0.55:
		coefs["bow_damage"] = maxf(float(coefs.get("bow_damage", 0.0)), 0.35)
	if dmg["great_axe"] < mx * 0.55:
		coefs["axe_damage"] = maxf(float(coefs.get("axe_damage", 0.0)), 0.35)


func _cfg_proxy(key: String, row: Dictionary) -> float:
	var w: Dictionary = row.get("wpn", {})
	if key == "axe_damage":
		return float((w.get("great_axe", {}) as Dictionary).get("dmg", 0))
	if key == "staff_damage":
		return float((w.get("staff", {}) as Dictionary).get("dmg", 0))
	if key == "bow_damage":
		return float((w.get("longbow", {}) as Dictionary).get("dmg", 0))
	if key == "enemy_hp_mult":
		return 1.0 / maxf(0.5, float(row.get("kills", 1)))
	return float(row.get("mine_ok", 0))


func _corr(xs: Array, ys: Array) -> float:
	var n := mini(xs.size(), ys.size())
	if n < 3:
		return 0.0
	var mx := 0.0
	var my := 0.0
	for i in n:
		mx += float(xs[i])
		my += float(ys[i])
	mx /= float(n)
	my /= float(n)
	var num := 0.0
	var dx := 0.0
	var dy := 0.0
	for i in n:
		var a := float(xs[i]) - mx
		var b := float(ys[i]) - my
		num += a * b
		dx += a * a
		dy += b * b
	if dx < 0.0001 or dy < 0.0001:
		return 0.0
	return clampf(num / sqrt(dx * dy), -1.0, 1.0)


func _build_recs() -> void:
	var base := {
		"axe_damage": App.bal.axe_damage,
		"staff_damage": App.bal.staff_damage,
		"bow_damage": App.bal.bow_damage,
		"enemy_hp_mult": App.bal.enemy_hp_mult,
		"mine_chance": App.bal.mine_chance,
		"move_speed": App.bal.move_speed,
	}
	var avg: float = (float(base.axe_damage) + float(base.staff_damage) + float(base.bow_damage)) / 3.0
	var staff_n := avg * 0.55
	var bow_n := avg * 0.8
	if float(coefs.get("staff_damage", 0.0)) > 0.2:
		staff_n = avg * 0.7
	if float(coefs.get("bow_damage", 0.0)) > 0.2:
		bow_n = avg * 0.9
	recs["fresh"] = [
		{"label": "Ideal — first extraction", "cfg": _merge(base, {"enemy_hp_mult": float(base.enemy_hp_mult) * 0.85, "mine_chance": mini_f(0.9, float(base.mine_chance) + 0.1), "move_speed": float(base.move_speed) * 1.05})},
		{"label": "Alt A — safer combat", "cfg": _merge(base, {"enemy_hp_mult": float(base.enemy_hp_mult) * 0.9, "axe_damage": avg})},
		{"label": "Alt B — gather lean", "cfg": _merge(base, {"mine_chance": mini_f(0.95, float(base.mine_chance) + 0.15)})},
	]
	recs["progressed"] = [
		{"label": "Ideal — weapon balance", "cfg": _merge(base, {"axe_damage": avg, "staff_damage": staff_n, "bow_damage": bow_n})},
		{"label": "Alt A — later floors", "cfg": _merge(base, {"enemy_hp_mult": float(base.enemy_hp_mult) * 1.1, "cycle_hp": App.bal.cycle_hp})},
		{"label": "Alt B — keep current", "cfg": base.duplicate()},
	]


func _merge(base: Dictionary, extra: Dictionary) -> Dictionary:
	var o := base.duplicate()
	for k in extra.keys():
		o[k] = extra[k]
	return o


func _snap_bal() -> Dictionary:
	var d := {}
	for row in App.bal.schema():
		d[str(row[0])] = App.bal.getv(str(row[0]))
	return d


func _restore_bal(d: Dictionary) -> void:
	for k in d.keys():
		App.bal.setv(str(k), float(d[k]))


func _format() -> String:
	var s := "Playtest  ·  rows %d  ·  queue %d\n" % [history.size(), queue.size()]
	s += "Coefs: "
	for k in coefs.keys():
		s += "%s=%.2f  " % [k, float(coefs[k])]
	s += "\nFresh recs: "
	for r in recs["fresh"]:
		s += str(r.label) + " | "
	s += "\nProgressed recs: "
	for r in recs["progressed"]:
		s += str(r.label) + " | "
	s += "\n" + success_report()
	return s


func success_report() -> String:
	if history.is_empty():
		return "Success: no rows."
	var extract_t := 9999.0
	var drain := true
	var wpn_kills := {"great_axe": 0.0, "staff": 0.0, "longbow": 0.0}
	for row in history:
		if str(row.get("end_cond", "")) == "extraction":
			extract_t = minf(extract_t, float(row.get("duration", 9999.0)))
		if not bool(row.get("recap_drain", false)):
			drain = false
		var wv: Variant = row.get("wpn", {})
		var w: Dictionary = wv if wv is Dictionary else {}
		for id in wpn_kills.keys():
			var dv: Variant = w.get(id, {})
			var wd: Dictionary = dv if dv is Dictionary else {}
			wpn_kills[id] = float(wpn_kills[id]) + float(wd.get("kills", 0))
	var mx := maxf(wpn_kills["great_axe"], maxf(wpn_kills["staff"], wpn_kills["longbow"]))
	var mn := minf(wpn_kills["great_axe"], minf(wpn_kills["staff"], wpn_kills["longbow"]))
	var bal_ok := mx <= 0.001 or (mn / maxf(0.001, mx)) >= 0.45
	var t_ok := extract_t <= 600.0
	return "SuccessCriterion extract_s=%.1f t_ok=%s recap=%s weapons_bal=%s" % [extract_t, str(t_ok), str(drain), str(bal_ok)]


func _save_history() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("user://playtest"))
	var f := FileAccess.open("user://playtest/history.json", FileAccess.WRITE)
	if f:
		f.store_string(JSON.stringify(history))


func _load_history() -> void:
	if not FileAccess.file_exists("user://playtest/history.json"):
		return
	var f := FileAccess.open("user://playtest/history.json", FileAccess.READ)
	if f == null:
		return
	var parsed: Variant = JSON.parse_string(f.get_as_text())
	if parsed is Array:
		history = parsed


func _save_coefs() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("user://playtest"))
	var f := FileAccess.open("user://playtest/coefs.json", FileAccess.WRITE)
	if f:
		f.store_string(JSON.stringify(coefs))


func _load_coefs() -> void:
	if not FileAccess.file_exists("user://playtest/coefs.json"):
		return
	var f := FileAccess.open("user://playtest/coefs.json", FileAccess.READ)
	if f == null:
		return
	var parsed: Variant = JSON.parse_string(f.get_as_text())
	if parsed is Dictionary:
		coefs = parsed
