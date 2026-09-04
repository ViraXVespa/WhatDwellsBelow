extends Object

const Make := preload("res://scripts/data/progress_make.gd")
const Rules := preload("res://scripts/data/gear_rules.gd")


static func required_ok(slot: String, it: Dictionary) -> bool:
	if it.is_empty() or str(it.get("slot", "")) != slot:
		return false
	if slot == "weapon":
		return Rules.BUILTIN_WEAPONS.find(str(it.get("weapon", ""))) >= 0
	if slot == "tool":
		return Rules.BUILTIN_TOOLS.find(str(it.get("tool", ""))) >= 0
	return false


static func required_piece(p: Object, slot: String) -> Dictionary:
	if slot != "weapon" and slot != "tool":
		return {}
	var h: Array = p.holds.get(slot, [])
	var pi := int(p.hold_pick.get(slot, -1))
	if pi >= 0 and pi < h.size() and h[pi] is Dictionary:
		var hold: Dictionary = (h[pi] as Dictionary).duplicate(true)
		if required_ok(slot, hold):
			return hold
	if slot == "weapon":
		var w := str(p.pick_weapon)
		if Rules.BUILTIN_WEAPONS.find(w) < 0:
			w = "great_axe"
		return Make.make_weapon(p, w, "white")
	var t := str(p.tool_type)
	if Rules.BUILTIN_TOOLS.find(t) < 0:
		t = "pickaxe"
	return Make.make_tool(p, t)


static func ensure_required_slots(p: Object) -> void:
	for slot in ["weapon", "tool"]:
		var cur: Dictionary = p.slots.get(slot, {})
		if not required_ok(slot, cur):
			p.slots[slot] = required_piece(p, slot)
		if slot == "weapon":
			_sync_weapon(p)


static func _sync_weapon(p: Object) -> void:
	var it: Dictionary = p.slots.get("weapon", {})
	App.weapon = str(it.get("weapon", p.pick_weapon))
	var pl: CharacterBody3D = p._player()
	if pl and pl.has_method("set_weapon"):
		pl.set_weapon(App.weapon)
