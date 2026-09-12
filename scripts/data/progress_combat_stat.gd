extends Object

const CatalogS := preload("res://scripts/data/catalog.gd")
const Affix := preload("res://scripts/data/affixes.gd")
const Xp := preload("res://scripts/data/progress_combat_xp.gd")

static func set_stats(p) -> Dictionary:
	var c := Xp.set_counts(p)
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

static func item_stat(it: Dictionary, key: String) -> float:
	if it.is_empty():
		return 0.0
	var want := key
	if key == "crit":
		want = Affix.ID_CRIT_CHANCE
	elif key == "spd":
		want = Affix.ID_MOVE
	elif key == "gather":
		want = Affix.ID_GATHER_SPD
	var n := 0.0
	var raw: Variant = it.get("affixes", [])
	var has_affix := raw is Array and not (raw as Array).is_empty()
	if has_affix:
		for row: Variant in raw:
			if not (row is Dictionary):
				continue
			var id := str(row.get("id", ""))
			if id == "crit":
				id = Affix.ID_CRIT_CHANCE
			elif id == "spd":
				id = Affix.ID_MOVE
			elif id == "gather":
				id = Affix.ID_GATHER_SPD
			if id == want:
				n += float(row.get("value", 0.0))
	else:
		n += float(it.get(want, 0.0))
		if want == Affix.ID_CRIT_CHANCE:
			n += float(it.get("crit", 0.0))
		elif want == Affix.ID_MOVE:
			n += float(it.get("spd", 0.0))
		elif want == Affix.ID_GATHER_SPD:
			n += float(it.get("gather", 0.0))
	var lv: int = maxi(1, int(it.get("ilvl", 1)))
	if Affix.kind_of(want) == Affix.KIND_PCT:
		return clampf(n, 0.0, (0.02 + 0.004 * float(lv)) * 1.25 * 1.25)
	return clampf(n, 0.0, (2.0 + 0.65 * float(lv)) * 1.25 * 1.25)

static func skill_grant_hit(p, is_special := false) -> void:
	if App.weapon == "staff":
		Xp.add_run_xp(p, "staff", App.bal.xp_hit_weapon)
		Xp.add_run_xp(p, "mag" if is_special else "str", App.bal.xp_hit_style)
		App.last_style = "mag" if is_special else "str"
	elif App.weapon == "longbow":
		Xp.add_run_xp(p, "bow", App.bal.xp_hit_weapon)
		Xp.add_run_xp(p, "rng", App.bal.xp_hit_style)
		App.last_style = "rng"
	else:
		Xp.add_run_xp(p, "axe", App.bal.xp_hit_weapon)
		Xp.add_run_xp(p, "str", App.bal.xp_hit_style)
		App.last_style = "str"

static func skill_dmg_mult(p, is_special := false) -> float:
	var _fac = load("res://scripts/data/progress_combat.gd")
	var wpn := "axe"
	var sty := "str"
	if App.weapon == "staff":
		wpn = "staff"
		sty = "mag" if is_special else "str"
	elif App.weapon == "longbow":
		wpn = "bow"
		sty = "rng"
	var m := 1.0
	m += float(maxi(0, _fac.skill_lv(p, wpn) - 1)) * App.bal.skill_dmg_weapon
	m += float(maxi(0, _fac.skill_lv(p, sty) - 1)) * App.bal.skill_dmg_style
	if is_special:
		m += float(maxi(0, _fac.skill_lv(p, wpn) - 1)) * App.bal.skill_special_bonus
	return m
