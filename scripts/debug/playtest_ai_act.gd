extends Object

const PlaytestLog := preload("res://scripts/debug/playtest_log.gd")
const Util := preload("res://scripts/debug/playtest_ai_util.gd")
const SEE := 28.0


static func approach_boss(pt: Node, p: Node, boss: Node) -> void:
	if boss == null or not is_instance_valid(boss) or pt._dist(p, boss) > SEE:
		pt.move = Vector2.ZERO
		return
	var gate: Node = pt._closed_door()
	if gate != null and is_instance_valid(gate) and (pt._door_between(p, boss) or pt._near_closed_door(p) or not pt._has_path(p, boss)):
		PlaytestLog.decide(pt, p, "door", "boss_gate", PlaytestLog.target(gate))
		pt._go_open_door(p, gate)
		return
	if pt._has_los(p, boss) and pt._dist(p, boss) <= 6.5:
		fight(pt, p, boss)
		return
	if pt._has_path(p, boss):
		if Util.spinning(pt):
			pt.path.clear()
			pt.path_i = 0
			pt.move = pt._safe_step(p, Vector2(-pt.wander_dir.y, pt.wander_dir.x))
		else:
			pt._follow_goal(p, boss)
		pt._lock_aim(p, boss)
		return
	pt.move = Vector2.ZERO


static func fight(pt: Node, p: Node, enemy: Node) -> void:
	if enemy == null or not is_instance_valid(enemy):
		pt.move = Vector2.ZERO
		pt.attack = false
		return
	Util.stop_gather(p)
	var d: float = pt._dist(p, enemy)
	var rng: float = pt._weapon_range()
	var boss: bool = pt._is_boss(enemy)
	var los: bool = pt._has_los(p, enemy)
	var wide: bool = pt._has_wide_los(p, enemy) if pt._is_bow() else los
	if pt._door_between(p, enemy):
		var bypass: Vector2 = pt._door_bypass(p, enemy)
		pt.move = pt._steer(p, bypass if bypass != Vector2.ZERO else pt._door_away(p))
		pt.attack = false
		pt._lock_aim(p, enemy)
		return
	var hold: float = clampf(rng * 0.86, 1.12, maxf(1.12, rng - 0.08))
	var too_close: float = minf(hold * 0.52, maxf(0.78, rng * 0.34))
	if pt._is_bow():
		hold = clampf(rng * 0.78, 3.0, rng - 0.15)
		too_close = 2.2
	elif pt._is_staff():
		hold = pt._staff_hold()
		too_close = 2.05
	elif boss and pt._is_axe():
		hold = rng - 0.18
		too_close = 1.08
	elif boss:
		hold = 3.9
		too_close = 3.2
	pt._lock_aim(p, enemy)
	if App.tel and App.tel.dmg_dealt > 0.0:
		pt.hit_something = true
	Util.try_staff_special(pt, d, los)
	Util.try_bow_special(pt, d, wide)
	Util.try_axe_special(pt, d, los, enemy)
	var can_shot: bool = d <= rng + 0.12 and (wide if pt._is_bow() else los)
	if can_shot:
		_hold_shot(pt, p, enemy, d, too_close, boss)
		return
	pt.attack = false
	if (not los) or (d > hold and not pt._walk_clear(p, enemy)) or (pt._is_axe() and not pt._walk_clear(p, enemy) and d > rng):
		if pt._has_path(p, enemy) and not Util.spinning(pt):
			pt._follow_goal(p, enemy)
			pt._lock_aim(p, enemy)
			return
		pt.path.clear()
		pt.path_goal = null
		var slide: Vector2 = pt._los_reposition(p, enemy)
		if slide == Vector2.ZERO or Util.spinning(pt):
			slide = Vector2(-pt.aim.y, pt.aim.x) * pt.strafe_sign
			if pt.stuck_t > 0.45:
				pt.strafe_sign *= -1.0
		pt.move = pt._steer(p, slide)
		pt._lock_aim(p, enemy)
		if pt.stuck_t > 0.7:
			Util.want_dash(pt)
		return
	if d > hold:
		pt.move = pt._safe_step(p, pt.aim)
		pt._lock_aim(p, enemy)
		return
	pt.move = pt._safe_step(p, Vector2(-pt.aim.y, pt.aim.x) * pt.strafe_sign)
	if pt.stuck_t > 0.55:
		pt.strafe_sign *= -1.0
	pt._lock_aim(p, enemy)


static func _hold_shot(pt: Node, p: Node, enemy: Node, d: float, too_close: float, boss: bool) -> void:
	pt.path.clear()
	pt.path_goal = null
	if pt._is_staff():
		pt.attack = pt.spec_cd > 0.2 and pt._in_primary(d)
	else:
		pt.attack = true
	if d < too_close:
		pt.move = pt._safe_step(p, -pt.aim)
		if d < (2.4 if boss else 1.05) or pt._crowd(p) >= 2:
			Util.want_dash(pt)
		pt._lock_aim(p, enemy)
		return
	if pt._is_bow():
		pt.move = Vector2.ZERO
		pt._lock_aim(p, enemy)
		return
	if Util.spinning(pt):
		pt.move = Vector2.ZERO
		pt._lock_aim(p, enemy)
		return
	pt.move = pt._safe_step(p, Vector2(-pt.aim.y, pt.aim.x) * pt.strafe_sign)
	if pt.stuck_t > 0.55:
		pt.strafe_sign *= -1.0
	pt._lock_aim(p, enemy)
