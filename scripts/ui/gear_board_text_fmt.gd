# Formatting helpers for gear items

const NAMES := {
	"weapon": "Weapon",
	"tool": "Tool",
	"potion": "Potion",
	"food": "Food",
	"head": "Head",
	"body": "Body",
	"legs": "Legs",
}


static func item_color(it: Dictionary) -> Color:
	if it.is_empty():
		return Color(0.62, 0.58, 0.52)
	if is_risk(it):
		return Color(0.95, 0.55, 0.38)
	match str(it.get("rarity", "white")):
		"green":
			return Color(0.55, 0.86, 0.52)
		"blue":
			return Color(0.52, 0.7, 1.0)
		_:
			if str(it.get("kind", "")) == "artifact":
				return Color(0.92, 0.78, 0.48)
			return Color(0.92, 0.84, 0.62)


static func is_risk(it: Dictionary) -> bool:
	if it.is_empty():
		return false
	if bool(it.get("hold", false)):
		return false
	if str(it.get("kit_src", "")) == "starter":
		return false
	if str(it.get("kit_src", "")) == "hold":
		return false
	if str(it.get("kind", "")) == "artifact":
		return true
	if str(it.get("kit_src", "")) == "bank":
		return true
	return not bool(it.get("hold", false)) and str(it.get("kit_src", "")) != ""


static func risk_mark(it: Dictionary, loadout: bool) -> String:
	if it.is_empty():
		return ""
	if bool(it.get("hold", false)) or str(it.get("kit_src", "")) == "hold":
		return "HOLD"
	if loadout and is_risk(it):
		return "AT RISK"
	return ""


static func _charges(it: Dictionary) -> int:
	if it.has("charges"):
		return int(it.charges)
	return int(it.get("stack", 0))


static func _charge_max(it: Dictionary) -> int:
	if it.has("charge_max"):
		return maxi(1, int(it.charge_max))
	if it.has("charges"):
		return maxi(1, int(it.charges))
	return maxi(1, int(it.get("stack", 1)))


static func _tmpl(it: Dictionary) -> String:
	var slot := str(it.get("slot", ""))
	if slot == "weapon":
		return "weapon:" + str(it.get("weapon", it.get("name", "")))
	if slot == "tool":
		return "tool:" + str(it.get("tool", ""))
	if slot == "potion":
		return "potion:" + str(it.get("name", "Potion"))
	return "%s:%s:%s" % [slot, str(it.get("name", "")), str(it.get("rarity", "white"))]
