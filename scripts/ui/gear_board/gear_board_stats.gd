extends Object

const CatalogS := preload("res://scripts/data/catalog.gd")
const Affix := preload("res://scripts/data/affixes.gd")

const COMBAT_KEYS: PackedStringArray = [
	Affix.ID_DMG,
	Affix.ID_DEF,
	Affix.ID_HP,
	Affix.ID_CRIT_CHANCE,
	Affix.ID_CRIT_DMG,
	Affix.ID_ATK_SPD,
	Affix.ID_ATK_RANGE,
	Affix.ID_HP_HIT,
	Affix.ID_HP_KILL,
]
const UTIL_KEYS: PackedStringArray = [
	Affix.ID_MOVE,
	Affix.ID_GATHER_SPD,
	Affix.ID_GATHER_POW,
	Affix.ID_YIELD,
]


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
	var mode := str(ui.get("gear_mode"))
	if mode == "loadout" or mode == "anvil":
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
	var lines := PackedStringArray()
	for id: String in COMBAT_KEYS:
		_add_if(lines, id, _sum(id))
	for id: String in UTIL_KEYS:
		_add_if(lines, id, _sum(id))
	if lines.is_empty():
		return "No equipment bonuses on this kit."
	return "\n".join(lines)


static func all_block(keys: PackedStringArray) -> String:
	var lines := PackedStringArray()
	for id: String in keys:
		var v := _sum(id)
		if absf(v) < 0.001:
			lines.append("%s  —" % Affix.label_of(id))
		else:
			lines.append("%s  %s" % [Affix.label_of(id), Affix.format_value(id, v)])
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


static func _sum(id: String) -> float:
	if App.prog.has_method("gear_stat"):
		return float(App.prog.gear_stat(id))
	if id == Affix.ID_DMG and App.prog.has_method("gear_dmg"):
		return float(App.prog.gear_dmg())
	if id == Affix.ID_DEF and App.prog.has_method("gear_def"):
		return float(App.prog.gear_def())
	if id == Affix.ID_HP and App.prog.has_method("gear_hp"):
		return float(App.prog.gear_hp())
	return 0.0


static func _add_if(lines: PackedStringArray, id: String, v: float) -> void:
	if absf(v) < 0.001:
		return
	lines.append("%s  %s" % [Affix.label_of(id), Affix.format_value(id, v)])
