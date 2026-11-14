extends Object

## Learned next goal. A missing policy file leaves the scripted ladder alone.

const Misc := preload("res://scripts/debug/playtest_ai/ai_misc.gd")
const U := preload("res://scripts/debug/playtest_ai/ai_util.gd")
const G := preload("res://scripts/debug/playtest_goals.gd")
const L := preload("res://scripts/debug/playtest_log.gd")
const A := preload("res://scripts/debug/playtest_ai/ai_act.gd")
const LogUtil := preload("res://scripts/debug/playtest_log/log_util.gd")
const CliArgs := preload("res://scripts/app/cli_args.gd")

const NEAR := 22.0
const GATHER := 9.0
const POLICY_PATH := "user://playtest/tuner/policy.json"
const ACTIONS: PackedStringArray = ["threat", "hunt", "gather", "clerk", "door", "wander"]

static func steer(pt: PlayHost, p: Node, delta: float) -> bool:
	var goal: String = _goal(pt, p)
	if goal == "":
		return false
	return _apply(pt, p, delta, goal)

static func features(pt: PlayHost, p: Node) -> PackedFloat32Array:
	return _pack(pt, p, false)

static func human_dists(pt: PlayHost, p: Node) -> Vector3:
	return _dists(pt, p, true)

static func _goal(pt: PlayHost, p: Node) -> String:
	if CliArgs.has("--wdb-pt-rl"):
		if pt.has_meta("rl_goal"):
			var rl: String = str(pt.get_meta("rl_goal"))
			if rl != "":
				return rl
		return ""
	if CliArgs.has("--wdb-pt-nopolicy"):
		return ""
	var model: Dictionary = _model(pt)
	if model.is_empty():
		return ""
	return _argmax(model, _pack(pt, p, false))

static func _model(pt: PlayHost) -> Dictionary:
	if pt.has_meta("policy_model"):
		var cached: Variant = pt.get_meta("policy_model")
		if cached is Dictionary:
			return cached
	var model: Dictionary = {}
	if FileAccess.file_exists(POLICY_PATH):
		var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(POLICY_PATH))
		if parsed is Dictionary and _valid(parsed):
			model = parsed
	pt.set_meta("policy_model", model)
	return model

static func _valid(d: Dictionary) -> bool:
	if int(d.get("ver", 0)) != 1:
		return false
	var weights: Variant = d.get("weights")
	var bias: Variant = d.get("bias")
	if not (weights is Array) or not (bias is Array):
		return false
	var rows: Array = weights
	var bias_row: Array = bias
	if rows.size() != ACTIONS.size() or bias_row.size() != ACTIONS.size():
		return false
	for row: Variant in rows:
		if not (row is Array) or (row as Array).size() != 7:
			return false
	return true

static func _pack(pt: PlayHost, p: Node, fresh_threat: bool) -> PackedFloat32Array:
	var out := PackedFloat32Array()
	out.resize(7)
	if p == null or not is_instance_valid(p):
		return out
	var dist: Vector3 = _dists(pt, p, fresh_threat)
	out[0] = _dist_feat(dist.x)
	out[1] = _dist_feat(dist.y)
	out[2] = _dist_feat(dist.z)
	var hp_f: float = 1.0
	if p.get("hp") != null and p.get("max_hp") != null:
		hp_f = clampf(float(p.hp) / maxf(1.0, float(p.max_hp)), 0.0, 1.0)
	out[3] = hp_f
	var ex: float = 0.0
	if App.extracted:
		ex = 1.0
	out[4] = ex
	out[5] = clampf(float(App.floor_n) / 10.0, 0.0, 1.0)
	var cargo: float = float(int(App.gold))
	if App.get("ore") != null:
		cargo += float(int(App.ore))
	if App.get("wood") != null:
		cargo += float(int(App.wood))
	out[6] = clampf(cargo / 20.0, 0.0, 1.0)
	return out

static func _dists(pt: PlayHost, p: Node, fresh_threat: bool) -> Vector3:
	var threat: float = 99.0
	if not fresh_threat and pt.has_meta("log_threat_d"):
		threat = float(pt.get_meta("log_threat_d"))
	else:
		var foe: Node = G.nearest_foe(pt, p)
		if foe != null and is_instance_valid(foe):
			threat = pt._dist(p, foe)
	var near: Array = LogUtil._near(pt, p)
	var scanned: Dictionary = L._scan_dists(near)
	var gather: float = float(scanned.get("gather_d", -1.0))
	var clerk: float = float(scanned.get("clerk_d", -1.0))
	if gather < 0.0:
		gather = 99.0
	if clerk < 0.0:
		clerk = 99.0
	return Vector3(threat, gather, clerk)

