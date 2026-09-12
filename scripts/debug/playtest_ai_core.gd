extends Object

const U := preload("res://scripts/debug/playtest_ai_util.gd")
const G := preload("res://scripts/debug/playtest_goals.gd")
const L := preload("res://scripts/debug/playtest_log.gd")
const A := preload("res://scripts/debug/playtest_ai_act.gd")
const CLOSE := 2.4
const NEAR := 22.0
const GATHER := 9.0

const Misc := preload("res://scripts/debug/playtest_ai_misc.gd")

static func think(pt: Node, p: Node, delta: float) -> void:
	U.tick_motion(pt, p, delta)
	pt.set_meta("flee_t", maxf(0.0, U._meta_f(pt, "flee_t", 0.0) - delta))
	if p.get("hp") != null and float(p.hp) / maxf(1.0, float(p.max_hp)) < 0.35:
		pt.potion = true
		pt.just["potion"] = true
	var foe: Node = G.nearest_foe(pt, p)
	U.note_threat(pt, p, foe)
	if foe and is_instance_valid(foe):
		Misc._engage(pt, p, foe, "threat")
		return
	var gathering: Variant = p.get("gathering")
	if gathering != null and is_instance_valid(gathering):
		L.decide(pt, p, "gathering", "busy", L.target(gathering))
		pt.path.clear()
		pt.path_goal = null
		pt.move = Vector2.ZERO
		pt.aim = pt._xz_to(p, gathering)
		return
	if U.should_unstick(pt, p):
		U.do_unstick(pt)
	var hold: Node = U._locked(pt, delta)
	if hold and is_instance_valid(hold):
		if U.is_foe_lock(hold):
			if pt._alive_enemy(hold):
				Misc._engage(pt, p, hold, "hold_foe")
				return
			Misc._clear_lock(pt)
			hold = null
		elif Misc._mail_if_close(pt, p, hold):
			return
		elif (str(hold.get("kind")) == "extract_gate" or str(hold.get("kind")).find("clerk") >= 0) and not Misc._wants_clerk(pt, hold):
			Misc._done_with_clerk(pt, hold)
			hold = null
		elif Misc._is_junk(pt, hold) or not U.can_use(pt, hold):
			Misc._clear_lock(pt)
			hold = null
		elif U.is_loot_kind(str(hold.get("kind"))) and pt._dist(p, hold) > GATHER + 2.0:
			Misc._clear_lock(pt)
			hold = null
	if hold and is_instance_valid(hold):
		if U.spinning(pt) and U.is_loot_kind(str(hold.get("kind"))):
			U._ban(pt, hold)
			Misc._clear_lock(pt)
		else:
			L.decide(pt, p, "hold", "lock", L.target(hold))
			Misc.use_prop(pt, p, hold)
			Misc._mail_if_close(pt, p, hold)
			return
	var hunt: Node = pt._nearest_hunt(p)
	if hunt and is_instance_valid(hunt) and pt._dist(p, hunt) <= NEAR:
		U.note_threat(pt, p, hunt)
		U._lock(pt, hunt, 2.2)
		L.decide(pt, p, "hunt", "hunt", L.target(hunt))
		if pt._is_boss(hunt):
			A.approach_boss(pt, p, hunt)
		else:
			if U.spinning(pt):
				pt.path.clear()
				pt.move = pt._any_open(p)
			else:
				pt._follow_goal(p, hunt)
			pt.aim = pt._xz_to(p, hunt)
		return
	var clerk: Node = pt._best_clerk(p)
	if clerk and is_instance_valid(clerk) and Misc._wants_clerk(pt, clerk):
		if Misc._mail_if_close(pt, p, clerk):
			return
		U._lock(pt, clerk, 4.0)
		L.decide(pt, p, "clerk", "cargo_near", L.target(clerk))
		Misc.use_prop(pt, p, clerk)
		Misc._mail_if_close(pt, p, clerk)
		return
	if U.really_extracted():
		var stairs: Node = pt._reachable_kind(p, "stairs")
		if stairs and is_instance_valid(stairs) and not U._banned(pt, stairs):
			U._lock(pt, stairs, 4.0)
			L.decide(pt, p, "extract_stairs", "extracted", L.target(stairs))
			Misc.use_prop(pt, p, stairs)
			return
	var chest: Node = pt._best_chest(p)
	if chest and is_instance_valid(chest) and U.can_use(pt, chest) and not Misc._is_junk(pt, chest) and pt._dist(p, chest) <= GATHER:
		U._lock(pt, chest, 4.0)
		L.decide(pt, p, "gather", "chest", L.target(chest))
		Misc.use_prop(pt, p, chest)
		return
	var node: Node = pt._best_gather(p)
	if node and is_instance_valid(node) and U.can_use(pt, node) and not Misc._is_junk(pt, node) and pt._dist(p, node) <= GATHER:
		U._lock(pt, node, 6.0)
		L.decide(pt, p, "gather", "path_prop", L.target(node))
		Misc.use_prop(pt, p, node)
		return
	var local: Node = Misc._usable_local(pt, p, GATHER)
	if local:
		var lk: String = str(local.get("kind"))
		if lk == "mine" or lk == "wood" or U.is_loot_kind(lk) or lk.find("chest") >= 0:
			U._lock(pt, local, 6.0)
			L.decide(pt, p, "gather", "local_prop", L.target(local))
			Misc.use_prop(pt, p, local)
			return
		if Misc._wants_clerk(pt, local):
			if Misc._mail_if_close(pt, p, local):
				return
			U._lock(pt, local, 4.0)
			L.decide(pt, p, "clerk", "cargo_local", L.target(local))
			Misc.use_prop(pt, p, local)
			return
		if lk.find("door") >= 0 or lk.find("stairs") >= 0:
			U._lock(pt, local, 2.5)
			L.decide(pt, p, "door", "local_exit", L.target(local))
			Misc.use_prop(pt, p, local)
			return
	var fleeing: bool = U._meta_f(pt, "flee_t", 0.0) > 0.0
	if not fleeing:
		var crystal: Node = G.closest_kind(pt, p, "crystal", 2.6)
		if crystal:
			Misc._leave_crystal(pt, p, crystal)
			return
		if pt.has_meta("flee_c"):
			pt.remove_meta("flee_c")
	var why: String = "explore"
	if U.really_extracted():
		why = "no_stairs"
	L.decide(pt, p, "wander", why)
	U.wander(pt, p, delta)
