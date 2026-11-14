extends Node

## TCP client for the local tuner. Created only when --wdb-pt-rl is set.

const Policy := preload("res://scripts/debug/playtest_ai/ai_policy.gd")
const CliArgs := preload("res://scripts/app/cli_args.gd")

const ACTIONS: PackedStringArray = ["threat", "hunt", "gather", "clerk", "door", "wander"]

var _peer: StreamPeerTCP
var _buf: PackedByteArray = PackedByteArray()
var _phase: String = "connect"
var _retry: float = 0.0
var _port: int = 11008
var _owe: bool = false
var _mark_t: float = -1.0
var _last_floor: int = 1
var _saw_live: bool = false

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_port = 11008
	var prefix: String = "--wdb-pt-rl-port="
	for a: String in CliArgs.args():
		if a.begins_with(prefix):
			_port = int(a.substr(prefix.length()))
	_peer = StreamPeerTCP.new()
	_peer.set_no_delay(true)
	_try_connect()

func _process(delta: float) -> void:
	if _peer == null:
		return
	_peer.poll()
	var st: int = _peer.get_status()
	if st == StreamPeerTCP.STATUS_ERROR or st == StreamPeerTCP.STATUS_NONE:
		_retry += delta
		if _retry >= 0.5:
			_retry = 0.0
			_buf = PackedByteArray()
			_phase = "connect"
			_owe = false
			_try_connect()
		return
	if st != StreamPeerTCP.STATUS_CONNECTED:
		return
	if _owe and _phase == "live":
		var pt: PlayHost = get_parent() as PlayHost
		if pt != null and float(pt.get("sim_t")) > _mark_t:
			_send_step(pt)
			_owe = false
	_read()

func _try_connect() -> void:
	_peer.disconnect_from_host()
	_peer.connect_to_host("127.0.0.1", _port)

func _read() -> void:
	var n_bytes: int = _peer.get_available_bytes()
	if n_bytes <= 0:
		return
	var got: Array = _peer.get_data(n_bytes)
	if int(got[0]) != OK:
		return
	var chunk: PackedByteArray = got[1]
	_buf.append_array(chunk)
	while true:
		var cut: int = _buf.find(0)
		if cut < 0:
			return
		var raw: PackedByteArray = _buf.slice(0, cut)
		_buf = _buf.slice(cut + 1)
		if raw.is_empty():
			continue
		var parsed: Variant = JSON.parse_string(raw.get_string_from_utf8())
		if parsed is Dictionary:
			_on_msg(parsed)

func _on_msg(msg: Dictionary) -> void:
	var kind: String = str(msg.get("type", ""))
	if kind == "handshake":
		_send_env()
		_phase = "live"
		return
	if kind == "reset":
		var pt: PlayHost = get_parent() as PlayHost
		if pt != null:
			pt.set_meta("rl_goal", "")
		_owe = false
		_send_reset()
		return
	if kind == "action":
		_take_action(msg)
		return
	if kind == "close":
		var tree: SceneTree = get_tree()
		if tree:
			tree.quit()
		return
	if kind == "call":
		_send({"type": "call", "returns": []})

func _take_action(msg: Dictionary) -> void:
	var idx: int = _action_index(msg.get("action", 0))
	var pt: PlayHost = get_parent() as PlayHost
	if pt == null:
		return
	pt.set_meta("rl_goal", ACTIONS[idx])
	_mark_t = float(pt.get("sim_t"))
	_owe = true
	_phase = "live"

func _action_index(action: Variant) -> int:
	var idx: int = 0
	if action is Array and (action as Array).size() > 0:
		idx = _one_index((action as Array)[0])
	else:
		idx = _one_index(action)
	if idx < 0:
		idx = 0
	if idx >= ACTIONS.size():
		idx = ACTIONS.size() - 1
	return idx

func _one_index(one: Variant) -> int:
	if one is float or one is int:
		return int(one)
	if one is Dictionary:
		return int((one as Dictionary).get("goal", 0))
	return 0

func _send_step(pt: PlayHost) -> void:
	var reward: float = 0.0
	var floor_n: int = int(App.floor_n)
	if floor_n > _last_floor:
		reward += float(floor_n - _last_floor)
		_last_floor = floor_n
	var cond: String = ""
	if App.tel != null:
		cond = str(App.tel.get("end_cond"))
	if cond == "extraction" and not bool(pt.get_meta("rl_paid_end", false)):
		reward += 1.0
		pt.set_meta("rl_paid_end", true)
	if (cond == "death" or cond == "dispel") and not bool(pt.get_meta("rl_paid_end", false)):
		reward -= 1.0
		pt.set_meta("rl_paid_end", true)
	var done: bool = false
	var live: bool = bool(pt.get("live_running"))
	if live:
		_saw_live = true
		pt.set_meta("rl_saw_live", true)
	elif _saw_live:
		done = true
	_send({"type": "step", "obs": [_obs(pt)], "reward": [reward], "done": [done]})

func _send_reset() -> void:
	var pt: PlayHost = get_parent() as PlayHost
	_last_floor = int(App.floor_n)
	if pt != null and pt.has_meta("rl_paid_end"):
		pt.remove_meta("rl_paid_end")
	_send({"type": "reset", "obs": [_obs(pt)]})

func _obs(pt: PlayHost) -> Dictionary:
	var p: Node = null
	var tree: SceneTree = get_tree()
	if tree:
		p = tree.get_first_node_in_group("player")
	var feat: PackedFloat32Array = Policy.features(pt, p)
	var nums: Array = []
	for i: int in feat.size():
		nums.append(feat[i])
	return {"obs": nums}

func _send_env() -> void:
	_send({
		"type": "env_info",
		"observation_space": {"agent_0": {"obs": {"size": [7], "space": "box"}}},
		"action_space": {"agent_0": {"goal": {"size": 6, "action_type": "discrete"}}},
		"n_agents": 1,
		"agent_policy_names": ["agent_0"],
	})

func _send(msg: Dictionary) -> void:
	if _peer == null:
		return
	var body: PackedByteArray = JSON.stringify(msg).to_utf8_buffer()
	body.append(0)
	_peer.put_data(body)
