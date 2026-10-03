extends Object

## Interaction handlers for world interactables.

const InteractFx := preload("res://scripts/world/interact/interact_fx.gd")
const Prompt := preload("res://scripts/world/interact/interact_prompt.gd")

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
		return App.tr("interact_act.choose_your_loadout")
	if host.kind == "anvil":
		var ui := ui_node(host)
		if ui and ui.has_method("open_anvil"):
			ui.open_anvil()
		return App.tr("interact_act.the_anvil_waits")
	if host.kind == "quest_board" or host.kind == "receptionist":
		var ui := ui_node(host)
		if ui and ui.has_method("open_quest"):
			ui.open_quest()
		return App.tr("interact_act.the_guild_has_work")
	if host.kind == "vendor":
		var ui := ui_node(host)
		if ui and ui.has_method("open_vendor"):
			ui.open_vendor()
		return App.tr("interact_act.wares_in_the_sun")
	if host.kind == "dumpster":
		var ui := ui_node(host)
		if ui and ui.has_method("open_flavor"):
			ui.open_flavor(App.tr("interact_act.dumpster"), App.tr("common.you_used_to_eat_from"))
		else:
			App.toast(App.tr("common.you_used_to_eat_from"))
		return App.tr("common.you_used_to_eat_from")
	if host.kind == "billboard":
		var ui := ui_node(host)
		if ui and ui.has_method("open_controls"):
			ui.open_controls()
		return App.tr("interact_act.the_painted_list")
	if host.kind == "quest_item":
		App.prog.note_fetch()
		host.used = true
		App.toast(App.tr("interact_act.cache_recovered"))
		host.queue_free()
		return App.tr("interact_act.the_guild_cache_is_yours")
	if host.kind == "stairs":
		if not host.pending:
			host.pending = true
			return App.tr("interact_act.confirm_descend_to_f") % (App.floor_n + 1)
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
		App.toast(App.tr("common.the_gate_shifts"))
		return App.tr("interact_act.the_gate_answers")
	if host.kind.ends_with("chest"):
		return open_chest(host)
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
	App.toast(App.tr("interact_act.damage_up"))
	Prompt.refresh(host)
	return App.tr("interact_act.a_blessing_takes_hold")

static func campfire(host: Node3D, who: Node) -> String:
	if host.used:
		return host.prompt
	host.used = true
	if who and who.has_method("heal"):
		who.heal(App.bal.player_max_hp * App.bal.campfire_heal)
	App.sfx("pickup")
	App.toast(App.tr("interact_act.warmth_returns"))
	Prompt.refresh(host)
	return App.tr("interact_act.you_sit_hp_restored")

static func open_extract_gate(host: Node3D) -> String:
	if host.used:
		return host.prompt
	App.note_clerk()
	var ui := ui_node(host)
	if ui and ui.has_method("open_extract"):
		ui.open_extract("gate", host)
	return App.tr("interact_act.feed_the_gate")

static func mark_spent(host: Node3D) -> void:
	host.used = true
	InteractFx.set_extract_tex(host, false)
	Prompt.refresh(host)

static func open_shop(host: Node3D) -> String:
	var ui := ui_node(host)
	if ui and ui.has_method("open_shop"):
		ui.open_shop(host)
	return App.tr("interact_act.a_pale_shopkeep_waits")

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
	var was: bool = bool(host.get("pressed"))
	host.pressed = on
	if on and not was:
		toggle_gates(host)
		App.sfx("ui")
		App.toast(App.tr("common.the_gate_shifts"))

static func open_chest(host: Node3D) -> String:
	var ChestS: GDScript = load("res://scripts/world/interact/interact_chest.gd") as GDScript
	return ChestS.open_chest(host)
