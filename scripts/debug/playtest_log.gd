extends Object

## ver 2 journal: compact JSON, no tel.cfg, packed cards, sparse beats, coalesced steps.
## cards bit order is EWNS as a 4-char "01" string.

const PlaytestLogUtil := preload("res://scripts/debug/playtest_log_util.gd")
const Core := preload("res://scripts/debug/playtest_log_core.gd")

# Facade aliases — callers still use PlaytestLog.started / .file_name / etc.
static var events: Array:
	get:
		return Core.events
	set(v):
		Core.events = v
static var file_name: String:
	get:
		return Core.file_name
	set(v):
		Core.file_name = v
static var started: bool:
	get:
		return Core.started
	set(v):
		Core.started = v
static var end_cond: String:
	get:
		return Core.end_cond
	set(v):
		Core.end_cond = v
static var end_fail: String:
	get:
		return Core.end_fail
	set(v):
		Core.end_fail = v


static func _dir() -> String:
	return Core._dir()

static func begin(pt: Node) -> void:
	Core.begin(pt)

static func wait(pt: Node, reason: String) -> void:
	if Core.events.size() > 0:
		var last: Variant = Core.events[Core.events.size() - 1]
		if last is Dictionary and str(last.get("ev", "")) == "wait" and str(last.get("reason", "")) == reason:
			return
	Core.events.append({
		"ev": "wait",
		"t": PlaytestLogUtil._t(pt),
		"in_dungeon": App.in_dungeon,
		"reason": reason,
		"ui_open": App.get("ui_open") == true,
	})



static func goal(pt: Node, p: Node, name: String, extra: Dictionary = {}) -> void:
	if name == Core.last_goal and extra.is_empty():
		return
	Core.last_goal = name
	var ev: Dictionary = {
		"ev": "goal",
		"t": PlaytestLogUtil._t(pt),
		"goal": name,
		"floor": App.floor_n,
		"cell": PlaytestLogUtil._xy(pt, p),
	}
	if extra.size() > 0:
		ev.merge(extra)
	Core.events.append(ev)



static func act(pt: Node, p: Node) -> void:
	if not pt.dash and not pt.special and not pt.potion and not pt.interact:
		return
	var ev: Dictionary = {
		"ev": "act",
		"t": PlaytestLogUtil._t(pt),
		"cell": PlaytestLogUtil._xy(pt, p),
	}
	if pt.dash:
		ev["dash"] = 1
	if pt.special:
		ev["spec"] = 1
	if pt.potion:
		ev["pot"] = 1
	if pt.interact:
		ev["use"] = 1
		ev.merge(PlaytestLogUtil._use_fields(pt, p))
	Core.events.append(ev)



static func beat(pt: Node, p: Node) -> void:
	Core.beat(pt, p)

static func _check_combat(pt: Node) -> void:
	var result: Dictionary = PlaytestLogUtil._maybe_combat(pt, Core.last_combat_kills, Core.last_combat_dealt, Core.last_combat_taken)
	if result.get("changed", false):
		Core.events.append(result.event)
		Core.last_combat_kills = result.kills
		Core.last_combat_dealt = result.dealt
		Core.last_combat_taken = result.taken



static func target(n: Node) -> Dictionary:
	if n == null or not is_instance_valid(n):
		return {}
	var is_boss: bool = n.get("is_boss") == true or n.is_in_group("boss")
	var kind: String = str(n.get("kind"))
	if kind == "<null>" or kind == "Null":
		kind = ""
	var out: Dictionary = {"tgt": n.name}
	if kind != "":
		out["kind"] = kind
	if is_boss:
		out["boss"] = 1
	return out



static func _scan_dists(near: Array) -> Dictionary:
	var gather_d: float = -1.0
	var gather_k: String = ""
	var clerk_d: float = -1.0
	for row: Variant in near:
		if not (row is Array) or (row as Array).size() < 2:
			continue
		var k: String = str(row[0])
		var d: float = float(row[1])
		if gather_d < 0.0 and (k == "mine" or k == "wood"):
			gather_d = d
			gather_k = k
		if clerk_d < 0.0 and (k == "extract_gate" or k.find("clerk") >= 0 or k == "patty" or k == "receptionist"):
			clerk_d = d
	return {"gather_d": gather_d, "gather_k": gather_k, "clerk_d": clerk_d}



static func decide(pt: Node, p: Node, name: String, why: String, extra: Dictionary = {}) -> void:
	Core.decide(pt, p, name, why, extra)

static func step(pt: Node, p: Node) -> void:
	Core.step(pt, p)

static func finish(pt: Node, cond: String, fail: String = "") -> void:
	if Core.ended:
		return
	Core.ended = true
	Core.end_cond = cond
	Core.end_fail = fail if fail != "" else cond
	var pl: Node = null
	if pt.get_tree():
		pl = pt.get_tree().get_first_node_in_group("player")
	Core.events.append({
		"ev": "end",
		"t": PlaytestLogUtil._t(pt),
		"cond": Core.end_cond,
		"fail": Core.end_fail,
		"ex": 1 if App.extracted else 0,
		"fl": App.floor_n,
		"goal": Core.last_goal,
		"sim_t": snappedf(float(pt.sim_t) if pt.get("sim_t") != null else 0.0, 0.1),
		"cell": PlaytestLogUtil._xy(pt, pl),
	})
	_flush(pt)
	Core.started = false



static func _flush(pt: Node) -> void:
	if Core.file_name == "":
		Core.file_name = PlaytestLogUtil._stamp(pt)
	PlaytestLogUtil._flush(Core.file_name, Core.events, Core.end_cond, Core.end_fail)
	Core.flush_n = 0

