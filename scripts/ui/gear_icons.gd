# Inventory / loadout icon lookup. Rarity wash is color only; plates stay chroma-keyed art.
extends Object

const Fmt := preload("res://scripts/ui/gear_board_text_fmt.gd")

const DIR := "res://assets/ui/gear/"
const RISK := Color(0.86, 0.22, 0.18)

const EMPTY_PATHS := {
	"head": DIR + "slot_head.png",
	"body": DIR + "slot_body.png",
	"legs": DIR + "slot_legs.png",
	"potion": DIR + "slot_potion.png",
	"food": DIR + "slot_food.png",
}

const ITEM_PATHS := {
	"weapon:great_axe": DIR + "great_axe.png",
	"weapon:staff": DIR + "staff.png",
	"weapon:longbow": DIR + "longbow.png",
	"tool:pickaxe": DIR + "pickaxe.png",
	"tool:hatchet": DIR + "hatchet.png",
	"head": DIR + "head.png",
	"body": DIR + "body.png",
	"legs": DIR + "legs.png",
	"potion": DIR + "potion.png",
	"food:ration": DIR + "ration.png",
	"food:trail_bread": DIR + "trail_bread.png",
}

static var _cache: Dictionary = {}


static func tex_for_slot(slot: String, it: Dictionary) -> Texture2D:
	if it.is_empty():
		return _load_path(str(EMPTY_PATHS.get(slot, "")))
	var filled: Texture2D = tex_for_item(it)
	if filled != null:
		return filled
	return _load_path(str(EMPTY_PATHS.get(slot, "")))


static func tex_for_item(it: Dictionary) -> Texture2D:
	return _load_path(_item_path(it))


static func has_item_icon(it: Dictionary) -> bool:
	return _item_path(it) != ""


static func rarity_fill(it: Dictionary) -> Color:
	if it.is_empty():
		return Color(0.16, 0.13, 0.1)
	match str(it.get("rarity", "white")):
		"green":
			return Color(0.16, 0.28, 0.16)
		"blue":
			return Color(0.14, 0.2, 0.34)
		_:
			return Color(0.28, 0.24, 0.18)


static func rarity_border(it: Dictionary) -> Color:
	if _at_risk(it):
		return RISK
	if it.is_empty():
		return Color(0.4, 0.3, 0.18)
	match str(it.get("rarity", "white")):
		"green":
			return Color(0.35, 0.72, 0.34)
		"blue":
			return Color(0.4, 0.58, 0.95)
		_:
			return Color(0.78, 0.7, 0.48)


static func _at_risk(it: Dictionary) -> bool:
	return Fmt.is_risk(it)


static func _item_path(it: Dictionary) -> String:
	if it.is_empty():
		return ""
	var slot: String = str(it.get("slot", ""))
	var kind: String = str(it.get("kind", slot))
	if slot == "weapon" or kind == "weapon":
		return str(ITEM_PATHS.get("weapon:" + _weapon_key(it), ""))
	if slot == "tool" or kind == "tool":
		return str(ITEM_PATHS.get("tool:" + _tool_key(it), ""))
	if slot == "potion" or kind == "potion":
		return str(ITEM_PATHS.get("potion", ""))
	if slot == "food" or kind == "food":
		return str(ITEM_PATHS.get("food:" + _food_key(it), ""))
	if slot == "head" or kind == "head":
		return str(ITEM_PATHS.get("head", ""))
	if slot == "body" or kind == "body":
		return str(ITEM_PATHS.get("body", ""))
	if slot == "legs" or kind == "legs":
		return str(ITEM_PATHS.get("legs", ""))
	return ""


static func _weapon_key(it: Dictionary) -> String:
	var w: String = str(it.get("weapon", "")).to_lower()
	if w == "staff" or w == "longbow" or w == "great_axe":
		return w
	var n: String = str(it.get("name", "")).to_lower()
	if n.find("staff") >= 0:
		return "staff"
	if n.find("bow") >= 0:
		return "longbow"
	return "great_axe"


static func _tool_key(it: Dictionary) -> String:
	var t: String = str(it.get("tool", "")).to_lower()
	if t == "hatchet":
		return "hatchet"
	if t == "pickaxe" or t.find("pick") >= 0:
		return "pickaxe"
	var n: String = str(it.get("name", "")).to_lower()
	if n.find("hatchet") >= 0:
		return "hatchet"
	return "pickaxe"


static func _food_key(it: Dictionary) -> String:
	var f: String = str(it.get("food", "")).to_lower()
	if f == "ration":
		return "ration"
	if f == "trail_bread" or f == "bread":
		return "trail_bread"
	var n: String = str(it.get("name", "")).to_lower()
	if n.find("ration") >= 0:
		return "ration"
	return "trail_bread"


static func _load_path(path: String) -> Texture2D:
	if path == "":
		return null
	if _cache.has(path):
		return _cache[path] as Texture2D
	var res: Resource = load(path)
	var tex: Texture2D = res as Texture2D
	_cache[path] = tex
	return tex
