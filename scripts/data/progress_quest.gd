extends Object

const Roll := preload("res://scripts/data/progress_quest_roll.gd")
const Prog := preload("res://scripts/data/progress_quest_prog.gd")
const Meta := preload("res://scripts/data/progress_quest_meta.gd")
const Restock := preload("res://scripts/data/progress_quest_restock.gd")


static func roll_quests(p: Object, keep_active: bool) -> void:
	Roll.roll_quests(p, keep_active)


static func accept_quest(p: Object, i: int) -> String:
	return Roll.accept_quest(p, i)


static func abandon_quest(p: Object) -> String:
	return Roll.abandon_quest(p)


static func note_kill(p: Object, type_id: String, named: String) -> void:
	Prog.note_kill(p, type_id, named)


static func note_fetch(p: Object) -> void:
	Prog.note_fetch(p)


static func quest_extract_ore(p: Object, n: int) -> void:
	Prog.quest_extract_ore(p, n)


static func try_complete(p: Object) -> void:
	Prog.try_complete(p)


static func unowned_gear(p: Object) -> Dictionary:
	return Prog.unowned_gear(p)


static func _starters_of(p: Object) -> Dictionary:
	return Meta.starters_of(p)


static func to_meta(p: Object) -> Dictionary:
	return Meta.to_meta(p)


static func from_meta(p: Object, d: Dictionary) -> void:
	Meta.from_meta(p, d)


static func restock(p: Object) -> String:
	return Restock.restock(p)
