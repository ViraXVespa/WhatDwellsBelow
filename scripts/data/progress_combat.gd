extends Object

const CatalogS := preload("res://scripts/data/catalog.gd")


static func skill_xp(p, id: String) -> float:
	return float(p.skills_run.get(id, 0.0)) + float(p.skills_perm.get(id, 0.0))


static func skill_lv(p, id: String) -> int:
	return level_from_xp(p, skill_xp(p, id))


static func xp_period() -> float:
	return maxf(1.0, App.bal.xp_double_every)


static func xp_unit() -> float:
	return maxf(1.0, App.bal.xp_level)


static func xp_to_reach(level: int) -> float:
	var lv := maxi(1, level)
	if lv <= 1:
		return 0.0
	var period := xp_period()
	var unit := xp_unit()
	var r := pow(2.0, 1.0 / period)
	return unit * (pow(r, float(lv - 1)) - 1.0) / (r - 1.0)


static func level_from_xp(p, total: float) -> int:
	var t := maxf(0.0, total)
	var period := xp_period()
	var unit := xp_unit()
	var r := pow(2.0, 1.0 / period)
	var n := 1.0 + log(1.0 + t * (r - 1.0) / unit) / log(r)
	return maxi(1, int(n))


static func xp_to_next(p, total: float) -> float:
	var lv := level_from_xp(p, total)
	return maxf(0.0, xp_to_reach(lv + 1) - maxf(0.0, total))


static func xp_ratio(p, total: float) -> float:
	var lv := level_from_xp(p, total)
	var a := xp_to_reach(lv)
	var b := xp_to_reach(lv + 1)
	var span := b - a
	if span <= 0.0001:
		return 1.0
	return clampf((maxf(0.0, total) - a) / span, 0.0, 1.0)


static func add_run_xp(p, id: String, amt: float) -> void:
	if App.adrenaline:
		amt *= App.adrenaline_xp
	var before := skill_lv(p, id)
	p.skills_run[id] = float(p.skills_run.get(id, 0.0)) + amt
	if skill_lv(p, id) > before:
		App.sfx("level")
		App.toast("Level up — %s %d" % [id, skill_lv(p, id)])
		p._refresh_player_hp()


static func add_perm_xp(p, id: String, amt: float) -> void:
	var before := skill_lv(p, id)
	p.skills_perm[id] = float(p.skills_perm.get(id, 0.0)) + amt
	if skill_lv(p, id) > before:
		App.sfx("level")
		App.toast("Level up — %s %d" % [id, skill_lv(p, id)])


static func skill_dmg_mult(p, is_special := false) -> float:
	var wpn := "axe"
	var sty := "str"
	if App.weapon == "staff":
		wpn = "staff"
		sty = "mag" if is_special else "str"
	elif App.weapon == "longbow":
		wpn = "bow"
		sty = "rng"
	var m := 1.0
	m += float(maxi(0, skill_lv(p, wpn) - 1)) * App.bal.skill_dmg_weapon
	m += float(maxi(0, skill_lv(p, sty) - 1)) * App.bal.skill_dmg_style
	if is_special:
		m += float(maxi(0, skill_lv(p, wpn) - 1)) * App.bal.skill_special_bonus
	return m


static func skill_def(p) -> float:
	return float(maxi(0, skill_lv(p, "def") - 1)) * App.bal.skill_def_per_lv


static func skill_hp(p) -> float:
	return float(maxi(0, skill_lv(p, "hp") - 1)) * App.bal.skill_hp_per_lv


static func tool_quality(p) -> float:
	var it: Dictionary = p.slots.get("tool", {})
	if it.is_empty():
		return 1.0
	var q := 1.0
	var r := str(it.get("rarity", "white"))
	if r == "green":
		q = 2.0
	elif r == "blue":
		q = 3.0
	if bool(it.get("hold", false)):
		q += 1.0
	return q


static func skill_grant_hit(p, is_special := false) -> void:
	if App.weapon == "staff":
		add_run_xp(p, "staff", App.bal.xp_hit_weapon)
		add_run_xp(p, "mag" if is_special else "str", App.bal.xp_hit_style)
		App.last_style = "mag" if is_special else "str"
	elif App.weapon == "longbow":
		add_run_xp(p, "bow", App.bal.xp_hit_weapon)
		add_run_xp(p, "rng", App.bal.xp_hit_style)
		App.last_style = "rng"
	else:
		add_run_xp(p, "axe", App.bal.xp_hit_weapon)
		add_run_xp(p, "str", App.bal.xp_hit_style)
		App.last_style = "str"


static func keep_fragments(p) -> void:
	var keep: float = App.bal.xp_keep
	for id in p.SKILLS:
		p.skills_perm[id] = float(p.skills_perm.get(id, 0.0)) + float(p.skills_run.get(id, 0.0)) * keep
		p.skills_run[id] = 0.0


static func survive_pair(p) -> float:
	return float(skill_lv(p, "def") + skill_lv(p, "hp"))


