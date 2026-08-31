extends "res://scripts/debug/playtest_api.gd"

const PlaytestNav := preload("res://scripts/debug/playtest_nav.gd")
const PlaytestGoals2 := preload("res://scripts/debug/playtest_goals.gd")


func _think(p: Node, delta: float) -> void:
	PlaytestAI.think(self, p, delta)


func _use_prop(p: Node, dest: Node, reach: float) -> void:
	PlaytestAI.use_prop(self, p, dest, reach)


func _wander(p: Node, delta: float) -> void:
	PlaytestAI.wander(self, p, delta)


func _weapon_range() -> float:
	return PlaytestAI.weapon_range()


func _is_bow() -> bool:
	return str(App.weapon) == "longbow"


func _is_staff() -> bool:
	return str(App.weapon) == "staff"


func _is_axe() -> bool:
	return str(App.weapon) == "great_axe"


func _is_boss(n: Node) -> bool:
	return PlaytestAI.is_boss(n)


func _is_chest(n: Node) -> bool:
	return n != null and str(n.get("kind")).ends_with("chest")


func _world3() -> World3D:
	return PlaytestNav.world3(self)


func _has_los(a: Node, b: Node) -> bool:
	return PlaytestNav.has_los(self, a, b)


func _has_los_from(pos: Vector3, b: Node) -> bool:
	return PlaytestNav.has_los_from(self, pos, b)


func _go_open_door(p: Node, gate: Node) -> void:
	PlaytestNav.go_open_door(self, p, gate)


func _door_between(a: Node, b: Node) -> bool:
	return PlaytestNav.door_between(self, a, b)


func _door_blocks_cell(c: Vector2i) -> bool:
	return PlaytestNav.door_blocks_cell(self, c)


func _has_wide_los(a: Node, b: Node) -> bool:
	return PlaytestNav.has_wide_los(self, a, b)


func _has_los_from_wide(pos: Vector3, b: Node) -> bool:
	return PlaytestNav.has_los_from_wide(self, pos, b)


func _alive_enemy(n: Node) -> bool:
	return PlaytestAI.alive_enemy(n)


func _notice_range() -> float:
	return PlaytestAI.notice_range(self)


func _grid_dims() -> Dictionary:
	return PlaytestNav.grid_dims(self)


func _grid_floor(c: Vector2i) -> bool:
	return PlaytestNav.grid_floor(self, c)


func _door_cells(door: Node) -> Array:
	return PlaytestNav.door_cells(self, door)


func _obstacle_cell(c: Vector2i) -> bool:
	return PlaytestNav.obstacle_cell(self, c)


func _prop_cell(c: Vector2i) -> bool:
	return PlaytestNav.prop_cell(self, c)


func _floor_cell(grid: PackedByteArray, w: int, h: int, c: Vector2i) -> bool:
	return PlaytestNav.floor_cell(self, grid, w, h, c)


func _steer_floor(c: Vector2i) -> bool:
	return PlaytestNav.steer_floor(self, c)


func _pos_walkable(pos: Vector3) -> bool:
	return PlaytestNav.pos_walkable(self, pos)


func _dir_open(p: Node, dir: Vector2) -> bool:
	return PlaytestNav.dir_open(self, p, dir)


func _any_open(p: Node) -> Vector2:
	return PlaytestNav.any_open(self, p)


func _walk_clear(a: Node, b: Node) -> bool:
	return PlaytestNav.walk_clear(self, a, b)


func _stand_cell(p: Node, dest: Node) -> Vector2i:
	return PlaytestNav.stand_cell(self, p, dest)


func _nearest_visible_threat(p: Node) -> Node:
	return PlaytestGoals2.nearest_visible_threat(self, p)


func _nearest_hunt(p: Node) -> Node:
	return PlaytestGoals2.nearest_hunt(self, p)


func _closed_door() -> Node:
	return PlaytestNav.closed_door(self)


func _closed_doors() -> Array:
	return PlaytestNav.closed_doors(self)


func _near_closed_door(p: Node) -> bool:
	return PlaytestNav.near_closed_door(self, p)


func _dir_hits_door(p: Node, dir: Vector2) -> bool:
	return PlaytestNav.dir_hits_door(self, p, dir)


func _door_away(p: Node) -> Vector2:
	return PlaytestNav.door_away(self, p)


func _nearest_boss(p: Node) -> Node:
	return PlaytestGoals2.nearest_boss(self, p)


func _approach_boss(p: Node, boss: Node) -> void:
	PlaytestAI.approach_boss(self, p, boss)


func _door_bypass(p: Node, boss: Node) -> Vector2:
	return PlaytestNav.door_bypass(self, p, boss)


func _safe_step(p: Node, desired: Vector2) -> Vector2:
	return PlaytestNav.safe_step(self, p, desired)


func _staff_hold() -> float:
	return float(App.bal.staff_special_radius) + 1.35


func _in_primary(d: float) -> bool:
	return d <= _weapon_range() + 0.12


