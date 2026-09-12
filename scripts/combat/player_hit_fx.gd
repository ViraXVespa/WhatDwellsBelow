extends RefCounted

const Combat := preload("res://scripts/combat/combat.gd")
const Cover := preload("res://scripts/combat/cover.gd")
const ProjS := preload("res://scripts/combat/projectile.gd")
const PlayerLock := preload("res://scripts/world/player_lock.gd")
static func hit_circle(host: Node, origin: Vector3, radius: float, dmg: float, need_los: bool, stagger: bool, xp := "auto", is_special := false) -> void:
	var _fac = load("res://scripts/combat/player_hit.gd")
	for e in Combat.enemies():
		if e == null or not is_instance_valid(e):
			continue
		if e.has_method("is_alive") and not e.is_alive():
			continue
		var cov := Cover.hit_circle(origin, radius, e as Node3D)
		if not Cover.connected(cov):
			continue
		if need_los and not Combat.los(origin, (e as Node3D).global_position, host.get_world_3d()):
			continue
		load("res://scripts/combat/player_hit_atk.gd").damage_enemy(host, e, dmg * Cover.dmg_mult(cov), stagger, xp, is_special, not Cover.crit_ok(cov), Cover.crit_ok(cov))
	_fac.hit_breakables_circle(host, origin, radius, dmg, need_los)

static func hit_arc(host: Node, rng: float, arc: float, dmg: float, need_los: bool, stagger: bool) -> void:
	var _fac = load("res://scripts/combat/player_hit.gd")
	for e in Combat.enemies():
		if e == null or not is_instance_valid(e):
			continue
		if e.has_method("is_alive") and not e.is_alive():
			continue
		var cov := Cover.hit_arc(host.global_position, host.aim_dir, rng, arc, e as Node3D)
		if not Cover.connected(cov):
			continue
		if need_los and not Combat.los(host.global_position, (e as Node3D).global_position, host.get_world_3d()):
			continue
		load("res://scripts/combat/player_hit_atk.gd").damage_enemy(host, e, dmg * Cover.dmg_mult(cov), stagger, "auto", false, not Cover.crit_ok(cov), Cover.crit_ok(cov))
	_fac.hit_breakables_arc(host, rng, arc, dmg, need_los)

static func draw_special_tele(host: Node, _active: bool) -> void:
	var _fac = load("res://scripts/combat/player_hit.gd")
	if host.telegraph == null:
		return
	var yel := Color(1.0, 0.92, 0.35, 0.42)
	var extra: float = _fac._gear("atk_range")
	if App.weapon == "great_axe":
		host.telegraph.show_circle(host.global_position, App.bal.slam_radius + extra, yel)
	elif App.weapon == "staff":
		host.telegraph.show_circle(host.spec_point, App.bal.staff_special_radius + extra, yel)
	else:
		var w := 0.08
		if App.bal:
			w = float(App.bal.bow_path_width)
		host.telegraph.show_spread(host.global_position, host.aim_dir, App.bal.bow_special_range + extra, App.bal.bow_special_cone, int(App.bal.bow_special_count), w, yel)

static func apply_basic(host: Node) -> void:
	var _fac = load("res://scripts/combat/player_hit.gd")
	var extra: float = _fac._gear("atk_range")
	if App.weapon == "longbow":
		_fac.spawn_arrow(host, host.aim_dir, _fac.scaled_dmg(App.bal.bow_damage, false), App.bal.bow_range + extra, App.bal.bow_proj_speed, App.bal.bow_los)
		App.sfx("bow")
		return
	var rng: float = App.bal.axe_range + extra
	var arc: float = App.bal.axe_arc_deg
	var dmg: float = App.bal.axe_damage
	var need_los: bool = App.bal.axe_los
	if App.weapon == "staff":
		rng = App.bal.staff_range + extra
		arc = App.bal.staff_arc_deg
		dmg = App.bal.staff_damage
		need_los = App.bal.staff_los
	App.sfx("hit")
	hit_arc(host, rng, arc, dmg, need_los, false)
