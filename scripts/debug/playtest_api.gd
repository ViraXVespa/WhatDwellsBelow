extends Node

## State, public API, and live driver. playtest.gd extends this.

const Store := preload("res://scripts/data/save_store.gd")
const PlaytestAI := preload("res://scripts/debug/playtest_ai.gd")
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
	PlaytestSim.load_history(self)
	PlaytestSim.load_coefs(self)
	if not recs["fresh"].is_empty() or not history.is_empty():
		PlaytestSim.build_recs(self)


func interrupt() -> void:
	interrupted = true
	if live_running:
		PlaytestSim.finish_job(self, "interrupted playtest", true)


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
		PlaytestSim.start_next(self)


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
	var snapshot: Dictionary = PlaytestSim.snap_bal()
	var live: Dictionary = Store.collect()
	PlaytestSim.sim_save(self, "fresh", false)
	if interrupted:
		PlaytestSim.restore_bal(snapshot)
		Store.apply(live)
		running = false
		return "Interrupted. Rows kept: %d" % history.size()
	PlaytestSim.sim_save(self, "progressed", true)
	PlaytestSim.compute_coefs(self)
	PlaytestSim.build_recs(self)
	PlaytestSim.save_coefs(self)
	PlaytestSim.save_history(self)
	PlaytestSim.restore_bal(snapshot)
	Store.apply(live)
	running = false
	last_summary = PlaytestSim.format_summary(self)
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
	PlaytestSim.finish_job(self, str(App.tel.end_cond), false)
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
	if PlaytestGoals.dungeon(self) == null:
		ai_on = false
		return
	var p: Node = get_tree().get_first_node_in_group("player")
	if p == null or not is_instance_valid(p):
		ai_on = false
		return
	ai_on = true
	if smoke_mode and sim_t >= 8.0:
		PlaytestSim.finish_job(self, "interrupted playtest", true)
		return
	var limit: float = float(job.get("limit", App.bal.playtest_limit))
	if not smoke_mode and sim_t >= limit:
		PlaytestSim.finish_job(self, "interrupted playtest", true)
		return
	PlaytestAI.think(self, p, delta)


func _world_ui() -> Node:
	return PlaytestGoals.world_ui(self)


func _role_has_cargo(role: String) -> bool:
	return PlaytestGoals.role_has_cargo(self, role)


func _dismiss_world_ui() -> bool:
	return PlaytestGoals.dismiss_world_ui(self)
