extends Node

## Full-target Automated Playtest. Drives the live player, combat, gather,
## clerks, recap, and isolated saves. Medium-bar fast seed remains for coefs.

const Store := preload("res://scripts/data/save_store.gd")
const PlaytestAI := preload("res://scripts/debug/playtest_ai.gd")
const PlaytestNav := preload("res://scripts/debug/playtest_nav.gd")
const PlaytestGoals := preload("res://scripts/debug/playtest_goals.gd")
const PlaytestSim := preload("res://scripts/debug/playtest_sim.gd")

var history: Array = []
var recs: Dictionary = {"fresh": [], "progressed": []}
var coefs: Dictionary = {}
var last_summary: String = ""
var interrupted: bool = false
var running: bool = false
var live_running: bool = false
var ai_on: bool = false
var queue: Array = []
var job: Dictionary = {}
var slot: String = "fresh"
var live_backup: Dictionary = {}
var bal_backup: Dictionary = {}
var scale_backup: float = 1.0
var sim_t: float = 0.0
var stuck_t: float = 0.0
var last_pos: Vector3 = Vector3.ZERO
var wander_t: float = 0.0
var wander_dir: Vector2 = Vector2.ZERO
var spec_cd: float = 0.0
var just: Dictionary = {}
var move: Vector2 = Vector2.ZERO
var aim: Vector2 = Vector2.DOWN
var attack: bool = false
var special: bool = false
var interact: bool = false
var dash: bool = false
var potion: bool = false
var smoke_mode: bool = false
var moved: bool = false
var hit_something: bool = false
var recap_taken: bool = false
var path: Array[Vector2i] = []
var path_i: int = 0
var path_goal: Node = null
var strafe_sign: float = 1.0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	process_priority = -80
	_load_history()
	_load_coefs()
	if not recs["fresh"].is_empty() or not history.is_empty():
		_build_recs()


func interrupt() -> void:
	interrupted = true
	if live_running:
		_finish_job("interrupted playtest", true)


func queue_batch() -> String:
	interrupted = false
	var weapons: PackedStringArray = PackedStringArray(["great_axe", "staff", "longbow"])
	var tools: PackedStringArray = PackedStringArray(["pickaxe", "hatchet", "pickaxe"])
	var genders: PackedStringArray = PackedStringArray(["male", "female", "male"])
	for kind: String in ["fresh", "progressed"]:
		for i: int in 3:
			enqueue({
				"save": kind,
				"weapon": weapons[i],
				"tool": tools[i],
				"gender": genders[i],
				"scale": App.bal.playtest_scale,
				"limit": App.bal.playtest_limit,
				"cfg": {},
			})
	return "Queued %d live runs." % queue.size()


func enqueue(j: Dictionary) -> void:
	queue.append(j)
	if not live_running:
		_start_next()


func begin_smoke() -> void:
	smoke_mode = true
	interrupted = false
	moved = false
	hit_something = false
	ai_on = false
	live_running = true
	running = true
	sim_t = 0.0
	path.clear()
	path_i = 0
	path_goal = null
	slot = "fresh"
	job = {"save": "fresh", "weapon": App.weapon, "tool": App.prog.tool_type, "limit": 8.0, "scale": 1.0, "cfg": {}}
	App.tel.reset("fresh", true)
	App.tel.start_weapon = App.weapon


func run_medium() -> String:
	running = true
	interrupted = false
	var snapshot: Dictionary = _snap_bal()
	var live: Dictionary = Store.collect()
	_sim_save("fresh", false)
	if interrupted:
		_restore_bal(snapshot)
		Store.apply(live)
		running = false
		return "Interrupted. Rows kept: %d" % history.size()
	_sim_save("progressed", true)
	_compute_coefs()
	_build_recs()
	_save_coefs()
	_save_history()
	_restore_bal(snapshot)
	Store.apply(live)
	running = false
	last_summary = _format()
	return last_summary


