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
var run_id := ""
var floors: Array = []
var floor_n := 0
var floor_dt := 0.0
var floor_dmg := 0.0
var floor_deaths := 0
var floor_near := 0
var changes: Array = []
var kill_delta: Dictionary = {}
var death_delta := 0
var death_delta_set := false
var _seq := 0

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
	floors = []
	floor_n = int(App.floor_n)
	floor_dt = 0.0
	floor_dmg = 0.0
	floor_deaths = 0
	floor_near = 0
	changes = []
	kill_delta = {}
	death_delta = 0
	death_delta_set = false
	_seq += 1
	run_id = "%d-%d" % [int(Time.get_unix_time_from_system()), _seq]

func _snap() -> Dictionary:
	var d := {}
	for row in App.bal.schema():
		d[str(row[0])] = App.bal.getv(str(row[0]))
	return d

func _w() -> Dictionary:
	return {"time": 0.0, "dmg": 0.0, "kills": 0, "deaths": 0, "spec": 0, "spec_hit": 0}

func tick(delta: float, fighting: bool) -> void:
	_sync_floor()
	duration += delta
	floor_dt += delta
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
	cycle = int((maxi(1, App.floor_n) - 1) / 5.0)

func note_damage_dealt(n: float, crit: bool) -> void:
	dmg_dealt += n
	if crit:
		crits += 1
	var key := App.weapon
	if wpn.has(key):
		wpn[key].dmg = float(wpn[key].dmg) + n

func note_damage_taken(n: float, hp: float, max_hp: float) -> void:
	if floor_n == 0:
		floor_n = int(App.floor_n)
	dmg_taken += n
	floor_dmg += n
	if max_hp > 0.0 and hp / max_hp <= App.bal.near_death_hp:
		near_death += 1
		floor_near += 1

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

func note_kill_levels(enemy_lv: int, player_lv: int) -> void:
	var gap: int = enemy_lv - player_lv
	var key: String = str(gap)
	kill_delta[key] = int(kill_delta.get(key, 0)) + 1

func note_death_levels(enemy_lv: int, player_lv: int) -> void:
	death_delta = enemy_lv - player_lv
	death_delta_set = true

func note_skill_change(id: String, before: int, after: int) -> void:
	changes.append({
		"phase": _phase(),
		"kind": "skill_lv",
		"id": id,
		"from": before,
		"to": after,
	})

func note_equip_changes(before: Array, after: Array) -> void:
	var prev: Dictionary = {}
	var nxt: Dictionary = {}
	for row: Variant in before:
		if row is Dictionary:
			prev[str(row.get("slot", ""))] = row
	for row: Variant in after:
		if row is Dictionary:
			nxt[str(row.get("slot", ""))] = row
	var seen: Dictionary = {}
	for key_v: Variant in prev.keys():
		seen[str(key_v)] = true
	for key_v: Variant in nxt.keys():
		seen[str(key_v)] = true
	for key_v: Variant in seen.keys():
		var slot_key: String = str(key_v)
		var left: Dictionary = prev.get(slot_key, {}) as Dictionary
		var right: Dictionary = nxt.get(slot_key, {}) as Dictionary
		if JSON.stringify(left) == JSON.stringify(right):
			continue
		if right.is_empty():
			changes.append({
				"phase": _phase(),
				"kind": "equip",
				"slot": slot_key,
				"ilvl": 0,
				"rarity": "",
				"affixes": [],
			})
			continue
		var piece: Dictionary = right.duplicate(true)
		piece["phase"] = _phase()
		piece["kind"] = "equip"
		changes.append(piece)

func note_end(cond: String, killer: String) -> void:
	end_cond = cond
	death_by = killer
	if cond == "death" or cond == "dispel":
		if floor_n == 0:
			floor_n = int(App.floor_n)
		floor_deaths += 1
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

func _phase() -> String:
	if App.in_dungeon:
		return "run"
	return "hub"

func _sync_floor() -> void:
	var n: int = int(App.floor_n)
	if floor_n == 0:
		floor_n = n
		return
	if n == floor_n:
		return
	floors.append(_open_floor())
	floor_dt = 0.0
	floor_dmg = 0.0
	floor_deaths = 0
	floor_near = 0
	floor_n = n

func _open_floor() -> Dictionary:
	return {
		"n": floor_n,
		"dt": floor_dt,
		"dmg_taken": floor_dmg,
		"deaths": floor_deaths,
		"near_death": floor_near,
	}

func floor_rows() -> Array:
	var rows: Array = floors.duplicate(true)
	if floor_n != 0:
		rows.append(_open_floor())
	return rows

func to_dict() -> Dictionary:
	var row: Dictionary = {
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
		"run_id": run_id,
		"floors": floor_rows(),
		"changes": changes.duplicate(true),
		"kill_delta": kill_delta.duplicate(),
	}
	if death_delta_set:
		row["death_delta"] = death_delta
	return row
