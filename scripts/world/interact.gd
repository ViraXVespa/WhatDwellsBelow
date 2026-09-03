extends Node3D

const T := preload("res://scripts/data/tunables.gd")
const Catalog := preload("res://scripts/data/catalog.gd")
const InteractFx := preload("res://scripts/world/interact_fx.gd")

var kind := "crystal"
var locked := false
var pending := false
var prompt := ""
var spr: Sprite3D
var mesh: MeshInstance3D
var label: Label3D
var body: StaticBody3D
var pair := "puzzle"
var used := false
var hidden := false
var role := "gather"
var stock: Array = []
var bought := 0
var open := false
var latched := false


func setup(k: String, pos: Vector3, lock := false) -> void:
	kind = k
	locked = lock
	position = pos
	if kind != "gate":
		add_to_group("interact")
	else:
		add_to_group("gates")
	if kind == "plate":
		add_to_group("plates")
	InteractFx.build(self)
	InteractFx.add_label(self)
	refresh()


func setup_extract_gate(pos: Vector3) -> void:
	role = "gate"
	setup("extract_gate", pos)


func setup_clerk(role_id: String, pos: Vector3) -> void:
	setup_extract_gate(pos)


func setup_shop(pos: Vector3, rng: RandomNumberGenerator) -> void:
	setup("shop", pos)
	var lo := int(App.bal.shop_stock_min)
	var hi := int(App.bal.shop_stock_max)
	if hi < lo:
		hi = lo
	var n := rng.randi_range(lo, hi)
	stock = Catalog.pick(rng, n)


func refresh() -> void:
	if kind == "stairs":
		locked = not App.boss_dead
		prompt = "Locked. Defeat the guardian." if locked else "A: Descend  (again to confirm)"
	elif kind == "crystal":
		locked = not App.boss_dead
		prompt = "Locked until the floor is cleared." if locked else "A: Descend  (again to confirm)"
	elif kind == "loadout_crystal":
		locked = false
		prompt = "A: Loadout / enter dungeon"
	elif kind == "anvil":
		prompt = "A: Anvil"
	elif kind == "quest_board":
		prompt = "A: Guild tasks"
	elif kind == "receptionist":
		prompt = "A: Talk — guild work"
	elif kind == "vendor":
		prompt = "A: Vendor stall"
	elif kind == "dumpster":
		prompt = "A: Read the dumpster"
	elif kind == "billboard":
		prompt = "A: Controls Billboard"
	elif kind == "quest_item":
		prompt = "A: Take the guild cache"
	elif kind == "shrine":
		prompt = "Already used." if used else "A: Pray  (+%d%% dmg)" % int(App.bal.shrine_dmg * 100.0)
	elif kind == "campfire":
		prompt = "The fire is spent." if used else "A: Sit  (heal)"
	elif kind == "extract_gate":
		prompt = "Spent. The portal is dark." if used else "A: Extraction Gate"
	elif kind == "shop":
		prompt = "A: Ghost Shop"
	elif kind == "lever":
		prompt = "A: Pull lever"
	elif kind == "plate":
		prompt = "Stand to hold the gate"
	elif kind == "gate":
		prompt = ""
	elif kind.ends_with("chest"):
		if used:
			prompt = "Empty."
		elif hidden:
			prompt = ""
		else:
			prompt = "A: Open chest"
	else:
		prompt = "A: Interact"
	if label:
		label.text = _title()
		if hidden:
			label.visible = false
		label.modulate = Color(0.95, 0.75, 0.35) if locked or used else Color(0.75, 0.95, 0.85)


func _title() -> String:
	match kind:
		"stairs":
			return "STAIRS" if not locked else "LOCKED STAIRS"
		"crystal":
			return "FLOOR CRYSTAL"
		"loadout_crystal":
			return "FLOOR CRYSTAL"
		"anvil":
			return "ANVIL"
		"quest_board":
			return "NOTICE BOARD"
		"receptionist":
			return "RECEPTION"
		"vendor":
			return "VENDOR"
		"dumpster":
			return "DUMPSTER"
		"billboard":
			return "CONTROLS"
		"quest_item":
			return "QUEST CACHE"
		"chest":
			return "BOSS CHEST"
		"base_chest":
			return "CHEST"
		"puzzle_chest":
			return "CACHE"
		"shrine":
			return "SHRINE"
		"campfire":
			return "CAMPFIRE"
		"extract_gate":
			return "EXTRACTION GATE" if not used else "DEAD GATE"
		"shop":
			return "GHOST SHOP"
		"lever":
			return "LEVER"
		"plate":
			return "PLATE"
		"gate":
			return "GATE" if not open else "OPEN"
	return kind