static func combat_score(p, wpn: String, sty: String) -> float:
	return (float(skill_lv(p, wpn) + skill_lv(p, sty)) + survive_pair(p)) / 4.0


static func combat_iv(p, wpn: String, sty: String) -> int:
	return maxi(1, int(round(combat_score(p, wpn, sty))))


static func melee_lv_f(p) -> float:
	return combat_score(p, "axe", "str")


static func magic_lv_f(p) -> float:
	return combat_score(p, "staff", "mag")


static func ranged_lv_f(p) -> float:
	return combat_score(p, "bow", "rng")


static func combat_lv_f(p) -> float:
	return maxf(melee_lv_f(p), maxf(magic_lv_f(p), ranged_lv_f(p)))


static func style_lv_f(p) -> float:
	if App.weapon == "staff":
		return magic_lv_f(p)
	if App.weapon == "longbow":
		return ranged_lv_f(p)
	return melee_lv_f(p)


static func set_counts(p) -> Dictionary:
	var c := {}
	for s in p.SETS:
		c[s] = 0
	for it in p.bag:
		var sid := str(it.get("set", ""))
		if c.has(sid):
			c[sid] = int(c[sid]) + 1
	for s in p.SLOTS:
		var it: Dictionary = p.slots.get(s, {})
		var sid := str(it.get("set", ""))
		if c.has(sid):
			c[sid] = int(c[sid]) + 1
	return c


static func set_stats(p) -> Dictionary:
	var c := set_counts(p)
	var dmg := 0.0
	var def := 0.0
	var hp := 0.0
	var crit := 0.0
	var gather := 0.0
	var spd := 0.0
	if int(c.cinder) >= 1:
		dmg += App.bal.set_cinder_1 * int(c.cinder)
	if int(c.cinder) >= 2:
		dmg += App.bal.set_cinder_2
	if int(c.tide) >= 1:
		hp += App.bal.set_tide_1 * int(c.tide)
	if int(c.tide) >= 2:
		hp += App.bal.set_tide_2
	if int(c.root) >= 1:
		gather += App.bal.set_root_1 * int(c.root)
	if int(c.root) >= 2:
		gather += App.bal.set_root_2
	if int(c.root) >= 3:
		gather += App.bal.set_root_3
	if int(c.ash) >= 1:
		def += App.bal.set_ash_1 * int(c.ash)
	if int(c.ash) >= 2:
		def += App.bal.set_ash_2
	if int(c.ash) >= 3:
		def += App.bal.set_ash_3
	if int(c.spark) >= 1:
		crit += App.bal.set_spark_1 * int(c.spark)
	if int(c.spark) >= 2:
		crit += App.bal.set_spark_2
	if int(c.bone) >= 1:
		hp += App.bal.set_bone_1 * int(c.bone)
	if int(c.bone) >= 2:
		hp += App.bal.set_bone_2
	if int(c.bone) >= 3:
		hp += App.bal.set_bone_3
	if int(c.veil) >= 1:
		spd += App.bal.set_veil_1 * int(c.veil)
	if int(c.veil) >= 2:
		spd += App.bal.set_veil_2
	if int(c.veil) >= 3:
		spd += App.bal.set_veil_3
	if int(c.veil) >= 4:
		spd += App.bal.set_veil_4
	if int(c.iron) >= 1:
		def += App.bal.set_iron_1 * int(c.iron)
	if int(c.iron) >= 2:
		def += App.bal.set_iron_2
	if int(c.iron) >= 3:
		def += App.bal.set_iron_3
	if int(c.iron) >= 4:
		def += App.bal.set_iron_4
	if int(c.iron) >= 5:
		def += App.bal.set_iron_5
	return {"dmg": dmg, "def": def, "hp": hp, "crit": crit, "gather": gather, "spd": spd}


static func gear_stat(p, key: String) -> float:
	var n := 0.0
	for s in p.SLOTS:
		var it: Dictionary = p.slots.get(s, {})
		if not it.is_empty():
			n += float(it.get(key, 0))
	n += float(set_stats(p).get(key, 0.0))
	return n


static func set_bonus_text(p, set_id: String) -> String:
	var n: int = int(set_counts(p).get(set_id, 0))
	var need := CatalogS.set_size(set_id)
	var lines := "Set %s  %d/%d" % [set_id.capitalize(), n, need]
	if n >= 2:
		lines += "\nActive: " + CatalogS.set_bonus_line(set_id, n)
	else:
		lines += "\nBonus from 2 pieces."
	return lines


static func sync_artifacts(p) -> void:
	App.run_artifacts.clear()
	for it in p.bag:
		if str(it.kind) == "artifact":
			App.run_artifacts.append(str(it.id))


static func refresh_player_hp(p) -> void:
	var pl: Variant = p._player()
	if pl == null:
		return
	var maxh: float = App.bal.player_max_hp + p.gear_hp() + p.skill_hp()
	var old := float(pl.get("max_hp"))
	pl.set("max_hp", maxh)
	var cur := float(pl.get("hp"))
	if maxh > old:
		pl.set("hp", cur + (maxh - old))
	else:
		pl.set("hp", minf(cur, maxh))
