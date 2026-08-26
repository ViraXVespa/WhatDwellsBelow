extends Node3D

const T := preload("res://scripts/data/tunables.gd")
const Depth := preload("res://scripts/world/depth.gd")
const Catalog := preload("res://scripts/data/catalog.gd")

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
	_visual()
	_label()
	refresh()


func setup_clerk(role_id: String, pos: Vector3) -> void:
	role = role_id
	if role == "patty":
		setup("clerk_patty", pos)
	elif role == "misc":
		setup("clerk_misc", pos)
	else:
		setup("clerk_gather", pos)


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
	elif kind.begins_with("clerk"):
		prompt = "A: Extract with %s" % _title()
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
		"clerk_gather":
			return "GATHER CLERK"
		"clerk_misc":
			return "MISC CLERK"
		"clerk_patty":
			return "PACKMULE PATTY"
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
	if kind.begins_with("clerk"):
		return _open_clerk()
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


func _open_clerk() -> String:
	App.note_clerk()
	var ui := _ui()
	if ui and ui.has_method("open_extract"):
		ui.open_extract(role)
	elif ui and ui.has_method("open_clerk"):
		ui.open_clerk(role)
	return "Extract what you carried."


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


func _visual() -> void:
	if kind == "crystal" or kind == "loadout_crystal":
		mesh = MeshInstance3D.new()
		var pr := PrismMesh.new()
		pr.size = Vector3(0.55, 1.2, 0.55)
		mesh.mesh = pr
		mesh.position.y = 0.7
		var m := StandardMaterial3D.new()
		m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		m.albedo_color = Color(0.35, 0.9, 1.0)
		mesh.material_override = m
		add_child(mesh)
		return
	if kind == "stairs":
		_sprite("res://assets/sprites/props/stairs.png", 1.1, 0.45)
		if spr == null:
			mesh = MeshInstance3D.new()
			var box := BoxMesh.new()
			box.size = Vector3(1.1, 0.55, 1.1)
			mesh.mesh = box
			mesh.position.y = 0.28
			var m := StandardMaterial3D.new()
			m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
			m.albedo_color = Color(0.55, 0.45, 0.28)
			mesh.material_override = m
			add_child(mesh)
		return
	if kind == "gate":
		_sprite("res://assets/sprites/props/gate.png", 1.6, 0.85)
		body = StaticBody3D.new()
		body.collision_layer = 1
		body.collision_mask = 0
		add_child(body)
		var cs := CollisionShape3D.new()
		var sh := BoxShape3D.new()
		sh.size = Vector3(1.2, 1.6, 0.4)
		cs.shape = sh
		cs.position.y = 0.8
		body.add_child(cs)
		return
	if kind == "plate":
		_sprite("res://assets/sprites/props/plate.png", 0.7, 0.08)
		return
	var path := _tex_path()
	_sprite(path, _spr_h(), _spr_y())


func _tex_path() -> String:
	match kind:
		"anvil":
			return "res://assets/sprites/props/anvil.png"
		"quest_board":
			return "res://assets/sprites/props/notice_board.png"
		"receptionist":
			return "res://assets/sprites/npcs/receptionist.png"
		"vendor":
			return "res://assets/sprites/npcs/vendor.png"
		"dumpster":
			return "res://assets/sprites/props/dumpster.png"
		"billboard":
			return "res://assets/sprites/props/sign.png"
		"quest_item":
			return "res://assets/sprites/props/chest.png"
		"shrine":
			return "res://assets/sprites/props/shrine.png"
		"campfire":
			return "res://assets/sprites/props/campfire.png"
		"shop":
			return "res://assets/sprites/npcs/shopkeep.png"
		"clerk_gather":
			return "res://assets/sprites/npcs/miner.png"
		"clerk_misc":
			return "res://assets/sprites/npcs/vendor.png"
		"clerk_patty":
			return "res://assets/sprites/npcs/patty.png"
		"lever":
			return "res://assets/sprites/props/lever.png"
		"chest", "base_chest", "puzzle_chest":
			return "res://assets/sprites/props/chest.png"
	return "res://assets/props/sort_crate.png"


func _spr_h() -> float:
	if kind.begins_with("clerk") or kind == "shop" or kind == "receptionist" or kind == "vendor":
		return 1.55
	if kind == "campfire":
		return 0.9
	if kind == "shrine":
		return 1.2
	return 0.85


func _spr_y() -> float:
	if kind.begins_with("clerk") or kind == "shop" or kind == "receptionist" or kind == "vendor":
		return 0.78
	if kind == "plate":
		return 0.06
	return 0.48


func _sprite(path: String, h: float, y: float) -> void:
	spr = Sprite3D.new()
	spr.centered = true
	spr.shaded = false
	spr.billboard = BaseMaterial3D.BILLBOARD_FIXED_Y
	spr.alpha_cut = SpriteBase3D.ALPHA_CUT_OPAQUE_PREPASS
	spr.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	if ResourceLoader.exists(path):
		spr.texture = load(path)
		spr.pixel_size = h / float(maxi(1, spr.texture.get_height()))
	spr.position.y = y
	add_child(spr)
	Depth.apply(spr, position)


func _label() -> void:
	label = Label3D.new()
	label.position = Vector3(0.0, 1.55, 0.0)
	if kind == "plate":
		label.position.y = 0.7
	label.font_size = 36
	label.outline_size = 8
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.no_depth_test = true
	label.pixel_size = 0.011
	add_child(label)
