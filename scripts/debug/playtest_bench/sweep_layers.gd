extends Object

## --wdb-sweep-layers: after the first scored hub walk, keep walking and time
## one group at a time (base, then floor, walls, sprites, props, sun, HUD,
## environment, Label3Ds). Those frames stay out of fps_pct. Nothing stays
## hidden: visibility, the sun, the environment, and the labels are put back
## before the dungeon. keep=1 only when the unhidden window has at least 20
## frames and submit_med of at least 45 ms (the web hub submit sits near 60).
## A lower base is a different frame, and the later lines are discarded.
## cpu_ms and gpu_ms are the viewport's previous-frame render times. A median
## of 0 means the renderer returned nothing, so the stall stays inside submit_ms.

const FLAG := "--wdb-sweep-layers"
const BU := preload("res://scripts/debug/playtest_bench/bench_util.gd")
const CliArgs := preload("res://scripts/app/cli_args.gd")
const HitchLog := preload("res://scripts/debug/hitch_log.gd")
const End := preload("res://scripts/debug/playtest_bench/hub_bench_end.gd")

const HOLD_SEC := 2.5
const WARM_SEC := 0.35
const BASE_SUBMIT_MS := 45.0
const MIN_N := 20

static var _env_nodes: Array[WorldEnvironment] = []
static var _env_saved: Array[Environment] = []
static var _submit: Array[float] = []
static var _tree: Array[float] = []
static var _cpu: Array[float] = []
static var _gpu: Array[float] = []
static var _lit: Array[float] = []
static var _geo: Array[float] = []
static var _sync: Array[float] = []
static var _albedo: Array[float] = []
static var _contact: Array[float] = []
static var _draw3d: Array[float] = []
static var _base_submit: float = -1.0
static var _keep: int = 0

static func pending(host: Node) -> bool:
	if not CliArgs.has(FLAG):
		return false
	var done: bool = bool(host._layers_done)
	return not done

static func _kinds() -> PackedStringArray:
	return PackedStringArray([
		"base", "floor", "walls", "sprites", "props", "sun", "hud", "environment", "label3d",
	])

static func _clear_samples() -> void:
	_submit.clear()
	_tree.clear()
	_cpu.clear()
	_gpu.clear()
	_lit.clear()
	_geo.clear()
	_sync.clear()
	_albedo.clear()
	_contact.clear()
	_draw3d.clear()

static func tick(host: Node, delta: float) -> void:
	HitchLog.set_unscored(true)
	if not host._iso_ready:
		_gather(host)
		host._iso_ready = true
		host._iso_i = 0
		host._iso_applied = -1
		host._iso_t = 0.0
		_base_submit = -1.0
		_keep = 0
		host._hb("HB: sweep counts %s env=%d" % [_counts(host), _env_nodes.size()])
	var kinds: PackedStringArray = _kinds()
	if host._iso_i >= kinds.size():
		_finish_window(host)
		return
	var kind: String = str(kinds[host._iso_i])
	if BU.iso_enter(host):
		_clear_samples()
	_apply(host, kind)
	if App.playtest != null:
		BU.walk_leg(host, delta)
	_sample(host)
	host._iso_t += delta
	if host._iso_t < HOLD_SEC:
		return
	_report(host, kind)
	host._iso_i += 1
	host._iso_applied = -1
	if host._iso_i >= kinds.size():
		_finish_window(host)

static func _finish_window(host: Node) -> void:
	_restore(host)
	HitchLog.set_unscored(false)
	host._layers_done = true
	var base_txt: String = "-"
	if _base_submit >= 0.0:
		base_txt = "%.1f" % _base_submit
	host._hb("HB: sweep layer=done base_submit=%s keep=%d" % [base_txt, _keep])
	End._finish(host, "")

static func _counts(host: Node) -> String:
	return BU.tag_counts(host._iso_tag, PackedStringArray([
		"floor", "walls", "sprites", "props", "sun", "hud", "label3d",
	]))

static func _tag(n: Node) -> String:
	if n is DirectionalLight3D:
		return "sun"
	if n is Label3D:
		return "label3d"
	if n is CanvasLayer:
		return "hud"
	if n.is_in_group("hub_ground") or str(n.name) == "Floors":
		return "floor"
	if n.is_in_group("hub_fence") or str(n.name) == "WallRibbons":
		return "walls"
	if n is Sprite3D:
		return "sprites"
	if n.is_in_group("hub_build"):
		return "props"
	if n is MultiMeshInstance3D:
		return "floor"
	if n is MeshInstance3D:
		var parent_node: Node = n.get_parent()
		if parent_node != null and str(parent_node.name) == "ActorLit":
			return ""
		return "props"
	return ""

