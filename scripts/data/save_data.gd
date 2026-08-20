class_name SaveData
extends RefCounted

const PATH := "user://wdb_save.json"

var mining_xp: float = 0.0
var smithing_xp: float = 0.0
var great_axe_xp: float = 0.0
var gold: int = 25
var banked_ore: int = 0
var banked_bars: int = 0
var deepest_floor: int = 1
var analyzed_axes: Array = []
var analyzed_pickaxes: Array = []
var extra_food: int = 0
var extra_potion: int = 0
var music_vol: float = 0.7
var sfx_vol: float = 0.85
var cam_zoom: float = 1.0


static func load_or_create() -> SaveData:
	if FileAccess.file_exists(PATH):
		var f := FileAccess.open(PATH, FileAccess.READ)
		if f:
			var json := JSON.new()
			if json.parse(f.get_as_text()) == OK and json.data is Dictionary:
				return from_dict(json.data)
	var s := SaveData.new()
	s.write()
	return s


func write() -> void:
	var f := FileAccess.open(PATH, FileAccess.WRITE)
	if f:
		f.store_string(JSON.stringify(to_dict(), "  "))


func to_dict() -> Dictionary:
	var axes: Array = []
	for it in analyzed_axes:
		axes.append((it as ItemData).to_dict())
	var picks: Array = []
	for it in analyzed_pickaxes:
		picks.append((it as ItemData).to_dict())
	return {
		"mining_xp": mining_xp,
		"smithing_xp": smithing_xp,
		"great_axe_xp": great_axe_xp,
		"gold": gold,
		"banked_ore": banked_ore,
		"banked_bars": banked_bars,
		"deepest_floor": deepest_floor,
		"analyzed_axes": axes,
		"analyzed_pickaxes": picks,
		"extra_food": extra_food,
		"extra_potion": extra_potion,
		"music_vol": music_vol,
		"sfx_vol": sfx_vol,
		"cam_zoom": cam_zoom,
	}


static func from_dict(d: Dictionary) -> SaveData:
	var s := SaveData.new()
	s.mining_xp = float(d.get("mining_xp", 0))
	s.smithing_xp = float(d.get("smithing_xp", 0))
	s.great_axe_xp = float(d.get("great_axe_xp", 0))
	s.gold = int(d.get("gold", 25))
	s.banked_ore = int(d.get("banked_ore", 0))
	s.banked_bars = int(d.get("banked_bars", 0))
	s.deepest_floor = int(d.get("deepest_floor", 1))
	s.extra_food = int(d.get("extra_food", 0))
	s.extra_potion = int(d.get("extra_potion", 0))
	s.music_vol = clampf(float(d.get("music_vol", 0.7)), 0.0, 1.0)
	s.sfx_vol = clampf(float(d.get("sfx_vol", 0.85)), 0.0, 1.0)
	s.cam_zoom = clampf(float(d.get("cam_zoom", 1.0)), 1.0, 1.75)
	for row in d.get("analyzed_axes", []):
		if row is Dictionary:
			s.analyzed_axes.append(ItemData.from_dict(row))
	for row in d.get("analyzed_pickaxes", []):
		if row is Dictionary:
			s.analyzed_pickaxes.append(ItemData.from_dict(row))
	return s


func stash_gear(it: ItemData) -> Array:
	var list: Array = analyzed_axes if it.family == "great_axe" else analyzed_pickaxes
	if list.size() < 3:
		list.append(it)
		return []
	return list


func overwrite_gear(it: ItemData, index: int) -> void:
	var list: Array = analyzed_axes if it.family == "great_axe" else analyzed_pickaxes
	if index >= 0 and index < list.size():
		list[index] = it