static func _dist_feat(d: float) -> float:
	if d < 0.0 or d >= 99.0:
		return 1.0
	return clampf(d / 30.0, 0.0, 1.0)

static func _argmax(model: Dictionary, feat: PackedFloat32Array) -> String:
	var weights: Array = model.get("weights", []) as Array
	var bias: Array = model.get("bias", []) as Array
	var actions: Array = model.get("actions", []) as Array
	var best_i: int = 0
	var best_s: float = -1.0e30
	var n_act: int = weights.size()
	for a: int in n_act:
		var score: float = 0.0
		if a < bias.size():
			score = float(bias[a])
		var row: Variant = weights[a]
		if row is Array:
			var coeffs: Array = row
			var lim: int = coeffs.size()
			if lim > feat.size():
				lim = feat.size()
			for i: int in lim:
				score += float(coeffs[i]) * feat[i]
		if score > best_s:
			best_s = score
			best_i = a
	if best_i < actions.size():
		return str(actions[best_i])
	if best_i < ACTIONS.size():
		return ACTIONS[best_i]
	return ""

static func _apply(pt: PlayHost, p: Node, delta: float, goal: String) -> bool:
	if goal == "threat":
		var foe: Node = G.nearest_foe(pt, p)
		if foe != null and is_instance_valid(foe):
			Misc._engage(pt, p, foe, "policy")
			return true
		return false
	if goal == "hunt":
		var hunt: Node = pt._nearest_hunt(p)
		if hunt != null and is_instance_valid(hunt) and pt._dist(p, hunt) <= NEAR:
			U.note_threat(pt, p, hunt)
			U._lock(pt, hunt, 2.2)
			L.decide(pt, p, "hunt", "policy", L.target(hunt))
			if pt._is_boss(hunt):
				A.approach_boss(pt, p, hunt)
			elif U.spinning(pt):
				pt.path.clear()
				pt.move = pt._any_open(p)
			else:
				pt._follow_goal(p, hunt)
				pt.aim = pt._xz_to(p, hunt)
			return true
		return false
	if goal == "gather":
		var chest: Node = pt._best_chest(p)
		if chest != null and is_instance_valid(chest) and U.can_use(pt, chest) and pt._dist(p, chest) <= GATHER:
			U._lock(pt, chest, 4.0)
			L.decide(pt, p, "gather", "policy", L.target(chest))
			Misc.use_prop(pt, p, chest)
			return true
		var node: Node = pt._best_gather(p)
		if node != null and is_instance_valid(node) and U.can_use(pt, node) and pt._dist(p, node) <= GATHER:
			U._lock(pt, node, 6.0)
			L.decide(pt, p, "gather", "policy", L.target(node))
			Misc.use_prop(pt, p, node)
			return true
		return false
	if goal == "clerk":
		var clerk: Node = pt._best_clerk(p)
		if clerk != null and is_instance_valid(clerk) and Misc._wants_clerk(pt, clerk):
			U._lock(pt, clerk, 4.0)
			L.decide(pt, p, "clerk", "policy", L.target(clerk))
			Misc.use_prop(pt, p, clerk)
			return true
		return false
	if goal == "door":
		if not U.really_extracted():
			return false
		var stairs: Node = pt._reachable_kind(p, "stairs")
		if stairs == null or not is_instance_valid(stairs) or bool(stairs.get("locked")):
			return false
		U._lock(pt, stairs, 4.0)
		L.decide(pt, p, "extract_stairs", "policy", L.target(stairs))
		Misc.use_prop(pt, p, stairs)
		return true
	if goal == "wander":
		if yields_for_depth(str(pt.slot), _depth_open(pt, p)):
			return false
		L.decide(pt, p, "wander", "policy")
		U.wander(pt, p, delta)
		return true
	return false


static func yields_for_depth(slot_name: String, depth_open: bool) -> bool:
	return slot_name == "campaign" and depth_open


static func _depth_open(pt: PlayHost, p: Node) -> bool:
	if Misc._living_boss(pt, p) != null:
		return true
	return Misc._floor_stairs(pt) != null
