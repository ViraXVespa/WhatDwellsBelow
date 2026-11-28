extends Object

const CatalogS := preload("res://scripts/data/catalog.gd")
const Affix := preload("res://scripts/data/affixes.gd")
const XpCurve := preload("res://scripts/data/progress_combat/xp_curve.gd")

## Timed food / potion bonus on one affix id (inventory.bag): food while it still heals, potion while its bonus timer runs.
static func consumable_bonus(p, key: String) -> float:
	var n := 0.0
	if p.food_t > 0.0 and p.food_bonus_id == key:
		n += p.food_bonus_amt
	if p.potion_bonus_t > 0.0 and p.potion_bonus_id == key:
		n += p.potion_bonus_amt
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
	var lines := App.tr("combat_xp.set") % [CatalogS.set_title(set_id), n, need]
	if n >= 2:
		lines += App.tr("combat_xp.active_line").format({"line": CatalogS.set_bonus_line(set_id, n)})
	else:
		lines += App.tr("combat_xp.bonus_from_2_pieces")
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
	if App.adrenaline:
		amt *= App.adrenaline_xp
	var before: int = int(XpCurve.skill_lv(p, id))
	p.skills_run[id] = float(p.skills_run.get(id, 0.0)) + amt
	if XpCurve.skill_lv(p, id) > before:
		App.sfx("level")
		App.toast(App.tr("common.level_up") % [id, XpCurve.skill_lv(p, id)])
		p._refresh_player_hp()