func apply_rec(save_kind: String, i: int) -> String:
	var arr: Array = recs.get(save_kind, [])
	if i < 0 or i >= arr.size():
		return "No recommendation."
	var cfg: Dictionary = arr[i].cfg
	for k: Variant in cfg.keys():
		App.bal.setv(str(k), float(cfg[k]))
	return "Applied %s rec %d." % [save_kind, i + 1]


func ideal_for(name: String, save_kind: String) -> float:
	var arr: Array = recs.get(save_kind, [])
	if arr.is_empty():
		return App.bal.getv(name)
	var cfg: Dictionary = arr[0].cfg
	if cfg.has(name):
		return float(cfg[name])
	return App.bal.getv(name)


func reset_progressed_template() -> String:
	var live: Dictionary = Store.collect()
	Store.fresh_delver()
	for id: String in App.prog.SKILLS:
		App.prog.skills_perm[id] = 400.0
	App.prog.deepest = 8
	App.bank_gold = 80
	App.bank_ore = 24
	App.bank_wood = 16
	App.character_chosen = true
	Store.save_slot("progressed")
	Store.apply(live)
	return "Progressed template reset (isolated slot)."


func consume_recap() -> bool:
	if not live_running or recap_taken:
		return false
	recap_taken = true
	App.tel.recap_drain = true
	_finish_job(str(App.tel.end_cond), false)
	return true


func _physics_process(delta: float) -> void:
	if not live_running:
		return
	just.clear()
	attack = false
	special = false
	interact = false
	dash = false
	potion = false
	move = Vector2.ZERO
	spec_cd = maxf(0.0, spec_cd - delta)
	sim_t += delta
	if App.recap and bool(App.recap.get("open")):
		if bool(App.recap.get("draining")):
			App.recap.skip_drain()
		elif not recap_taken:
			App.recap._finish()
		return
	if _dismiss_world_ui():
		return
	if not App.in_dungeon:
		ai_on = false
		return
	if _dungeon() == null:
		ai_on = false
		return
	var p: Node = get_tree().get_first_node_in_group("player")
	if p == null or not is_instance_valid(p):
		ai_on = false
		return
	ai_on = true
	if smoke_mode and sim_t >= 8.0:
		_finish_job("interrupted playtest", true)
		return
	var limit: float = float(job.get("limit", App.bal.playtest_limit))
	if not smoke_mode and sim_t >= limit:
		_finish_job("interrupted playtest", true)
		return
	_think(p, delta)


func _world_ui() -> Node:
	return PlaytestGoals.world_ui(self)


func _role_has_cargo(role: String) -> bool:
	return PlaytestGoals.role_has_cargo(self, role)


func _dismiss_world_ui() -> bool:
	return PlaytestGoals.dismiss_world_ui(self)


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
	return PlaytestGoals.nearest_visible_threat(self, p)


func _nearest_hunt(p: Node) -> Node:
	return PlaytestGoals.nearest_hunt(self, p)


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
	return PlaytestGoals.nearest_boss(self, p)


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
	PlaytestGoals.mail_at(self, clerk)


func _clerk_role(n: Node) -> String:
	return PlaytestGoals.clerk_role(n)


func _gather_cargo() -> int:
	return PlaytestGoals.gather_cargo()


func _misc_cargo() -> int:
	return PlaytestGoals.misc_cargo()


func _clerk_accepts(n: Node) -> bool:
	return PlaytestGoals.clerk_accepts(self, n)


func _best_clerk(p: Node) -> Node:
	return PlaytestGoals.best_clerk(self, p)


func _best_gather(p: Node) -> Node:
	return PlaytestGoals.best_gather(self, p)


func _best_chest(p: Node) -> Node:
	return PlaytestGoals.best_chest(self, p)


func _reachable_kind(p: Node, prefix: String) -> Node:
	return PlaytestGoals.reachable_kind(self, p, prefix)


func _crowd(p: Node) -> int:
	return PlaytestGoals.crowd(self, p)


func _dist(a: Node, b: Node) -> float:
	return PlaytestGoals.dist(a, b)


func _xz_to(a: Node, b: Node) -> Vector2:
	return PlaytestGoals.xz_to(a, b)


func _dungeon() -> Node:
	return PlaytestGoals.dungeon(self)


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
