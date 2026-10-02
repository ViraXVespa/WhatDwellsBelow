extends Object

const Gen := preload("res://scripts/dungeon/gen.gd")
const Roster := preload("res://scripts/combat/roster.gd")

static func p4(host: Node) -> void:
	var _fac = load("res://scripts/debug/smoke_early.gd")
	if str(host.get("last_named")) == "" or _fac.tree(host).get_nodes_in_group("named").is_empty():
		var pool0: PackedStringArray = Roster.floor_types(App.floor_n)
		var ntype: String = pool0[0] if not pool0.is_empty() else "goblin"
		var nname: String = Roster.make_name(host.floor_rng)
		var room: Dictionary = host.call("_combat_room")
		if not room.is_empty():
			var gid: int = int(host.get("next_group"))
			host.set("next_group", gid + 1)
			host.call("_add_enemy", ntype, host.call("_cell_pos", host.call("_rand_cell", room)), gid, true, nname)
			host.set("last_named", nname)
	printerr("P4: res=" + ProjectSettings.globalize_path("res://"))
	printerr("P4: roster=" + str(Roster.IDS.size()) + " " + ", ".join(Roster.IDS))
	for f: int in range(1, 6):
		var pool: PackedStringArray = Roster.floor_types(f)
		printerr("P4: poolF%d n=%d types=%s" % [f, pool.size(), ", ".join(pool)])
	printerr("P4: floor=" + str(App.floor_n))
	var types_present: PackedStringArray = host.get("types_present")
	printerr("P4: types_on_floor n=" + str(types_present.size()) + " " + ", ".join(types_present))
	printerr("P4: named=" + str(host.get("last_named")))
	printerr("P4: named_count=" + str(_fac.tree(host).get_nodes_in_group("named").size()))
	printerr("P4: enemies=" + str(_fac.tree(host).get_nodes_in_group("enemies").size()))
	printerr("P4: bosses=" + str(_fac.tree(host).get_nodes_in_group("boss").size()))
	var tele_ok: bool = false
	for n: Node in _fac.tree(host).get_nodes_in_group("enemies"):
		if n.get("is_boss") == true:
			continue
		if n.has_method("_begin_windup"):
			n._begin_windup()
			var st: String = str(n.state_name()) if n.has_method("state_name") else ""
			var vis: bool = false
			if n.get("telegraph") != null:
				vis = (n.telegraph as Node).visible
			printerr("P4: telegraph_state=" + st + " visible=" + str(vis) + " type=" + str(n.get("type_id")) + " role=" + str(n.get("role")))
			tele_ok = vis or st == "windup"
			break
	printerr("P4: telegraph_ok=" + str(tele_ok))
	var leash_state: String = ""
	for n2: Node in _fac.tree(host).get_nodes_in_group("enemies"):
		if n2.get("is_boss") == true:
			continue
		if n2.has_method("smoke_force_leash"):
			leash_state = str(n2.smoke_force_leash())
			printerr("P4: leash_state=" + leash_state)
			break
	printerr("P4: leash_ok=" + str(leash_state == "return"))
	var fled: String = _fac.force_flee_any(host)
	printerr("P4: flee_who=" + fled)
	printerr("P4: flee_used=" + str(host.get("flee_used")))
	_fac.tree(host).create_timer(1.25).timeout.connect(func(): p4_after_flee(host))

static func p4_after_flee(host: Node) -> void:
	var _fac = load("res://scripts/debug/smoke_early.gd")
	var help: int = 0
	for n: Node in _fac.tree(host).get_nodes_in_group("enemies"):
		if n.get("is_boss") == true:
			continue
		help += 1
	printerr("P4: after_flee_enemies=" + str(help))
	printerr("P4: flee_ok=" + str(int(host.get("flee_used")) >= 1))
	var before: int = _fac.tree(host).get_nodes_in_group("enemies").size()
	var player: Variant = host.get("player")
	if player:
		var room: Dictionary = host.call("_combat_room")
		if not room.is_empty():
			player.global_position = host.call("_cell_pos", host.call("_rand_cell", room))
	var press: int = host.call("_pressure_spawn")
	printerr("P4: pressure_unsafe n=" + str(press) + " before=" + str(before))
	var safe_n: int = 0
	var clerk: Dictionary = host.call("_find_kind_room", "extract_gate")
	if clerk.is_empty():
		clerk = host.call("_find_kind_room", "spawn")
	if player and not clerk.is_empty():
		player.global_position = host.call("_cell_pos", Vector2i(int(clerk.x) + 1, int(clerk.y) + 1))
		safe_n = host.call("_pressure_spawn")
	printerr("P4: pressure_safe n=" + str(safe_n))
	printerr("P4: pressure_ok=" + str(press > 0 and safe_n == 0))
	var pool_ok: bool = true
	for f: int in range(1, 6):
		if Roster.floor_types(f).size() < 5:
			pool_ok = false
	printerr("P4: five_per_floor=" + str(pool_ok))
	printerr("P4: twelve_types=" + str(Roster.IDS.size() >= 12))
	printerr("P4: named_ok=" + str(str(host.get("last_named")) != "" and _fac.tree(host).get_nodes_in_group("named").size() > 0))
	_fac.quit_in(host, 0.35)
