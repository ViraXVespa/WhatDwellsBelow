extends RefCounted

const Combat := preload("res://scripts/combat/combat.gd")
const Cover := preload("res://scripts/combat/cover.gd")
const ProjS := preload("res://scripts/combat/projectile.gd")
const PlayerLock := preload("res://scripts/world/player_lock.gd")
const Atk := preload("res://scripts/combat/player_hit_atk.gd")
const Fx := preload("res://scripts/combat/player_hit_fx.gd")


static func draw_basic_tele(host: Node, _active: bool) -> void:
	if host.telegraph == null:
		return
	if App.weapon == "longbow":
		host.telegraph.hide_now()
		return
	var col := Color(1.0, 0.82, 0.28, 0.4)
	var extra: float = _gear("atk_range")
	if App.weapon == "staff":
		host.telegraph.show_arc(host.global_position, host.aim_dir, App.bal.staff_range + extra, App.bal.staff_arc_deg, col)
		return
	host.telegraph.show_arc(host.global_position, host.aim_dir, App.bal.axe_range + extra, App.bal.axe_arc_deg, col)

static func draw_special_tele(host: Node, _active: bool) -> void:
	Fx.draw_special_tele(host, _active)

static func special_point(host: Node) -> Vector3:
	if PlayerLock.valid_lock(host, host.lock_target):
		return (host.lock_target as Node3D).global_position
	var reach: float = App.bal.staff_special_radius + 1.5 + _gear("atk_range")
	return host.global_position + Vector3(host.aim_dir.x, 0.0, host.aim_dir.y) * reach

static func apply_basic(host: Node) -> void:
	Fx.apply_basic(host)

static func apply_special(host: Node) -> void:
	Atk.apply_special(host)

static func hit_arc(host: Node, rng: float, arc: float, dmg: float, need_los: bool, stagger: bool) -> void:
	Fx.hit_arc(host, rng, arc, dmg, need_los, stagger)

static func hit_circle(host: Node, origin: Vector3, radius: float, dmg: float, need_los: bool, stagger: bool, xp := "auto", is_special := false) -> void:
	Fx.hit_circle(host, origin, radius, dmg, need_los, stagger, xp, is_special)

static func scaled_dmg(base: float, is_special: bool) -> float:
	var d: float = base * App.prog.skill_dmg_mult(is_special) + App.prog.gear_dmg()
	if App.shrine_t > 0.0:
		d *= 1.0 + App.bal.shrine_dmg
	return d

static func damage_enemy(host: Node, e: Node, dmg: float, stagger: bool, xp := "auto", _is_special := false, glance := false, can_crit := true) -> void:
	Atk.damage_enemy(host, e, dmg, stagger, xp, _is_special, glance, can_crit)

static func _life_tap(host: Node, e: Node) -> void:
	var hit_heal: float = _gear("hp_on_hit")
	if hit_heal > 0.0 and host.has_method("heal"):
		host.heal(hit_heal)
	if e != null and is_instance_valid(e) and e.has_method("is_alive") and not e.is_alive():
		var kill_heal: float = _gear("hp_on_kill")
		if kill_heal > 0.0 and host.has_method("heal"):
			host.heal(kill_heal)

static func grant_hit_xp(xp: String) -> void:
	if xp == "none":
		return
	App.prog.skill_grant_hit(xp == "magic")

static func hit_breakables_arc(host: Node, rng: float, arc: float, dmg: float, need_los: bool) -> void:
	for b in host.get_tree().get_nodes_in_group("breakables"):
		if b == null or not is_instance_valid(b) or not (b is Node3D):
			continue
		if not Cover.connected(Cover.hit_arc(host.global_position, host.aim_dir, rng, arc, b as Node3D)):
			continue
		if need_los and not Combat.los(host.global_position, (b as Node3D).global_position, host.get_world_3d()):
			continue
		if b.has_method("take_hit"):
			b.take_hit(dmg, host.aim_dir, false)

static func hit_breakables_circle(host: Node, origin: Vector3, radius: float, dmg: float, need_los: bool) -> void:
	for b in host.get_tree().get_nodes_in_group("breakables"):
		if b == null or not is_instance_valid(b) or not (b is Node3D):
			continue
		if not Cover.connected(Cover.hit_circle(origin, radius, b as Node3D)):
			continue
		if need_los and not Combat.los(origin, (b as Node3D).global_position, host.get_world_3d()):
			continue
		if b.has_method("take_hit"):
			b.take_hit(dmg, host.aim_dir, false)

static func spawn_arrow(host: Node, dir: Vector2, dmg: float, rng: float, spd: float, need_los: bool) -> void:
	var p: Node3D = ProjS.new()
	var world := host.get_parent()
	if world:
		world.add_child(p)
	else:
		host.add_child(p)
	var crit := Combat.roll_crit(App.bal.crit_chance + _gear("crit_chance"))
	p.setup(host.global_position, dir, spd, rng, dmg, need_los, crit, false, "", true)

static func fx(host: Node, path: String, pos: Vector3, h: float, ybill: bool) -> void:
	Atk.fx(host, path, pos, h, ybill)

static func trail(host: Node, delta: float) -> void:
	Atk.trail(host, delta)

static func _gear(key: String) -> float:
	if App.prog == null:
		return 0.0
	return App.prog.gear_stat(key)
