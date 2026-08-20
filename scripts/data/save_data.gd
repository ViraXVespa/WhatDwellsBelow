class_name SaveData
extends RefCounted

const SkillMath := preload("res://scripts/data/skills.gd")

const PATH := "user://wdb_save.json"
const HOLD_KEYS := ["great_axe", "pickaxe", "potion", "head", "body", "legs"]

var mining_xp: float = 0.0
var smithing_xp: float = 0.0
var great_axe_xp: float = 0.0
var strength_xp: float = 0.0
var defense_xp: float = 0.0
var hitpoints_xp: float = 0.0
var gold: int = 0
var banked_ore: int = 0
var banked_bars: int = 0
var deepest_floor: int = 1
var recipes: Array = []
var holds: Dictionary = {}
var extra_food: int = 0
var extra_potion: int = 0
var has_dived: bool = false
var music_vol: float = 0.7
var sfx_vol: float = 0.85
var cam_zoom: float = 1.0


func _init() -> void:
	_ensure_holds()


func _ensure_holds() -> void:
	for k in HOLD_KEYS:
		if not holds.has(k) or not (holds[k] is Array):
			holds[k] = []


static func load_or_create() -> SaveData:
	if FileAccess.file_exists(PATH):
		var f := FileAccess.open(PATH, FileAccess.READ)
		if f:
			var json := JSON.new()
			if json.parse(f.get_as_text()) == OK and json.data is Dictionary:
				return from_dict(json.data)
	var s := SaveData.new()
	s._seed_starters()
	s.restock_if_broke()
	s.write()
	return s


func _seed_kit() -> void:
	_ensure_holds()
	if (holds["great_axe"] as Array).is_empty():
		(holds["great_axe"] as Array).append(ItemData.make_starter_axe())
	if (holds["pickaxe"] as Array).is_empty():
		(holds["pickaxe"] as Array).append(ItemData.make_starter_pickaxe())


func _seed_starters() -> void:
	_seed_kit()
	if (holds["potion"] as Array).is_empty():
		(holds["potion"] as Array).append(ItemData.make_potion())


func write() -> void:
	var f := FileAccess.open(PATH, FileAccess.WRITE)
	if f:
		f.store_string(JSON.stringify(to_dict(), "  "))


func to_dict() -> Dictionary:
	var rec: Array = []
	for it in recipes:
		rec.append((it as ItemData).to_dict())
	var h := {}
	for k in HOLD_KEYS:
		var arr: Array = []
		for it in holds.get(k, []):
			arr.append((it as ItemData).to_dict())
		h[k] = arr
	return {
		"mining_xp": mining_xp,
		"smithing_xp": smithing_xp,
		"great_axe_xp": great_axe_xp,
		"strength_xp": strength_xp,
		"defense_xp": defense_xp,
		"hitpoints_xp": hitpoints_xp,
		"gold": gold,
		"banked_ore": banked_ore,
		"banked_bars": banked_bars,
		"deepest_floor": deepest_floor,
		"recipes": rec,
		"holds": h,
		"extra_food": extra_food,
		"extra_potion": extra_potion,
		"has_dived": has_dived,
		"music_vol": music_vol,
		"sfx_vol": sfx_vol,
		"cam_zoom": cam_zoom,
	}


