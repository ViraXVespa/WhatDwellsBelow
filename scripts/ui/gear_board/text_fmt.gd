# Formatting helpers for gear items

const LocS := preload("res://scripts/app/app_loc.gd")
const Tok: GDScript = preload("res://scripts/ui/ui_tokens.gd")
const CatalogS := preload("res://scripts/data/catalog.gd")
static func slot_name(slot: String) -> String:
	return LocS.tr_or("slot." + slot, slot)

static func item_color(it: Dictionary) -> Color:
	if it.is_empty():
		return Color(0.45, 0.36, 0.28)
	if is_risk(it):
		return Color(0.55, 0.16, 0.11)
	var other: Color = Color(0.42, 0.24, 0.08) if str(it.get("kind", "")) == "artifact" else Tok.INK
	return by_rarity(it, _ITEM_TONE, other)

## Item text tone per rarity (white and unknown rarities use the caller's fallback).
const _ITEM_TONE := {"green": Color(0.16, 0.40, 0.14), "blue": Color(0.14, 0.26, 0.48)}

## tones[rarity] for item `it`, or `other` when its rarity has no entry. Gear text and icon frames share it.
static func by_rarity(it: Dictionary, tones: Dictionary, other: Color) -> Color:
	return tones.get(str(it.get("rarity", "white")), other)

static func is_risk(it: Dictionary) -> bool:
	if it.is_empty():
		return false
	if bool(it.get("hold", false)) or str(it.get("kit_src", "")) == "hold":
		return false
	if str(it.get("kit_src", "")) == "starter":
		return false
	if str(it.get("kind", "")) == "artifact":
		return false
	if str(it.get("slot", "")) == "potion" or str(it.get("slot", "")) == "food":
		return false
	if str(it.get("rarity", "white")) == "white":
		return false
	return true

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
		return "potion:" + str(it.get("uid", it.get("brew", "potion")))
	return "%s:%s:%s" % [slot, str(it.get("name", "")), str(it.get("rarity", "white"))]

static func item_cell(it: Dictionary) -> String:
	var nm: String = str(it.get("name", ""))
	if str(it.get("kind", "")) == "potion" or str(it.get("slot", "")) == "potion":
		return "%s\n%d/%d" % [nm, _charges(it), _charge_max(it)]
	var stack: int = int(it.get("stack", 1))
	if stack > 1:
		nm += "\nx%d" % stack
	elif bool(it.get("hold", false)):
		nm += "\n" + App.tr("text_fmt.hold")
	elif str(it.get("kind", "")) == "artifact":
		nm += "\n" + (CatalogS.set_title(str(it.get("set", ""))) if str(it.get("set", "")) != "" else App.tr("text_fmt.relic"))
	return nm
