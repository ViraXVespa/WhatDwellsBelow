extends Object

const Gen := preload("res://scripts/dungeon/gen.gd")
const Roster := preload("res://scripts/combat/roster.gd")

static func p3(host: Node) -> void:
	var _fac = load("res://scripts/debug/smoke_early.gd")
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
	printerr("P3: enemies=" + str(_fac.tree(host).get_nodes_in_group("enemies").size()))
	printerr("P3: bosses=" + str(_fac.tree(host).get_nodes_in_group("boss").size()))
	_fac.p3_roles()
	if App.floor_n > 1:
		printerr("P3: descended_ok floor=" + str(App.floor_n))
		printerr("P3: process_frames=" + str(Engine.get_process_frames()))
		_fac.quit_in(host, 0.35)
		return
	_fac.tree(host).create_timer(0.4).timeout.connect(func(): _fac.p3_unlock(host))

static func p12(host: Node) -> void:
	var _fac = load("res://scripts/debug/smoke_early.gd")
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
	printerr("P2: dummy=" + str(_fac.tree(host).get_nodes_in_group("enemies").size()))
	printerr("P2: aim_line=" + str(player.get("aim_line") != null))
	printerr("P2: telegraph=" + str(player.get("telegraph") != null))
	printerr("P2: debug=" + str(App.debug != null))
	_fac.tree(host).create_timer(0.35).timeout.connect(func(): _fac.p12_fire(host))
