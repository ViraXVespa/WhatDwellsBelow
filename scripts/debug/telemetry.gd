extends RefCounted

## Capped Section 13 telemetry. One row per run.

var end_cond := ""
var duration := 0.0
var deepest := 1
var cycle := 0
var start_weapon := ""
var tool := ""
var char_type := ""
var clerk_t := -1.0
var extract_t := -1.0
var deaths_before_extract := 0
var recap_drain := false
var combat_t := 0.0
var out_t := 0.0
var in_combat := false
var near_death := 0
var dmg_dealt := 0.0
var dmg_taken := 0.0
var kills := 0
var death_by := ""
var dash_n := 0
var spec_n := 0
var spec_hit := 0
var adrenaline_n := 0
var adrenaline_t := 0.0
var crits := 0
var wpn: Dictionary = {}
var mine_hits := 0
var mine_ok := 0
var wood_hits := 0
var wood_ok := 0
var gather_t := 0.0
var gold_gained := 0
var gold_extracted := 0
var gold_lost := 0
var ore_extracted := 0
var wood_extracted := 0
var ore_lost := 0
var wood_lost := 0
var shop_buys := 0
var shop_spent := 0
var forge_n := 0
var playtest := false
var save_type := "human"
var cfg_hash := ""
var cfg: Dictionary = {}
var run_start := 0.0


func reset(save_kind: String, is_playtest: bool) -> void:
	end_cond = ""
	duration = 0.0
	deepest = 1
	cycle = 0
	start_weapon = App.weapon
	tool = App.prog.tool_type
	char_type = App.character_type
	clerk_t = -1.0
	extract_t = -1.0
	deaths_before_extract = 0
	recap_drain = false
	combat_t = 0.0
	out_t = 0.0
	in_combat = false
	near_death = 0
	dmg_dealt = 0.0
	dmg_taken = 0.0
	kills = 0
	death_by = ""
	dash_n = 0
	spec_n = 0
	spec_hit = 0
	adrenaline_n = 0
	adrenaline_t = 0.0
	crits = 0
	wpn = {
		"great_axe": _w(),
		"staff": _w(),
		"longbow": _w(),
	}
	mine_hits = 0
	mine_ok = 0
	wood_hits = 0
	wood_ok = 0
	gather_t = 0.0
	gold_gained = 0
	gold_extracted = 0
	gold_lost = 0
	ore_extracted = 0
	wood_extracted = 0
	ore_lost = 0
	wood_lost = 0
	shop_buys = 0
	shop_spent = 0
	forge_n = 0
	playtest = is_playtest
	save_type = save_kind
	cfg = _snap()
	cfg_hash = _hash()
	run_start = App.clock


func _snap() -> Dictionary:
	var d := {}
	for row in App.bal.schema():
		d[str(row[0])] = App.bal.getv(str(row[0]))
	return d


func _w() -> Dictionary:
	return {"time": 0.0, "dmg": 0.0, "kills": 0, "deaths": 0, "spec": 0, "spec_hit": 0}


func tick(delta: float, fighting: bool) -> void:
	duration += delta
	if fighting:
		combat_t += delta
		in_combat = true
	else:
		out_t += delta
		in_combat = false
	var key := App.weapon
	if wpn.has(key):
		wpn[key].time = float(wpn[key].time) + delta
	if App.adrenaline:
		adrenaline_t += delta
	deepest = maxi(deepest, App.floor_n)
	cycle = int((maxi(1, App.floor_n) - 1) / 5)


func note_damage_dealt(n: float, crit: bool) -> void:
	dmg_dealt += n
	if crit:
		crits += 1
	var key := App.weapon
	if wpn.has(key):
		wpn[key].dmg = float(wpn[key].dmg) + n


func note_damage_taken(n: float, hp: float, max_hp: float) -> void:
	dmg_taken += n
	if max_hp > 0.0 and hp / max_hp <= App.bal.near_death_hp:
		near_death += 1


func note_kill() -> void:
	kills += 1
	var key := App.weapon
	if wpn.has(key):
		wpn[key].kills = int(wpn[key].kills) + 1


func note_dash() -> void:
	dash_n += 1


func note_special(hit: bool) -> void:
	spec_n += 1
	var key := App.weapon
	if wpn.has(key):
		wpn[key].spec = int(wpn[key].spec) + 1
		if hit:
			spec_hit += 1
			wpn[key].spec_hit = int(wpn[key].spec_hit) + 1


func note_adrenaline() -> void:
	adrenaline_n += 1


func note_extract(g: int, o: int, w: int) -> void:
	if extract_t < 0.0:
		extract_t = duration
	gold_extracted += g
	ore_extracted += o
	wood_extracted += w


func note_end(cond: String, killer: String) -> void:
	end_cond = cond
	death_by = killer
	if cond == "death" or cond == "dispel":
		if extract_t < 0.0:
			deaths_before_extract += 1
		gold_lost += App.gold
		ore_lost += App.ore
		wood_lost += App.wood
		var key := App.weapon
		if wpn.has(key):
			wpn[key].deaths = int(wpn[key].deaths) + 1


func _hash() -> String:
	var s := ""
	for row in App.bal.schema():
		s += str(row[0]) + "=" + str(App.bal.getv(str(row[0]))) + ";"
	return str(s.hash())


func to_dict() -> Dictionary:
	return {
		"end_cond": end_cond,
		"duration": duration,
		"deepest": deepest,
		"cycle": cycle,
		"start_weapon": start_weapon,
		"tool": tool,
		"char_type": char_type,
		"clerk_t": clerk_t,
		"extract_t": extract_t,
		"deaths_before_extract": deaths_before_extract,
		"recap_drain": recap_drain,
		"combat_t": combat_t,
		"out_t": out_t,
		"near_death": near_death,
		"dmg_dealt": dmg_dealt,
		"dmg_taken": dmg_taken,
		"kills": kills,
		"death_by": death_by,
		"dash_n": dash_n,
		"spec_n": spec_n,
		"spec_hit": spec_hit,
		"adrenaline_n": adrenaline_n,
		"adrenaline_t": adrenaline_t,
		"crits": crits,
		"wpn": wpn.duplicate(true),
		"mine_hits": mine_hits,
		"mine_ok": mine_ok,
		"wood_hits": wood_hits,
		"wood_ok": wood_ok,
		"gather_t": gather_t,
		"gold_gained": gold_gained,
		"gold_extracted": gold_extracted,
		"gold_lost": gold_lost,
		"ore_extracted": ore_extracted,
		"wood_extracted": wood_extracted,
		"ore_lost": ore_lost,
		"wood_lost": wood_lost,
		"shop_buys": shop_buys,
		"shop_spent": shop_spent,
		"forge_n": forge_n,
		"playtest": playtest,
		"save_type": save_type,
		"cfg_hash": cfg_hash,
		"cfg": cfg.duplicate(),
	}
