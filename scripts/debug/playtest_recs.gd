extends Object


static func compute_coefs(pt: Node) -> void:
	pt.coefs.clear()
	for key: String in ["axe_damage", "staff_damage", "bow_damage", "enemy_hp_mult", "mine_chance"]:
		var xs: Array = []
		var ys: Array = []
		for row: Variant in pt.history:
			xs.append(pt._cfg_proxy(key, row))
			ys.append(float(row.get("dmg_dealt", 0)) + 1.0 / maxf(0.2, float(row.get("duration", 1.0))))
		pt.coefs[key] = pt._corr(xs, ys)
	pt._weapon_aware_nudge()


static func weapon_aware_nudge(pt: Node) -> void:
	var dmg: Dictionary = {"great_axe": 0.0, "staff": 0.0, "longbow": 0.0}
	for row: Variant in pt.history:
		var wv: Variant = row.get("wpn", {})
		var w: Dictionary = wv if wv is Dictionary else {}
		for id: String in dmg.keys():
			var dv: Variant = w.get(id, {})
			var wd: Dictionary = dv if dv is Dictionary else {}
			dmg[id] = float(dmg[id]) + float(wd.get("dmg", 0))
	var mx: float = maxf(dmg["great_axe"], maxf(dmg["staff"], dmg["longbow"]))
	if mx <= 1.0:
		return
	if dmg["staff"] < mx * 0.55:
		pt.coefs["staff_damage"] = maxf(float(pt.coefs.get("staff_damage", 0.0)), 0.35)
	if dmg["longbow"] < mx * 0.55:
		pt.coefs["bow_damage"] = maxf(float(pt.coefs.get("bow_damage", 0.0)), 0.35)
	if dmg["great_axe"] < mx * 0.55:
		pt.coefs["axe_damage"] = maxf(float(pt.coefs.get("axe_damage", 0.0)), 0.35)


static func cfg_proxy(key: String, row: Dictionary) -> float:
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


static func corr(xs: Array, ys: Array) -> float:
	var n: int = mini(xs.size(), ys.size())
	if n < 3:
		return 0.0
	var mx: float = 0.0
	var my: float = 0.0
	for i: int in n:
		mx += float(xs[i])
		my += float(ys[i])
	mx /= float(n)
	my /= float(n)
	var num: float = 0.0
	var dx: float = 0.0
	var dy: float = 0.0
	for i2: int in n:
		var a: float = float(xs[i2]) - mx
		var b: float = float(ys[i2]) - my
		num += a * b
		dx += a * a
		dy += b * b
	if dx < 0.0001 or dy < 0.0001:
		return 0.0
	return clampf(num / sqrt(dx * dy), -1.0, 1.0)


static func build_recs(pt: Node) -> void:
	var base: Dictionary = {
		"axe_damage": App.bal.axe_damage,
		"staff_damage": App.bal.staff_damage,
		"bow_damage": App.bal.bow_damage,
		"enemy_hp_mult": App.bal.enemy_hp_mult,
		"mine_chance": App.bal.mine_chance,
		"move_speed": App.bal.move_speed,
	}
	var avg: float = (float(base.axe_damage) + float(base.staff_damage) + float(base.bow_damage)) / 3.0
	var staff_n: float = avg * 0.55
	var bow_n: float = avg * 0.8
	if float(pt.coefs.get("staff_damage", 0.0)) > 0.2:
		staff_n = avg * 0.7
	if float(pt.coefs.get("bow_damage", 0.0)) > 0.2:
		bow_n = avg * 0.9
	pt.recs["fresh"] = [
		{"label": "Ideal — first extraction", "cfg": pt._merge(base, {"enemy_hp_mult": float(base.enemy_hp_mult) * 0.85, "mine_chance": pt.mini_f(0.9, float(base.mine_chance) + 0.1), "move_speed": float(base.move_speed) * 1.05})},
		{"label": "Alt A — safer combat", "cfg": pt._merge(base, {"enemy_hp_mult": float(base.enemy_hp_mult) * 0.9, "axe_damage": avg})},
		{"label": "Alt B — gather lean", "cfg": pt._merge(base, {"mine_chance": pt.mini_f(0.95, float(base.mine_chance) + 0.15)})},
	]
	pt.recs["progressed"] = [
		{"label": "Ideal — weapon balance", "cfg": pt._merge(base, {"axe_damage": avg, "staff_damage": staff_n, "bow_damage": bow_n})},
		{"label": "Alt A — later floors", "cfg": pt._merge(base, {"enemy_hp_mult": float(base.enemy_hp_mult) * 1.1, "cycle_hp": App.bal.cycle_hp})},
		{"label": "Alt B — keep current", "cfg": base.duplicate()},
	]


