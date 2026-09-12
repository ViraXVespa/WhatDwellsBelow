extends Object

## Interaction handlers for world interactables.

const InteractFx := preload("res://scripts/world/interact_fx.gd")
const Prompt := preload("res://scripts/world/interact_prompt.gd")
const Chest := preload("res://scripts/world/interact_chest.gd")


static func interact(host: Node3D, who: Node) -> String:
	if App.ui_open:
		return ""
	Prompt.refresh(host)
	if host.hidden:
		return ""
	if host.locked:
		host.pending = false
		return host.prompt
	if host.kind == "loadout_crystal":
		var ui := ui_node(host)
		if ui and ui.has_method("open_loadout"):
			ui.open_loadout()
		return "Choose your loadout."
	if host.kind == "anvil":
		var ui := ui_node(host)
		if ui and ui.has_method("open_anvil"):
			ui.open_anvil()
		return "The anvil waits."
	if host.kind == "quest_board" or host.kind == "receptionist":
		var ui := ui_node(host)
		if ui and ui.has_method("open_quest"):
			ui.open_quest()
		return "The guild has work."
	if host.kind == "vendor":
		var ui := ui_node(host)
		if ui and ui.has_method("open_vendor"):
			ui.open_vendor()
		return "Wares in the sun."
	if host.kind == "dumpster":
		var ui := ui_node(host)
		if ui and ui.has_method("open_flavor"):
			ui.open_flavor("Dumpster", "You used to eat from this. Career upgrade pending.")
		else:
			App.toast("You used to eat from this. Career upgrade pending.")
		return "You used to eat from this. Career upgrade pending."
	if host.kind == "billboard":
		var ui := ui_node(host)
		if ui and ui.has_method("open_controls"):
			ui.open_controls()
		return "The painted list."
	if host.kind == "quest_item":
		App.prog.note_fetch()
		host.used = true
		App.toast("Cache recovered.")
		host.queue_free()
		return "The guild cache is yours."
	if host.kind == "stairs":
		if not host.pending:
			host.pending = true
			return "Confirm descend to F%d" % (App.floor_n + 1)
		host.pending = false
		App.next_floor()
		return ""
	if host.kind == "shrine":
		return shrine(host)
	if host.kind == "campfire":
		return campfire(host, who)
	if host.kind == "extract_gate":
		return open_extract_gate(host)
	if host.kind == "shop":
		return open_shop(host)
	if host.kind == "lever":
		toggle_gates(host)
		App.sfx("ui")
		App.toast("The gate shifts.")
		return "The gate answers."
	if host.kind.ends_with("chest"):
		return Chest.open_chest(host)
	return host.prompt


static func unlock_hidden(host: Node3D) -> void:
	host.hidden = false
	host.visible = true
	if host.spr:
		host.spr.visible = true
	Prompt.refresh(host)
	host.add_to_group("interact")


static func hide_as_secret(host: Node3D) -> void:
	host.hidden = true
	if host.spr:
		host.spr.visible = false
	if host.label:
		host.label.visible = false
	host.remove_from_group("interact")


static func shrine(host: Node3D) -> String:
	if host.used:
		return host.prompt
	host.used = true
	App.shrine_t = App.bal.shrine_time
	App.sfx("warcry")
	App.toast("Damage up.")
	Prompt.refresh(host)
	return "A blessing takes hold."


static func campfire(host: Node3D, who: Node) -> String:
	if host.used:
		return host.prompt
	host.used = true
	if who and who.has_method("heal"):
		who.heal(App.bal.player_max_hp * App.bal.campfire_heal)
	App.sfx("pickup")
	App.toast("Warmth returns.")
	Prompt.refresh(host)
	return "You sit. HP restored."


static func open_extract_gate(host: Node3D) -> String:
	if host.used:
		return host.prompt
	App.note_clerk()
	var ui := ui_node(host)
	if ui and ui.has_method("open_extract"):
		ui.open_extract("gate", host)
	return "Feed the gate."


static func mark_spent(host: Node3D) -> void:
	host.used = true
	InteractFx.set_extract_tex(host, false)
	Prompt.refresh(host)


static func open_shop(host: Node3D) -> String:
	var ui := ui_node(host)
	if ui and ui.has_method("open_shop"):
		ui.open_shop(host)
	return "A pale shopkeep waits."


static func ui_node(host: Node3D) -> Node:
	var s := host.get_tree().current_scene
	if s and s.has_method("world_ui"):
		return s.world_ui()
	return null


static func toggle_gates(host: Node3D) -> void:
	for n in host.get_tree().get_nodes_in_group("gates"):
		if n != host and n.get("pair") == host.pair and n.has_method("set_open"):
			var next := not bool(n.get("latched"))
			n.latched = next
			n.set_open(next)


static func set_open(host: Node3D, v: bool) -> void:
	host.open = v
	if host.body:
		host.body.collision_layer = 0 if host.open else 1
		for c in host.body.get_children():
			if c is CollisionShape3D:
				(c as CollisionShape3D).disabled = host.open
	if host.spr:
		host.spr.modulate.a = 0.25 if host.open else 1.0
	Prompt.refresh(host)


static func plate_held(host: Node3D, on: bool) -> void:
	if host.kind != "plate":
		return
	for n in host.get_tree().get_nodes_in_group("gates"):
		if n.get("pair") == host.pair and n.has_method("set_open"):
			if on:
				n.set_open(true)
			elif not bool(n.get("latched")):
				n.set_open(false)


static func open_chest(host: Node3D) -> String:
	return Chest.open_chest(host)
