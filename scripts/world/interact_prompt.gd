extends Object

## Prompt / title refresh for world interactables.


static func refresh(host: Node3D) -> void:
	if host.kind == "stairs":
		host.locked = not App.boss_dead
		host.prompt = "Locked. Defeat the guardian." if host.locked else "Descend"
	elif host.kind == "crystal":
		host.locked = not App.boss_dead
		host.prompt = "Locked until the floor is cleared." if host.locked else "Descend"
	elif host.kind == "loadout_crystal":
		host.locked = false
		host.prompt = "Loadout / enter dungeon"
	elif host.kind == "anvil":
		host.prompt = "Anvil"
	elif host.kind == "quest_board":
		host.prompt = "Guild tasks"
	elif host.kind == "receptionist":
		host.prompt = "Talk - guild work"
	elif host.kind == "vendor":
		host.prompt = "Vendor stall"
	elif host.kind == "dumpster":
		host.prompt = "Read the dumpster"
	elif host.kind == "billboard":
		host.prompt = "Controls Billboard"
	elif host.kind == "quest_item":
		host.prompt = "Take the guild cache"
	elif host.kind == "shrine":
		host.prompt = "Already used." if host.used else "Pray  (+%d%% dmg)" % int(App.bal.shrine_dmg * 100.0)
	elif host.kind == "campfire":
		host.prompt = "The fire is spent." if host.used else "Sit  (heal)"
	elif host.kind == "extract_gate":
		host.prompt = "Spent. The portal is dark." if host.used else "Extraction Gate"
	elif host.kind == "shop":
		host.prompt = "Ghost Shop"
	elif host.kind == "lever":
		host.prompt = "Pull lever"
	elif host.kind == "plate":
		host.prompt = "Stand to hold the gate"
	elif host.kind == "gate":
		host.prompt = ""
	elif host.kind.ends_with("chest"):
		if host.used:
			host.prompt = "Empty."
		elif host.hidden:
			host.prompt = ""
		else:
			host.prompt = "Open chest"
	else:
		host.prompt = "Interact"
	if host.label:
		host.label.text = title(host)
		if host.hidden:
			host.label.visible = false
		host.label.modulate = Color(0.95, 0.75, 0.35) if host.locked or host.used else Color(0.75, 0.95, 0.85)


static func title(host: Node3D) -> String:
	match host.kind:
		"stairs":
			return "STAIRS" if not host.locked else "LOCKED STAIRS"
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
			return "EXTRACTION GATE" if not host.used else "DEAD GATE"
		"shop":
			return "GHOST SHOP"
		"lever":
			return "LEVER"
		"plate":
			return "PLATE"
		"gate":
			return "GATE" if not host.open else "OPEN"
	return host.kind
