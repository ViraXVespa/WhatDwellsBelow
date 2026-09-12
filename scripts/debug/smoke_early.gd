extends Object

const Gen := preload("res://scripts/dungeon/gen.gd")
const Roster := preload("res://scripts/combat/roster.gd")
const P4 := preload("res://scripts/debug/smoke_early_p4.gd")
const P3 := preload("res://scripts/debug/smoke_early_p3.gd")


static func tree(host: Node) -> SceneTree:
	return host.get_tree()

static func quit_in(host: Node, sec: float) -> void:
	tree(host).create_timer(sec).timeout.connect(func(): tree(host).quit())

static func p12(host: Node) -> void:
	P3.p12(host)

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
	P3.p3(host)

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
	P4.p4(host)

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
	P4.p4_after_flee(host)
