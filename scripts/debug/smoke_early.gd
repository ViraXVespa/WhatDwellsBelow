extends Object

const Gen := preload("res://scripts/dungeon/gen.gd")
const Roster := preload("res://scripts/combat/roster.gd")


static func tree(host: Node) -> SceneTree:
	return host.get_tree()


static func quit_in(host: Node, sec: float) -> void:
	tree(host).create_timer(sec).timeout.connect(func(): tree(host).quit())


static func p12(host: Node) -> void:
	var player: Variant = host.get("player")
	var cam: Camera3D = host.get_viewport().get_camera_3d()
	printerr("P1: res=" + ProjectSettings.globalize_path("res://"))
	printerr("P1: app=" + str(host.get_node_or_null("/root/App") != null))
	printerr("P1: game_autoload_absent=" + str(host.get_node_or_null("/root/Game") == null))
	printerr("P1: player=" + str(player != null))
	printerr("P1: character=" + App.character_type)
	if cam:
		printerr("P1: cam_ortho=" + str(cam.projection == Camera3D.PROJECTION_ORTHOGONAL))
		printerr("P1: cam_pitch=" + str(snappedf(cam.rotation_degrees.x, 0.1)))
		printerr("P1: cam_size=" + str(snappedf(cam.size, 0.01)))
	var spr: Variant = player.get("body") if player else null
	if spr:
		printerr("P1: billboard=" + str(spr.billboard == BaseMaterial3D.BILLBOARD_FIXED_Y))
	if player:
		printerr("P1: facing=" + str(player.get("facing_key")))
	printerr("P2: weapon=" + App.weapon)
	printerr("P2: dummy=" + str(tree(host).get_nodes_in_group("enemies").size()))
	printerr("P2: aim_line=" + str(player.get("aim_line") != null))
	printerr("P2: telegraph=" + str(player.get("telegraph") != null))
	printerr("P2: debug=" + str(App.debug != null))
	tree(host).create_timer(0.35).timeout.connect(func(): p12_fire(host))


static func p12_fire(host: Node) -> void:
	var player: Variant = host.get("player")
	if player and player.has_method("set_weapon"):
		player.aim_dir = Vector2.DOWN
		player.set_weapon("great_axe")
		player.atk_state = 1
		player.atk_t = 0.0
		player.hit_done = false
		player._draw_basic_tele(false)
	tree(host).create_timer(0.4).timeout.connect(func():
		if player:
			player._apply_basic()
			player._draw_basic_tele(true)
			printerr("P2: axe_tele_visible=" + str(player.telegraph.visible if player.telegraph else false))
			player.set_weapon("staff")
			player.spec_point = player.global_position + Vector3(0, 0, 2.2)
			player._apply_special()
			player.set_weapon("longbow")
			player._apply_basic()
			player._try_dash(Vector2.DOWN)
		printerr("P2: process_frames=" + str(Engine.get_process_frames()))
		printerr("P2: fps_est=" + str(Engine.get_process_frames()))
		printerr("P2: projectiles=" + str(count_proj(host)))
		printerr("P2: schema=" + str(App.bal.schema().size()))
		tree(host).quit()
	)


static func count_proj(host: Node) -> int:
	var n: int = 0
	for c: Node in host.get_children():
		var scr: Variant = c.get_script()
		if scr and str(scr.resource_path).ends_with("projectile.gd"):
			n += 1
	return n


static func p3(host: Node) -> void:
	var data: Dictionary = host.get("data")
	var stairs: Variant = host.get("stairs")
	var door: Variant = host.get("door")
	printerr("P3: res=" + ProjectSettings.globalize_path("res://"))
	printerr("P3: ok=" + str(data.get("ok", false)))
	printerr("P3: floor=" + str(App.floor_n))
	printerr("P3: role=" + str(data.get("boss_title", "")))
	printerr("P3: gate=" + str(data.get("gate_master", false)))
	printerr("P3: rooms=" + str((data.get("rooms", []) as Array).size()))
	printerr("P3: bases=" + str((data.get("bases", []) as Array).size()))
	printerr("P3: door=" + str(data.get("door", Vector2i.ZERO)))
	printerr("P3: stairs=" + str(data.get("stairs", Vector2i.ZERO)))
	printerr("P3: boss_dead=" + str(App.boss_dead))
	printerr("P3: stairs_locked=" + str(stairs.locked if stairs else true))
	printerr("P3: door_open=" + str(door.open if door else false))
	printerr("P3: enemies=" + str(tree(host).get_nodes_in_group("enemies").size()))
	printerr("P3: bosses=" + str(tree(host).get_nodes_in_group("boss").size()))
	p3_roles()
	if App.floor_n > 1:
		printerr("P3: descended_ok floor=" + str(App.floor_n))
		printerr("P3: process_frames=" + str(Engine.get_process_frames()))
		quit_in(host, 0.35)
		return
	tree(host).create_timer(0.4).timeout.connect(func(): p3_unlock(host))