static func from_dict(d: Dictionary) -> SaveData:
	var s := SaveData.new()
	s.mining_xp = float(d.get("mining_xp", 0))
	s.smithing_xp = float(d.get("smithing_xp", 0))
	s.great_axe_xp = float(d.get("great_axe_xp", 0))
	s.strength_xp = float(d.get("strength_xp", 0))
	s.defense_xp = float(d.get("defense_xp", 0))
	s.hitpoints_xp = float(d.get("hitpoints_xp", 0))
	s.gold = int(d.get("gold", 0))
	s.banked_ore = int(d.get("banked_ore", 0))
	s.banked_bars = int(d.get("banked_bars", 0))
	s.deepest_floor = int(d.get("deepest_floor", 1))
	s.extra_food = int(d.get("extra_food", 0))
	s.extra_potion = int(d.get("extra_potion", 0))
	s.has_dived = bool(d.get("has_dived", false))
	s.music_vol = clampf(float(d.get("music_vol", 0.7)), 0.0, 1.0)
	s.sfx_vol = clampf(float(d.get("sfx_vol", 0.85)), 0.0, 1.0)
	s.cam_zoom = clampf(float(d.get("cam_zoom", 1.0)), 1.0, 1.75)
	s._ensure_holds()
	for row in d.get("recipes", []):
		if row is Dictionary:
			s.recipes.append(ItemData.from_dict(row))
	if d.has("holds") and d.holds is Dictionary:
		for k in HOLD_KEYS:
			var arr: Array = []
			for row in d.holds.get(k, []):
				if row is Dictionary:
					var it := ItemData.from_dict(row)
					it.forged = true
					arr.append(it)
			s.holds[k] = arr
	else:
		_migrate_old(s, d)
	s._seed_kit()
	s.restock_if_broke()
	return s


static func _migrate_old(s: SaveData, d: Dictionary) -> void:
	for row in d.get("analyzed_axes", []):
		if row is Dictionary:
			var it := ItemData.from_dict(row)
			if it.forged:
				(s.holds["great_axe"] as Array).append(it)
			else:
				s.recipes.append(it)
	for row in d.get("analyzed_pickaxes", []):
		if row is Dictionary:
			var it := ItemData.from_dict(row)
			if it.forged:
				(s.holds["pickaxe"] as Array).append(it)
			else:
				s.recipes.append(it)


func family_unlocked(family: String) -> bool:
	for it in recipes:
		if it.family == family or it.hold_key() == family:
			return true
	return false


func holds_of(key: String) -> Array:
	_ensure_holds()
	if not holds.has(key):
		holds[key] = []
	return holds[key]


func add_recipe(it: ItemData) -> void:
	if it == null:
		return
	var copy := it.duplicate_item()
	copy.forged = false
	recipes.append(copy)


func destroy_hold(key: String, index: int) -> ItemData:
	var list := holds_of(key)
	if index < 0 or index >= list.size():
		return null
	var it: ItemData = list[index]
	list.remove_at(index)
	return it


func add_hold(it: ItemData) -> bool:
	if it == null:
		return false
	var key := it.hold_key()
	var list := holds_of(key)
	if list.size() >= 3:
		return false
	var copy := it.duplicate_item()
	copy.forged = true
	copy.forged_once = true
	var sm: float = SkillMath.smith_out_mult(SkillMath.level_from_xp(smithing_xp))
	if copy.kind == ItemData.Kind.WEAPON:
		copy.damage *= sm
	if copy.kind == ItemData.Kind.ARMOR:
		copy.defense *= sm
	if copy.kind == ItemData.Kind.TOOL:
		copy.gather_mult *= sm
	if copy.kind == ItemData.Kind.POTION:
		copy.heal *= sm
	list.append(copy)
	return true


func xp_of(skill: String) -> float:
	match skill:
		"mining":
			return mining_xp
		"smithing":
			return smithing_xp
		"great_axe":
			return great_axe_xp
		"strength":
			return strength_xp
		"defense":
			return defense_xp
		"hitpoints":
			return hitpoints_xp
		_:
			return 0.0


func add_xp(skill: String, n: float) -> void:
	match skill:
		"mining":
			mining_xp += n
		"smithing":
			smithing_xp += n
		"great_axe":
			great_axe_xp += n
		"strength":
			strength_xp += n
		"defense":
			defense_xp += n
		"hitpoints":
			hitpoints_xp += n


func restock_if_broke() -> void:
	# Cushion is 3 rations + 1 potion. Stall is 5g/ration and 15g/potion.
	# If you're short of the mins and can't afford to buy the missing amount, fill it free.
	extra_food = clampi(extra_food, 0, 20)
	var missing_food := maxi(0, 3 - extra_food)
	if missing_food > 0 and gold < missing_food * 5:
		extra_food = 3
	var pots := holds_of("potion")
	if pots.is_empty() and gold < 15:
		pots.append(ItemData.make_potion())
