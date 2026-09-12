extends Object

const CatalogS := preload("res://scripts/data/catalog.gd")
const Affix := preload("res://scripts/data/affixes.gd")
static func gear_stat(p, key: String) -> float:
	var n := 0.0
	for s in p.SLOTS:
		var it: Dictionary = p.slots.get(s, {})
		if not it.is_empty():
			n += load("res://scripts/data/progress_combat_stat.gd").item_stat(it, key)
	var sets: Dictionary = load("res://scripts/data/progress_combat_stat.gd").set_stats(p)
	n += float(sets.get(key, 0.0))
	if key == Affix.ID_CRIT_CHANCE:
		n += float(sets.get("crit", 0.0))
	if key == Affix.ID_MOVE:
		n += float(sets.get("spd", 0.0))
	if key == Affix.ID_GATHER_SPD or key == Affix.ID_YIELD:
		n += float(sets.get("gather", 0.0))
	return n

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

static func set_bonus_text(p, set_id: String) -> String:
	var n: int = int(set_counts(p).get(set_id, 0))
	var need := CatalogS.set_size(set_id)
	var lines := "Set %s  %d/%d" % [set_id.capitalize(), n, need]
	if n >= 2:
		lines += "\nActive: " + CatalogS.set_bonus_line(set_id, n)
	else:
		lines += "\nBonus from 2 pieces."
	return lines

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

static func add_run_xp(p, id: String, amt: float) -> void:
	var _fac = load("res://scripts/data/progress_combat.gd")
	if App.adrenaline:
		amt *= App.adrenaline_xp
	var before := _fac.skill_lv(p, id)
	p.skills_run[id] = float(p.skills_run.get(id, 0.0)) + amt
	if _fac.skill_lv(p, id) > before:
		App.sfx("level")
		App.toast("Level up — %s %d" % [id, _fac.skill_lv(p, id)])
		p._refresh_player_hp()