func interact(who: Node) -> String:
	if App.ui_open:
		return ""
	refresh()
	if hidden:
		return ""
	if locked:
		pending = false
		return prompt
	if kind == "loadout_crystal":
		var ui := _ui()
		if ui and ui.has_method("open_loadout"):
			ui.open_loadout()
		return "Choose your loadout."
	if kind == "anvil":
		var ui := _ui()
		if ui and ui.has_method("open_anvil"):
			ui.open_anvil()
		return "The anvil waits."
	if kind == "quest_board" or kind == "receptionist":
		var ui := _ui()
		if ui and ui.has_method("open_quest"):
			ui.open_quest()
		return "The guild has work."
	if kind == "vendor":
		var ui := _ui()
		if ui and ui.has_method("open_vendor"):
			ui.open_vendor()
		return "Wares in the sun."
	if kind == "dumpster":
		var ui := _ui()
		if ui and ui.has_method("open_flavor"):
			ui.open_flavor("Dumpster", "You used to eat from this. Career upgrade pending.")
		else:
			App.toast("You used to eat from this. Career upgrade pending.")
		return "You used to eat from this. Career upgrade pending."
	if kind == "billboard":
		var ui := _ui()
		if ui and ui.has_method("open_controls"):
			ui.open_controls()
		return "The painted list."
	if kind == "quest_item":
		App.prog.note_fetch()
		used = true
		App.toast("Cache recovered.")
		queue_free()
		return "The guild cache is yours."
	if kind == "stairs" or kind == "crystal":
		if not pending:
			pending = true
			return "A again to descend to F%d" % (App.floor_n + 1)
		pending = false
		App.next_floor()
		return ""
	if kind == "shrine":
		return _shrine()
	if kind == "campfire":
		return _campfire(who)
	if kind == "extract_gate":
		return _open_extract_gate()
	if kind == "shop":
		return _open_shop()
	if kind == "lever":
		_toggle_gates()
		App.sfx("ui")
		App.toast("The gate shifts.")
		return "The gate answers."
	if kind.ends_with("chest"):
		return _open_chest()
	return prompt


func unlock_hidden() -> void:
	hidden = false
	visible = true
	if spr:
		spr.visible = true
	refresh()
	add_to_group("interact")


func hide_as_secret() -> void:
	hidden = true
	if spr:
		spr.visible = false
	if label:
		label.visible = false
	remove_from_group("interact")


func _shrine() -> String:
	if used:
		return prompt
	used = true
	App.shrine_t = App.bal.shrine_time
	App.sfx("warcry")
	App.toast("Damage up.")
	refresh()
	return "A blessing takes hold."


func _campfire(who: Node) -> String:
	if used:
		return prompt
	used = true
	if who and who.has_method("heal"):
		who.heal(App.bal.player_max_hp * App.bal.campfire_heal)
	App.sfx("pickup")
	App.toast("Warmth returns.")
	refresh()
	return "You sit. HP restored."


func _open_chest() -> String:
	if used:
		return "Empty."
	used = true
	var gold := int(App.bal.chest_gold_base) + randi() % maxi(1, int(App.bal.chest_gold_span))
	if kind == "chest":
		gold += int(App.bal.boss_chest_gold)
	App.gain_gold(gold)
	var art := ""
	var msg_gear := ""
	var give_art := kind == "chest" or kind == "puzzle_chest" or (kind == "base_chest" and randf() < App.bal.chest_art)
	if kind == "chest":
		give_art = true
	if give_art:
		var rng := RandomNumberGenerator.new()
		rng.randomize()
		var pick: Array = Catalog.pick(rng, 1)
		if not pick.is_empty():
			var art_it: Dictionary = App.prog.make_artifact(str(pick[0].id))
			art = str(art_it.name)
			if not App.prog.add_item(art_it):
				App.spawn_floor_item(art_it, global_position)
	var rarity := "white"
	if kind == "chest":
		rarity = "blue" if randf() < App.bal.boss_blue_chance else "green"
	elif randf() < App.bal.chest_green_chance:
		rarity = "green"
	if kind == "chest" or randf() < App.bal.chest_gear_chance:
		var gear: Dictionary = App.prog.make_armor(["head", "body", "legs"][randi() % 3], rarity)
		if kind == "chest" and randf() < 0.5:
			gear = App.prog.make_weapon(["great_axe", "staff", "longbow"][randi() % 3], rarity)
		msg_gear = str(gear.name)
		if not App.prog.add_item(gear):
			App.spawn_floor_item(gear, global_position)
	App.sfx("pickup")
	refresh()
	var msg := "+%dg" % gold
	if art != "":
		msg += "  ·  Artifact: " + art
	if msg_gear != "":
		msg += "  ·  " + msg_gear
	App.toast(msg)
	return msg


func _open_extract_gate() -> String:
	if used:
		return prompt
	App.note_clerk()
	var ui := _ui()
	if ui and ui.has_method("open_extract"):
		ui.open_extract("gate", self)
	return "Feed the gate."


func mark_spent() -> void:
	used = true
	InteractFx.set_extract_tex(self, false)
	refresh()


func _open_shop() -> String:
	var ui := _ui()
	if ui and ui.has_method("open_shop"):
		ui.open_shop(self)
	return "A pale shopkeep waits."


func _ui() -> Node:
	var s := get_tree().current_scene
	if s and s.has_method("world_ui"):
		return s.world_ui()
	return null


func _toggle_gates() -> void:
	for n in get_tree().get_nodes_in_group("gates"):
		if n != self and n.get("pair") == pair and n.has_method("set_open"):
			var next := not bool(n.get("latched"))
			n.latched = next
			n.set_open(next)


func set_open(v: bool) -> void:
	open = v
	if body:
		body.collision_layer = 0 if open else 1
		for c in body.get_children():
			if c is CollisionShape3D:
				(c as CollisionShape3D).disabled = open
	if spr:
		spr.modulate.a = 0.25 if open else 1.0
	refresh()


func plate_held(on: bool) -> void:
	if kind != "plate":
		return
	for n in get_tree().get_nodes_in_group("gates"):
		if n.get("pair") == pair and n.has_method("set_open"):
			if on:
				n.set_open(true)
			elif not bool(n.get("latched")):
				n.set_open(false)