static func merge(base: Dictionary, extra: Dictionary) -> Dictionary:
	var o: Dictionary = base.duplicate()
	for k: Variant in extra.keys():
		o[k] = extra[k]
	return o


static func snap_bal() -> Dictionary:
	var d: Dictionary = {}
	for row: Variant in App.bal.schema():
		d[str(row[0])] = App.bal.getv(str(row[0]))
	return d


static func restore_bal(d: Dictionary) -> void:
	for k: Variant in d.keys():
		App.bal.setv(str(k), float(d[k]))


static func format_summary(pt: Node) -> String:
	var s: String = "Playtest  ·  rows %d  ·  queue %d\n" % [pt.history.size(), pt.queue.size()]
	s += "Coefs: "
	for k: Variant in pt.coefs.keys():
		s += "%s=%.2f  " % [k, float(pt.coefs[k])]
	s += "\nFresh recs: "
	for r: Variant in pt.recs["fresh"]:
		s += str(r.label) + " | "
	s += "\nProgressed recs: "
	for r2: Variant in pt.recs["progressed"]:
		s += str(r2.label) + " | "
	s += "\n" + pt.success_report()
	return s


static func success_report(pt: Node) -> String:
	if pt.history.is_empty():
		return "Success: no rows."
	var extract_t: float = 9999.0
	var drain: bool = true
	var wpn_kills: Dictionary = {"great_axe": 0.0, "staff": 0.0, "longbow": 0.0}
	for row: Variant in pt.history:
		if str(row.get("end_cond", "")) == "extraction":
			extract_t = minf(extract_t, float(row.get("duration", 9999.0)))
		if not bool(row.get("recap_drain", false)):
			drain = false
		var wv: Variant = row.get("wpn", {})
		var w: Dictionary = wv if wv is Dictionary else {}
		for id: String in wpn_kills.keys():
			var dv: Variant = w.get(id, {})
			var wd: Dictionary = dv if dv is Dictionary else {}
			wpn_kills[id] = float(wpn_kills[id]) + float(wd.get("kills", 0))
	var mx: float = maxf(wpn_kills["great_axe"], maxf(wpn_kills["staff"], wpn_kills["longbow"]))
	var mn: float = minf(wpn_kills["great_axe"], minf(wpn_kills["staff"], wpn_kills["longbow"]))
	var bal_ok: bool = mx <= 0.001 or (mn / maxf(0.001, mx)) >= 0.45
	var t_ok: bool = extract_t <= 600.0
	return "SuccessCriterion extract_s=%.1f t_ok=%s recap=%s weapons_bal=%s" % [extract_t, str(t_ok), str(drain), str(bal_ok)]


static func save_history(pt: Node) -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("user://playtest"))
	var f: FileAccess = FileAccess.open("user://playtest/history.json", FileAccess.WRITE)
	if f:
		f.store_string(JSON.stringify(pt.history))


static func load_history(pt: Node) -> void:
	if not FileAccess.file_exists("user://playtest/history.json"):
		return
	var f: FileAccess = FileAccess.open("user://playtest/history.json", FileAccess.READ)
	if f == null:
		return
	var parsed: Variant = JSON.parse_string(f.get_as_text())
	if parsed is Array:
		pt.history = parsed


static func save_coefs(pt: Node) -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("user://playtest"))
	var f: FileAccess = FileAccess.open("user://playtest/coefs.json", FileAccess.WRITE)
	if f:
		f.store_string(JSON.stringify(pt.coefs))


static func load_coefs(pt: Node) -> void:
	if not FileAccess.file_exists("user://playtest/coefs.json"):
		return
	var f: FileAccess = FileAccess.open("user://playtest/coefs.json", FileAccess.READ)
	if f == null:
		return
	var parsed: Variant = JSON.parse_string(f.get_as_text())
	if parsed is Dictionary:
		pt.coefs = parsed
