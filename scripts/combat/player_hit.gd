extends RefCounted

const PlayerLock := preload("res://scripts/world/player/player_lock.gd")
const Atk := preload("res://scripts/combat/player_hit/hit_atk.gd")
const Fx := preload("res://scripts/combat/player_hit/hit_fx.gd")

static func draw_basic_tele(host: Node, _active: bool) -> void:
	if host.telegraph == null:
		return
	if App.weapon == "longbow":
		host.telegraph.hide_now()
		return
	var col := Color(1.0, 0.82, 0.28, 0.4)
	var extra: float = App.gear("atk_range")
	if App.weapon == "staff":
		host.telegraph.show_arc(host.global_position, host.aim_dir, App.bal.staff_range + extra, App.bal.staff_arc_deg, col)
		return
	host.telegraph.show_arc(host.global_position, host.aim_dir, App.bal.axe_range + extra, App.bal.axe_arc_deg, col)

static func draw_special_tele(host: Node, _active: bool) -> void:
	Fx.draw_special_tele(host, _active)

static func special_point(host: Node) -> Vector3:
	if PlayerLock.valid_lock(host, host.lock_target):
		return (host.lock_target as Node3D).global_position
	var reach: float = App.bal.staff_special_radius + 1.5 + App.gear("atk_range")
	return host.global_position + Vector3(host.aim_dir.x, 0.0, host.aim_dir.y) * reach

static func apply_basic(host: Node) -> void:
	Fx.apply_basic(host)

static func apply_special(host: Node) -> void:
	Atk.apply_special(host)

static func fx(host: Node, path: String, pos: Vector3, h: float, ybill: bool) -> void:
	Atk.fx(host, path, pos, h, ybill)

static func trail(host: Node, delta: float) -> void:
	Atk.trail(host, delta)

static func warm_shown(host: Node) -> void:
	Atk.warm_shown(host)
