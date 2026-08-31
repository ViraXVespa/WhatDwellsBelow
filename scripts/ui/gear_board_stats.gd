extends Object

const CatalogS := preload("res://scripts/data/catalog.gd")

const COMBAT_KEYS := ["dmg", "def", "hp", "crit"]
const UTIL_KEYS := ["spd", "gather"]


static func title(ui: CanvasLayer) -> String:
	var pages := page_ids(ui)
	var idx := clampi(int(ui.get("gear_stat_page")), 0, pages.size() - 1)
	ui.gear_stat_page = idx
	return page_title(pages[idx])


static func body(ui: CanvasLayer) -> String:
	var pages := page_ids(ui)
	var idx := clampi(int(ui.get("gear_stat_page")), 0, pages.size() - 1)
	ui.gear_stat_page = idx
	match pages[idx]:
		"equipped":
			return equipped_only()
		"combat":
			return all_block(COMBAT_KEYS)
		"utility":
			return all_block(UTIL_KEYS)
		_:
			return artifact_block()


static func page(ui: CanvasLayer) -> String:
	return title(ui) + "\n" + body(ui)


static func page_ids(ui: CanvasLayer) -> PackedStringArray:
	if str(ui.get("gear_mode")) == "loadout":
		return PackedStringArray(["equipped", "combat", "utility"])
	return PackedStringArray(["equipped", "combat", "utility", "artifacts"])


static func page_title(id: String) -> String:
	match id:
		"equipped":
			return "Bonuses from this kit"
		"combat":
			return "All combat stats"
		"utility":
			return "All utility stats"
		_:
			return "Artifact sets"


static func equipped_only() -> String:
	var ss: Dictionary = App.prog.set_stats()
	var lines := PackedStringArray()
	_add_if(lines, "Damage", _gear("dmg", ss))
	_add_if(lines, "Defense", _gear("def", ss))
	_add_if(lines, "Max HP", _gear("hp", ss))
	_add_if(lines, "Crit", float(ss.get("crit", 0.0)))
	_add_if(lines, "Move", float(ss.get("spd", 0.0)))
	_add_if(lines, "Gather", float(ss.get("gather", 0.0)))
	if lines.is_empty():
		return "No equipment bonuses on this kit."
	return "\n".join(lines)


static func _gear(key: String, ss: Dictionary) -> float:
	if key == "dmg" and App.prog.has_method("gear_dmg"):
		return float(App.prog.gear_dmg())
	if key == "def" and App.prog.has_method("gear_def"):
		return float(App.prog.gear_def())
	if key == "hp" and App.prog.has_method("gear_hp"):
		return float(App.prog.gear_hp())
	var n := 0.0
	for s: String in App.prog.SLOTS:
		var it: Dictionary = App.prog.slots.get(s, {})
		if not it.is_empty():
			n += float(it.get(key, 0))
	n += float(ss.get(key, 0.0))
	return n


static func _add_if(lines: PackedStringArray, lab: String, v: float) -> void:
	if absf(v) < 0.001:
		return
	if absf(v - roundf(v)) < 0.05:
		lines.append("%s  %+d" % [lab, int(round(v))])
	else:
		lines.append("%s  %+.2f" % [lab, v])


static func all_block(keys: PackedStringArray) -> String:
	var ss: Dictionary = App.prog.set_stats()
	var lines := PackedStringArray()
	var labels := {"dmg": "Damage", "def": "Defense", "hp": "Max HP", "crit": "Crit", "spd": "Move", "gather": "Gather"}
	for k: String in keys:
		var v := float(ss.get(k, 0.0))
		if k == "dmg" or k == "def" or k == "hp":
			v = _gear(k, ss)
		lines.append("%s  %+.2f   (0 if nothing grants it)" % [str(labels.get(k, k)), v])
	return "\n".join(lines)


static func artifact_block() -> String:
	var counts: Dictionary = App.prog.set_counts()
	var lines := PackedStringArray()
	for sid: String in CatalogS.set_ids():
		var n := int(counts.get(sid, 0))
		if n <= 0:
			continue
		var bit := "%s  %d/%d" % [sid.capitalize(), n, CatalogS.set_size(sid)]
		if n >= 2:
			bit += "  —  " + CatalogS.set_bonus_line(sid, n)
		lines.append(bit)
	if lines.is_empty():
		return "No artifacts this run."
	return "\n".join(lines)
