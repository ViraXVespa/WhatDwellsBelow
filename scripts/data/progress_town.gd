extends Object

const Extract := preload("res://scripts/data/progress_extract.gd")
const Quest := preload("res://scripts/data/progress_quest.gd")
const ForgeP := preload("res://scripts/data/progress_forge.gd")


static func extractable(p: Object, role: String = "") -> Array:
	return Extract.extractable(p, role)


static func extract_all(p: Object, role: String) -> String:
	return Extract.extract_all(p, role)


static func extract_one(p: Object, it: Dictionary, role: String) -> String:
	return Extract.extract_one(p, it, role)


static func withdraw_bank_consumables(p: Object) -> void:
	Extract.withdraw_bank_consumables(p)


static func analyze_destroy(p: Object, row: Dictionary) -> Dictionary:
	var it: Dictionary = row.it.duplicate(true) if row.get("it") is Dictionary else {}
	if it.is_empty():
		return {}
	if not ForgeP.can_analyze(p, it):
		return {}
	var src := str(row.get("src", ""))
	var uid := int(row.get("uid", it.get("uid", 0)))
	if src == "hold" or src == "analyzed" or src == "starter":
		return {}
	var got: Dictionary = {}
	if src == "bag":
		got = p.remove_uid(uid)
	elif src == "bank":
		got = _take_bank(p, uid)
	elif src == "equipped":
		got = _take_equipped(p, it, uid)
	if got.is_empty():
		return {}
	ForgeP.grant(p, got)
	App.save_now()
	return got


static func _take_bank(p: Object, uid: int) -> Dictionary:
	for i: int in p.bank_items.size():
		if int(p.bank_items[i].uid) == uid:
			var got: Dictionary = p.bank_items[i]
			p.bank_items.remove_at(i)
			return got
	return {}


static func _take_equipped(p: Object, it: Dictionary, uid: int) -> Dictionary:
	var slot := str(it.get("slot", ""))
	var cur: Dictionary = p.slots.get(slot, {})
	if cur.is_empty() or int(cur.get("uid", 0)) != uid:
		return {}
	var copy: Dictionary = cur.duplicate(true)
	if slot == "weapon":
		p.slots["weapon"] = p.make_weapon(p.pick_weapon, "white")
		App.weapon = str(p.slots.weapon.get("weapon", p.pick_weapon))
	elif slot == "tool":
		p.slots["tool"] = p.make_tool(p.tool_type)
	else:
		p.slots[slot] = {}
	if p.has_method("_refresh_player_hp"):
		p._refresh_player_hp()
	return copy


static func roll_quests(p: Object, keep_active: bool) -> void:
	Quest.roll_quests(p, keep_active)


static func accept_quest(p: Object, i: int) -> String:
	return Quest.accept_quest(p, i)


static func abandon_quest(p: Object) -> String:
	return Quest.abandon_quest(p)


static func note_kill(p: Object, type_id: String, named: String) -> void:
	Quest.note_kill(p, type_id, named)


static func note_fetch(p: Object) -> void:
	Quest.note_fetch(p)


static func quest_extract_ore(p: Object, n: int) -> void:
	Quest.quest_extract_ore(p, n)


static func try_complete(p: Object) -> void:
	Quest.try_complete(p)


static func unowned_gear(p: Object) -> Dictionary:
	return Quest.unowned_gear(p)


static func to_meta(p: Object) -> Dictionary:
	return Quest.to_meta(p)


static func from_meta(p: Object, d: Dictionary) -> void:
	Quest.from_meta(p, d)


static func restock(p: Object) -> String:
	return Quest.restock(p)
