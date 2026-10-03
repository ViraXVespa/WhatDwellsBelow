extends Object

## Prompt / title refresh for world interactables.

static func refresh(host: Node3D) -> void:
	if host.kind == "stairs":
		host.locked = not App.boss_dead
		host.prompt = App.tr("interact_prompt.locked_defeat_the_guardian") if host.locked else App.tr("interact_prompt.descend")
	elif host.kind == "loadout_crystal":
		host.locked = false
		host.prompt = App.tr("interact_prompt.loadout_enter_dungeon")
	elif host.kind == "anvil":
		host.prompt = App.tr("common.anvil")
	elif host.kind == "quest_board":
		host.prompt = App.tr("interact_prompt.guild_tasks")
	elif host.kind == "receptionist":
		host.prompt = App.tr("interact_prompt.talk_guild_work")
	elif host.kind == "vendor":
		host.prompt = App.tr("interact_prompt.vendor_stall")
	elif host.kind == "dumpster":
		host.prompt = App.tr("interact_prompt.read_the_dumpster")
	elif host.kind == "billboard":
		host.prompt = App.tr("common.controls_billboard")
	elif host.kind == "quest_item":
		host.prompt = App.tr("interact_prompt.take_the_guild_cache")
	elif host.kind == "shrine":
		host.prompt = App.tr("interact_prompt.already_used") if host.used else App.tr("interact_prompt.pray_dmg") % int(App.bal.shrine_dmg * 100.0)
	elif host.kind == "campfire":
		host.prompt = App.tr("interact_prompt.the_fire_is_spent") if host.used else App.tr("interact_prompt.sit_heal")
	elif host.kind == "extract_gate":
		host.prompt = App.tr("interact_prompt.spent_the_portal_is_dark") if host.used else App.tr("common.extraction_gate")
	elif host.kind == "shop":
		host.prompt = App.tr("common.ghost_shop")
	elif host.kind == "lever":
		host.prompt = App.tr("interact_prompt.pull_lever")
	elif host.kind == "plate":
		host.prompt = App.tr("interact_prompt.step_the_plate")
	elif host.kind == "gate":
		host.prompt = ""
	elif host.kind.ends_with("chest"):
		if host.used:
			host.prompt = App.tr("common.empty")
		elif host.hidden:
			host.prompt = ""
		else:
			host.prompt = App.tr("interact_prompt.open_chest")
	else:
		host.prompt = App.tr("interact_prompt.interact")
	if host.label:
		host.label.text = title(host)
		if host.hidden:
			host.label.visible = false
		host.label.modulate = Color(0.95, 0.75, 0.35) if host.locked or host.used else Color(0.75, 0.95, 0.85)

static func title(host: Node3D) -> String:
	match host.kind:
		"stairs":
			return "STAIRS" if not host.locked else App.tr("interact_prompt.locked_stairs")
		"crystal":
			return App.tr("common.floor_crystal")
		"loadout_crystal":
			return App.tr("common.floor_crystal")
		"anvil":
			return "ANVIL"
		"quest_board":
			return App.tr("interact_prompt.notice_board")
		"receptionist":
			return "RECEPTION"
		"vendor":
			return "VENDOR"
		"dumpster":
			return "DUMPSTER"
		"billboard":
			return "CONTROLS"
		"quest_item":
			return App.tr("interact_prompt.quest_cache")
		"chest":
			return App.tr("interact_prompt.boss_chest")
		"base_chest":
			return "CHEST"
		"puzzle_chest":
			return "CACHE"
		"shrine":
			return "SHRINE"
		"campfire":
			return "CAMPFIRE"
		"extract_gate":
			return App.tr("interact_prompt.extraction_gate") if not host.used else App.tr("interact_prompt.dead_gate")
		"shop":
			return App.tr("interact_prompt.ghost_shop")
		"lever":
			return "LEVER"
		"plate":
			return "PLATE"
		"gate":
			return "GATE" if not host.open else "OPEN"
	return host.kind
