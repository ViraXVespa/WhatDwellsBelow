extends RefCounted

## Player hit core: damage, XP, life tap, arrows, breakables. Leaf of the player_hit cluster (moved from player_hit.gd and hit_atk.gd).

const Combat := preload("res://scripts/combat/combat.gd")
const Cover := preload("res://scripts/combat/cover.gd")
const ProjS := preload("res://scripts/combat/projectile.gd")
const BreakWalk := preload("res://scripts/combat/player_hit/break_walk.gd")

static func scaled_dmg(base: float, is_special: bool) -> float:
	var d: float = base * App.prog.skill_dmg_mult(is_special) + App.prog.gear_dmg()
	if App.shrine_t > 0.0:
		d *= 1.0 + App.bal.shrine_dmg
	return d

static func _life_tap(host: Node, e: Node) -> void:
	var hit_heal: float = App.gear("hp_on_hit")
	if hit_heal > 0.0 and host.has_method("heal"):
		host.heal(hit_heal)
	if e != null and is_instance_valid(e) and e.has_method("is_alive") and not e.is_alive():
		var kill_heal: float = App.gear("hp_on_kill")
		if kill_heal > 0.0 and host.has_method("heal"):
			host.heal(kill_heal)

static func grant_hit_xp(xp: String) -> void:
	if xp == "none":
		return
	App.prog.skill_grant_hit(xp == "magic")

static func hit_breakables_arc(host: Node, rng: float, arc: float, dmg: float, need_los: bool) -> void:
	var o: Vector3 = host.global_position
	var aim: Vector2 = host.aim_dir
	var world: World3D = host.get_world_3d()
	BreakWalk.smash(host.get_tree(), o, rng, dmg, aim, func(b: Node) -> bool:
		if not Cover.connected(Cover.hit_arc(o, aim, rng, arc, b as Node3D)):
			return false
		return not need_los or Combat.los(o, (b as Node3D).global_position, world))

static func hit_breakables_circle(host: Node, origin: Vector3, radius: float, dmg: float, need_los: bool) -> void:
	var world: World3D = host.get_world_3d()
	BreakWalk.smash(host.get_tree(), origin, radius, dmg, host.aim_dir, func(b: Node) -> bool:
		if not Cover.connected(Cover.hit_circle(origin, radius, b as Node3D)):
			return false
		return not need_los or Combat.los(origin, (b as Node3D).global_position, world))

static func spawn_arrow(host: Node, dir: Vector2, dmg: float, rng: float, spd: float, need_los: bool) -> void:
	var p: Node3D = ProjS.new()
	var world := host.get_parent()
	if world:
		world.add_child(p)
	else:
		host.add_child(p)
	var crit := Combat.roll_crit(App.bal.crit_chance + App.gear("crit_chance"))
	p.setup(host.global_position, dir, spd, rng, dmg, need_los, crit, false, "", true)

static func damage_enemy(host: Node, e: Node, dmg: float, stagger: bool, xp := "auto", _is_special := false, glance := false, can_crit := true) -> void:
	if xp == "magic":
		_is_special = true
	grant_hit_xp(xp)
	var chance: float = App.bal.crit_chance + App.gear("crit_chance")
	var crit := can_crit and Combat.roll_crit(chance)
	if "last_glance" in e:
		e.last_glance = glance and not crit
	if e.has_method("take_hit"):
		e.take_hit(dmg, host.aim_dir, crit)
	_life_tap(host, e)
	if App.tel:
		var shown: float = dmg if not crit else dmg * (App.bal.crit_mult + App.gear("crit_dmg"))
		App.tel.note_damage_dealt(shown, crit)
		if host.atk_state == host.ATK_ACT or host.atk_state == host.ATK_WIND:
			App.tel.spec_hit += 1
			var key := App.weapon
			if App.tel.wpn.has(key):
				App.tel.wpn[key].spec_hit = int(App.tel.wpn[key].spec_hit) + 1
	if stagger and e.has_method("apply_stagger"):
		e.apply_stagger(App.bal.slam_stagger)