func _try_staff_special(d: float, los: bool) -> void:
	PlaytestAI.try_staff_special(self, d, los)


func _lock_aim(p: Node, enemy: Node) -> void:
	aim = _xz_to(p, enemy)


func _fight(p: Node, enemy: Node) -> void:
	PlaytestAI.fight(self, p, enemy)


func _los_reposition(p: Node, target: Node) -> Vector2:
	return PlaytestNav.los_reposition(self, p, target)


func _clearance_target(c: Vector2i) -> Vector2:
	return PlaytestNav.clearance_target(self, c)


func _wall_sep(p: Node) -> Vector2:
	return PlaytestNav.wall_sep(self, p)


func _steer(p: Node, desired: Vector2) -> Vector2:
	return PlaytestNav.steer(self, p, desired)


func _step_dir(p: Node, desired: Vector2) -> Vector2:
	return PlaytestNav.step_dir(self, p, desired)


func _mail_at(clerk: Node) -> void:
	PlaytestGoals2.mail_at(self, clerk)


func _clerk_role(n: Node) -> String:
	return PlaytestGoals2.clerk_role(n)


func _gather_cargo() -> int:
	return PlaytestGoals2.gather_cargo()


func _misc_cargo() -> int:
	return PlaytestGoals2.misc_cargo()


func _clerk_accepts(n: Node) -> bool:
	return PlaytestGoals2.clerk_accepts(self, n)


func _best_clerk(p: Node) -> Node:
	return PlaytestGoals2.best_clerk(self, p)


func _best_gather(p: Node) -> Node:
	return PlaytestGoals2.best_gather(self, p)


func _best_chest(p: Node) -> Node:
	return PlaytestGoals2.best_chest(self, p)


func _reachable_kind(p: Node, prefix: String) -> Node:
	return PlaytestGoals2.reachable_kind(self, p, prefix)


func _crowd(p: Node) -> int:
	return PlaytestGoals2.crowd(self, p)


func _dist(a: Node, b: Node) -> float:
	return PlaytestGoals2.dist(a, b)


func _xz_to(a: Node, b: Node) -> Vector2:
	return PlaytestGoals2.xz_to(a, b)


func _dungeon() -> Node:
	return PlaytestGoals2.dungeon(self)


func _cell_of_pos(pos: Vector3) -> Vector2i:
	return Vector2i(int(floor(pos.x)), int(floor(pos.z)))


func _cell_of_node(n: Node) -> Vector2i:
	return _cell_of_pos((n as Node3D).global_position)


func _has_path(p: Node, dest: Node) -> bool:
	return PlaytestNav.has_path(self, p, dest)


func _follow_goal(p: Node, dest: Node) -> void:
	PlaytestNav.follow_goal(self, p, dest)


func _follow_or_direct(p: Node, dest: Node) -> Vector2:
	return PlaytestNav.follow_or_direct(self, p, dest)


func _astar(p: Node, dest: Node) -> Array[Vector2i]:
	return PlaytestNav.astar(self, p, dest)


func _start_next() -> void:
	PlaytestSim.start_next(self)


func _prep_slot() -> void:
	PlaytestSim.prep_slot(self)


func _finish_job(cond: String, force_end: bool) -> void:
	PlaytestSim.finish_job(self, cond, force_end)


func _stop_live() -> void:
	PlaytestSim.stop_live(self)


func _sim_save(kind: String, progressed: bool) -> void:
	PlaytestSim.sim_save(self, kind, progressed)


func mini_f(a: float, b: float) -> float:
	return a if a < b else b


func _one_run(kind: String, progressed: bool, wpn: String, tw: Dictionary) -> void:
	PlaytestSim.one_run(self, kind, progressed, wpn, tw)


func _compute_coefs() -> void:
	PlaytestSim.compute_coefs(self)


func _weapon_aware_nudge() -> void:
	PlaytestSim.weapon_aware_nudge(self)


func _cfg_proxy(key: String, row: Dictionary) -> float:
	return PlaytestSim.cfg_proxy(key, row)


func _corr(xs: Array, ys: Array) -> float:
	return PlaytestSim.corr(xs, ys)


func _build_recs() -> void:
	PlaytestSim.build_recs(self)


func _merge(base: Dictionary, extra: Dictionary) -> Dictionary:
	return PlaytestSim.merge(base, extra)


func _snap_bal() -> Dictionary:
	return PlaytestSim.snap_bal()


func _restore_bal(d: Dictionary) -> void:
	PlaytestSim.restore_bal(d)


func _format() -> String:
	return PlaytestSim.format_summary(self)


func success_report() -> String:
	return PlaytestSim.success_report(self)


func _save_history() -> void:
	PlaytestSim.save_history(self)


func _load_history() -> void:
	PlaytestSim.load_history(self)


func _save_coefs() -> void:
	PlaytestSim.save_coefs(self)


func _load_coefs() -> void:
	PlaytestSim.load_coefs(self)
