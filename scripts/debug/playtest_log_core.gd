extends Object

const PlaytestLogUtil := preload("res://scripts/debug/playtest_log_util.gd")

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
	var t: float = PlaytestLogUtil._t(pt)
	if name == last_goal and why == str(pt.get_meta("decide_why", "")) and t - last_decide_t < 2.0:
		return
	last_goal = name
	last_decide_t = t
	pt.set_meta("decide_why", why)
	var cargo: int = int(App.gold)
	if App.get("ore") != null:
		cargo += int(App.ore)
	if App.get("wood") != null:
		cargo += int(App.wood)
	var near: Array = PlaytestLogUtil._near(pt, p)
	var scanned: Dictionary = load("res://scripts/debug/playtest_log.gd")._scan_dists(near)
	var clerk_d: float = float(scanned.clerk_d)
	var gather_d: float = float(scanned.gather_d)
	if pt.has_meta("log_clerk_d"):
		clerk_d = float(pt.get_meta("log_clerk_d"))
	if pt.has_meta("log_gather_d"):
		gather_d = float(pt.get_meta("log_gather_d"))
	var threat_d: float = 99.0
	if pt.has_meta("log_threat_d"):
		threat_d = float(pt.get_meta("log_threat_d"))
	elif extra.has("threat_d"):
		threat_d = float(extra.threat_d)
	var bans: int = 0
	if pt.has_meta("skip_list") and pt.get_meta("skip_list") is Array:
		bans = (pt.get_meta("skip_list") as Array).size()
	if extra.has("kind") and (str(extra.kind) == "<null>" or str(extra.kind) == "Null"):
		extra.erase("kind")
	var ev: Dictionary = {
		"ev": "decide",
		"t": t,
		"goal": name,
		"why": PlaytestLogUtil._relabel(why, clerk_d, gather_d, cargo),
		"fl": App.floor_n,
		"cell": PlaytestLogUtil._xy(pt, p),
		"gold": int(App.gold),
		"cargo": cargo,
		"near": near,
		"threat_d": threat_d,
		"clerk_d": clerk_d,
		"gather_d": gather_d,
	}
	if why != ev["why"]:
		ev["why_raw"] = why
	var gk: String = str(scanned.gather_k)
	if pt.has_meta("log_gather_k"):
		gk = str(pt.get_meta("log_gather_k"))
	if gk != "":
		ev["gather_k"] = gk
	if bans > 0:
		ev["bans"] = bans
	if App.extracted:
		ev["ex"] = 1
	ev.merge(PlaytestLogUtil._lock_fields(pt, p))
	if name == "wander" or why == "explore":
		var skip: String = PlaytestLogUtil._skip_hint(pt, p)
		if skip != "":
			ev["skip"] = skip
		var wd: String = PlaytestLogUtil._wd(pt)
		if wd != "":
			ev["wd"] = wd
		var seen_n: int = PlaytestLogUtil._seen_n(pt)
		if seen_n > 0:
			ev["seen"] = seen_n
	if extra.size() > 0:
		ev.merge(extra)
	events.append(ev)



static func step(pt: Node, p: Node) -> void:
	if p == null or not is_instance_valid(p):
		return
	var t: float = PlaytestLogUtil._t(pt)
	var here: Vector2i = pt._cell_of_node(p)
	var pos: Vector3 = (p as Node3D).global_position
	var moved: float = 0.0
	if last_step_pos != Vector3.ZERO:
		moved = last_step_pos.distance_to(pos)
	if here == last_step_cell and t - last_step_t < 0.3:
		return
	last_step_t = t
	last_step_cell = here
	last_step_pos = pos
	var cards: Dictionary = PlaytestLogUtil._card_open(pt, p)
	var want: Vector2 = pt.move
	if want.length() < 0.05 and pt.get("wander_dir") != null:
		want = pt.wander_dir
	var cmd: String = PlaytestLogUtil._cmd(want)
	var g: String = PlaytestLogUtil._bits(cards.grid)
	var o: String = PlaytestLogUtil._bits(cards.open)
	var ts: String = PlaytestLogUtil._bits(cards.test)
	var mismatch: bool = g != ts or g != o
	if here == last_step_cell and not mismatch and t > 1.0 and moved < 0.2:
		return
	var ev: Dictionary = {
		"ev": "step",
		"t": t,
		"cell": [here.x, here.y],
		"cmd": cmd,
		"g": g,
		"o": o,
		"p": ts,
		"d": snappedf(moved, 0.01),
		"goal": last_goal,
	}
	if mismatch:
		ev["mis"] = 1
	ev.merge(PlaytestLogUtil._path_fields(pt))
	ev.merge(PlaytestLogUtil._tgt_cell(pt, ev))
	if last_goal == "wander":
		var wd: String = PlaytestLogUtil._wd(pt)
		if wd != "":
			ev["wd"] = wd
	if PlaytestLogUtil._coalesce_step(events, ev):
		return
	events.append(ev)