static func p3_roles() -> void:
	var roles: PackedStringArray = PackedStringArray()
	for f: int in range(1, 12):
		roles.append("%d:%s" % [f, Gen.boss_title(f)])
	printerr("P3: loop=" + ", ".join(roles))
	for f2: int in [1, 5, 6]:
		var d: Dictionary = Gen.generate(f2, 42, App.bal)
		printerr("P3: genF%d ok=%s gate=%s rooms=%d bases=%d" % [f2, str(d.get("ok", false)), str(d.get("gate_master", false)), (d.get("rooms", []) as Array).size(), (d.get("bases", []) as Array).size()])


static func p3_unlock(host: Node) -> void:
	var bosses: Array = tree(host).get_nodes_in_group("boss")
	if bosses.size() > 0 and bosses[0].has_method("force_kill"):
		bosses[0].force_kill()
	tree(host).create_timer(0.25).timeout.connect(func(): p3_after_kill(host))


static func p3_after_kill(host: Node) -> void:
	var stairs: Variant = host.get("stairs")
	var door: Variant = host.get("door")
	if stairs and stairs.has_method("refresh"):
		stairs.refresh()
	printerr("P3: after_kill_dead=" + str(App.boss_dead))
	printerr("P3: after_kill_stairs_locked=" + str(stairs.locked if stairs else true))
	printerr("P3: after_kill_door_open=" + str(door.open if door else false))
	App.next_floor()


static func p4(host: Node) -> void:
	if str(host.get("last_named")) == "" or tree(host).get_nodes_in_group("named").is_empty():
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
	printerr("P4: named_count=" + str(tree(host).get_nodes_in_group("named").size()))
	printerr("P4: enemies=" + str(tree(host).get_nodes_in_group("enemies").size()))
	printerr("P4: bosses=" + str(tree(host).get_nodes_in_group("boss").size()))
	var tele_ok: bool = false
	for n: Node in tree(host).get_nodes_in_group("enemies"):
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
	for n2: Node in tree(host).get_nodes_in_group("enemies"):
		if n2.get("is_boss") == true:
			continue
		if n2.has_method("smoke_force_leash"):
			leash_state = str(n2.smoke_force_leash())
			printerr("P4: leash_state=" + leash_state)
			break
	printerr("P4: leash_ok=" + str(leash_state == "return"))
	var fled: String = force_flee_any(host)
	printerr("P4: flee_who=" + fled)
	printerr("P4: flee_used=" + str(host.get("flee_used")))
	tree(host).create_timer(1.25).timeout.connect(func(): p4_after_flee(host))


static func force_flee_any(host: Node) -> String:
	var groups: Dictionary = host.get("groups")
	for gid: Variant in groups.keys():
		var g: Dictionary = groups[gid]
		if g.fled:
			continue
		var who: Variant = host.call("_trigger_flee", int(gid))
		if who:
			return str(who.get("type_id"))
	return ""


static func p4_after_flee(host: Node) -> void:
	var help: int = 0
	for n: Node in tree(host).get_nodes_in_group("enemies"):
		if n.get("is_boss") == true:
			continue
		help += 1
	printerr("P4: after_flee_enemies=" + str(help))
	printerr("P4: flee_ok=" + str(int(host.get("flee_used")) >= 1))
	var before: int = tree(host).get_nodes_in_group("enemies").size()
	var player: Variant = host.get("player")
	if player:
		var room: Dictionary = host.call("_combat_room")
		if not room.is_empty():
			player.global_position = host.call("_cell_pos", host.call("_rand_cell", room))
	var press: int = host.call("_pressure_spawn")
	printerr("P4: pressure_unsafe n=" + str(press) + " before=" + str(before))
	var safe_n: int = 0
	var clerk: Dictionary = host.call("_find_kind_room", "clerk")
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
	printerr("P4: named_ok=" + str(str(host.get("last_named")) != "" and tree(host).get_nodes_in_group("named").size() > 0))
	quit_in(host, 0.35)