static func _gather(host: Node) -> void:
	host._iso_all.clear()
	host._iso_on.clear()
	host._iso_tag = PackedStringArray()
	_env_nodes.clear()
	_env_saved.clear()
	var tree: SceneTree = host.get_tree()
	if tree == null or tree.root == null:
		return
	var stack: Array[Node] = [tree.root]
	while stack.size() > 0:
		var n: Node = stack.pop_back()
		if n is WorldEnvironment:
			var env_node: WorldEnvironment = n as WorldEnvironment
			var env: Environment = env_node.environment
			if env != null:
				_env_nodes.append(env_node)
				_env_saved.append(env)
		var tag: String = _tag(n)
		if tag != "":
			if n is Node3D:
				var body: Node3D = n as Node3D
				host._iso_all.append(body)
				host._iso_on.append(body.visible)
				host._iso_tag.append(tag)
			elif n is CanvasLayer:
				var layer: CanvasLayer = n as CanvasLayer
				host._iso_all.append(layer)
				host._iso_on.append(layer.visible)
				host._iso_tag.append(tag)
		for c in n.get_children():
			stack.append(c)

static func _restore(host: Node) -> void:
	var i: int = 0
	while i < host._iso_all.size():
		var n: Node = host._iso_all[i]
		var on: bool = bool(host._iso_on[i])
		if n is Node3D:
			(n as Node3D).visible = on
		elif n is CanvasLayer:
			(n as CanvasLayer).visible = on
		i += 1
	var e: int = 0
	while e < _env_nodes.size():
		_env_nodes[e].environment = _env_saved[e]
		e += 1

static func _apply(host: Node, kind: String) -> void:
	_restore(host)
	if kind == "base" or kind == "":
		return
	if kind == "environment":
		var e: int = 0
		while e < _env_nodes.size():
			_env_nodes[e].environment = null
			e += 1
		return
	var i: int = 0
	while i < host._iso_all.size():
		if str(host._iso_tag[i]) != kind:
			i += 1
			continue
		var n: Node = host._iso_all[i]
		if n is Node3D:
			(n as Node3D).visible = false
		elif n is CanvasLayer:
			(n as CanvasLayer).visible = false
		i += 1

static func _sample(host: Node) -> void:
	if host._iso_t < WARM_SEC:
		return
	var split: Dictionary = HitchLog.frame_split()
	_take(_submit, float(split.get("submit_ms", -1.0)))
	_take(_tree, float(split.get("tree_ms", -1.0)))
	_take(_cpu, float(split.get("cpu_ms", -1.0)))
	_take(_gpu, float(split.get("gpu_ms", -1.0)))
	_take(_lit, float(split.get("lit_ms", -1.0)))
	_take(_geo, float(split.get("geo_ms", -1.0)))
	_take(_sync, float(split.get("sync_ms", -1.0)))
	_take(_albedo, float(split.get("albedo_ms", -1.0)))
	_take(_contact, float(split.get("contact_ms", -1.0)))
	_take(_draw3d, float(split.get("draw_3d", -1.0)))

static func _take(bucket: Array[float], value: float) -> void:
	if value >= 0.0:
		bucket.append(value)

static func _mid(vals: Array[float]) -> float:
	if vals.is_empty():
		return -1.0
	var ordered: Array[float] = vals.duplicate()
	ordered.sort()
	var at: int = int(round(float(ordered.size() - 1) * 0.5))
	return ordered[at]

static func _num(value: float) -> String:
	if value < 0.0:
		return "-"
	return "%.1f" % value

static func _whole(value: float) -> String:
	if value < 0.0:
		return "-"
	return "%d" % int(round(value))

static func _report(host: Node, kind: String) -> void:
	var n: int = _submit.size()
	var submit_med: float = _mid(_submit)
	if kind == "base":
		_base_submit = submit_med
		if n >= MIN_N and submit_med >= BASE_SUBMIT_MS:
			_keep = 1
		else:
			_keep = 0
	host._hb("HB: sweep layer=%s n=%d submit_med=%s tree_med=%s cpu_med=%s gpu_med=%s lit_med=%s geo_med=%s sync_med=%s albedo_med=%s contact_med=%s draw3d_med=%s keep=%d" % [
		kind, n, _num(submit_med), _num(_mid(_tree)), _num(_mid(_cpu)), _num(_mid(_gpu)),
		_num(_mid(_lit)), _num(_mid(_geo)), _num(_mid(_sync)), _num(_mid(_albedo)),
		_num(_mid(_contact)), _whole(_mid(_draw3d)), _keep,
	])
