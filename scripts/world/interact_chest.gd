extends Object

## Chest loot open for world interactables.

const Catalog := preload("res://scripts/data/catalog.gd")
const Prompt := preload("res://scripts/world/interact_prompt.gd")


static func open_chest(host: Node3D) -> String:
	if host.used:
		return "Empty."
	host.used = true
	var gold := int(App.bal.chest_gold_base) + randi() % maxi(1, int(App.bal.chest_gold_span))
	if host.kind == "chest":
		gold += int(App.bal.boss_chest_gold)
	App.gain_gold(gold)
	var art := ""
	var msg_gear := ""
	var give_art: bool = host.kind == "chest" or host.kind == "puzzle_chest" or (host.kind == "base_chest" and randf() < App.bal.chest_art)
	if host.kind == "chest":
		give_art = true
	if give_art:
		var rng := RandomNumberGenerator.new()
		rng.randomize()
		var pick: Array = Catalog.pick(rng, 1)
		if not pick.is_empty():
			var art_it: Dictionary = App.prog.make_artifact(str(pick[0].id))
			art = str(art_it.name)
			if not App.prog.add_item(art_it):
				App.spawn_floor_item(art_it, host.global_position)
	var rarity := "white"
	if host.kind == "chest":
		rarity = "blue" if randf() < App.bal.boss_blue_chance else "green"
	elif randf() < App.bal.chest_green_chance:
		rarity = "green"
	if host.kind == "chest" or randf() < App.bal.chest_gear_chance:
		var gear: Dictionary = App.prog.make_armor(["head", "body", "legs"][randi() % 3], rarity)
		if host.kind == "chest" and randf() < 0.5:
			gear = App.prog.make_weapon(["great_axe", "staff", "longbow"][randi() % 3], rarity)
		msg_gear = str(gear.name)
		if not App.prog.add_item(gear):
			App.spawn_floor_item(gear, host.global_position)
	App.sfx("pickup")
	Prompt.refresh(host)
	var msg := "+%dg" % gold
	if art != "":
		msg += "  ·  Artifact: " + art
	if msg_gear != "":
		msg += "  ·  " + msg_gear
	App.toast(msg)
	return msg
