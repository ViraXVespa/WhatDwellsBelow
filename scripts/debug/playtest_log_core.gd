extends Object

const PlaytestLogUtil := preload("res://scripts/debug/playtest_log_util.gd")
const Beat := preload("res://scripts/debug/playtest_log_core_beat.gd")

static func _dir() -> String:
	return PlaytestLogUtil._dir()


static var events: Array = []
static var file_name: String = ""
static var started: bool = false
static var last_goal: String = ""
static var last_decide_t: float = -999.0
static var last_step_t: float = -999.0
static var last_step_cell: Vector2i = Vector2i(-999, -999)
static var last_step_pos: Vector3 = Vector3.ZERO
static var last_combat_kills: int = 0
static var last_combat_dealt: float = 0.0
static var last_combat_taken: float = 0.0
static var last_beat_gold: int = -1
static var last_beat_kills: int = -1
static var last_beat_hp: float = -1.0
static var last_beat_goal: String = ""
static var flush_n: int = 0
static var ended: bool = false
static var end_cond: String = ""
static var end_fail: String = ""

static func begin(pt: Node) -> void:
	events = []
	started = true
	ended = false
	end_cond = ""
	end_fail = ""
	last_goal = ""
	last_decide_t = -999.0
	last_step_t = -999.0
	last_step_cell = Vector2i(-999, -999)
	last_step_pos = Vector3.ZERO
	last_combat_kills = 0
	last_combat_dealt = 0.0
	last_combat_taken = 0.0
	last_beat_gold = -1
	last_beat_kills = -1
	last_beat_hp = -1.0
	last_beat_goal = ""
	flush_n = 0
	file_name = PlaytestLogUtil._stamp(pt)
	var save: String = "fresh"
	var limit: float = float(App.bal.playtest_limit)
	var scale: float = float(App.bal.playtest_scale)
	var smoke: bool = false
	if pt.get("job") is Dictionary:
		var job: Dictionary = pt.job
		save = str(job.get("save", "fresh"))
		limit = float(job.get("limit", limit))
		smoke = job.get("smoke") == true
	if pt.get("smoke_mode") == true:
		smoke = true
	events.append({
		"ev": "begin",
		"t": 0.0,
		"cfg_hash": PlaytestLogUtil._cfg_hash(),
		"gender": str(App.character_type),
		"limit": limit,
		"platform": OS.get_name(),
		"save": save,
		"scale": scale,
		"time_scale": Engine.time_scale,
		"smoke": smoke,
		"tool": str(App.prog.tool_type) if App.prog else "",
		"weapon": str(App.weapon),
	})
	load("res://scripts/debug/playtest_log.gd")._flush(pt)

static func beat(pt: Node, p: Node) -> void:
	var gold: int = int(App.gold)
	var kills: int = int(App.tel.kills) if App.tel else 0
	var hp: float = 0.0
	if p != null and p.get("hp") != null:
		hp = float(p.hp)
	var same: bool = gold == last_beat_gold and kills == last_beat_kills and last_goal == last_beat_goal and is_equal_approx(hp, last_beat_hp)
	last_beat_gold = gold
	last_beat_kills = kills
	last_beat_hp = hp
	last_beat_goal = last_goal
	if same:
		load("res://scripts/debug/playtest_log.gd")._check_combat(pt)
		return
	var ev: Dictionary = {
		"ev": "beat",
		"t": PlaytestLogUtil._t(pt),
		"fl": App.floor_n,
		"cell": PlaytestLogUtil._xy(pt, p),
		"g": last_goal,
		"gold": gold,
		"hp": snappedf(hp, 0.1),
		"kills": kills,
		"stk": snappedf(float(pt.stuck_t), 0.1),
	}
	if App.extracted:
		ev["ex"] = 1
	if p != null and p.get("in_combat") == true:
		ev["cmb"] = 1
	if App.get("ore") != null and int(App.ore) != 0:
		ev["ore"] = int(App.ore)
	if App.get("wood") != null and int(App.wood) != 0:
		ev["wood"] = int(App.wood)
	ev.merge(PlaytestLogUtil._beat_perf())
	events.append(ev)
	load("res://scripts/debug/playtest_log.gd")._check_combat(pt)
	flush_n += 1
	if flush_n >= 24:
		load("res://scripts/debug/playtest_log.gd")._flush(pt)

static func decide(pt: Node, p: Node, name: String, why: String, extra: Dictionary = {}) -> void:
	Beat.decide(pt, p, name, why, extra)

static func step(pt: Node, p: Node) -> void:
	Beat.step(pt, p)
