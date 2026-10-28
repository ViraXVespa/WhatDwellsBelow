extends Object

## --wdb-dungeon-walk-layers: during visible play, hide one group at a time.
## After bare, noenv / linear / rest / empty time what is still submitted.
## empty1 and empty05 repeat empty with scaling_3d_scale pinned at 1.0 and 0.5.
## The playtest keeps acting. This does not score the 99% bar.

const CliArgs := preload("res://scripts/app/cli_args.gd")
const HitchLog := preload("res://scripts/debug/hitch_log.gd")

const FLAG := "--wdb-dungeon-walk-layers"

static var _env_nodes: Array[WorldEnvironment] = []
static var _env_saved: Array[Environment] = []
static var _tone_saved: Array[int] = []
static var _rest_nodes: Array[Node] = []
static var _rest_on: Array[bool] = []
static var _rest_cls: Dictionary[String, int] = {}
## Negative means Auto owns the scale. 1.0 and 0.5 are the empty-window pins.
static var _scale_pin: float = -1.0
static var _scale_seen: Array[float] = []

static func active() -> bool:
	return CliArgs.has(FLAG)

static func _kinds() -> PackedStringArray:
	return PackedStringArray([
		"base", "floor", "walls", "sprites", "props", "lights", "hud", "bare",
		"noenv", "linear", "rest", "empty", "empty1", "empty05", "base2",
	])

static func _tag(n: Node) -> String:
	var node_name: String = str(n.name)
	if node_name == "Floors":
		return "floor"
	if node_name == "WallRibbons":
		return "walls"
	if n is MultiMeshInstance3D:
		return "floor"
	if n is Sprite3D:
		return "sprites"
	if n is Light3D:
		return "lights"
	if n is CanvasLayer:
		return "hud"
	if n is MeshInstance3D:
		return "props"
	return ""

static func _clear_extra() -> void:
	_env_nodes.clear()
	_env_saved.clear()
	_tone_saved.clear()
	_rest_nodes.clear()
	_rest_on.clear()
	_rest_cls.clear()

static func _note_env(n: Node) -> bool:
	if not (n is WorldEnvironment):
		return false
	var env_node: WorldEnvironment = n as WorldEnvironment
	var e: Environment = env_node.environment
	if e == null:
		return true
	_env_nodes.append(env_node)
	_env_saved.append(e)
	_tone_saved.append(int(e.tonemap_mode))
	return true

static func _note_rest(n: Node) -> void:
	if _note_env(n):
		return
	var shown: bool = false
	if n is CanvasItem:
		shown = (n as CanvasItem).visible
	elif n is VisualInstance3D:
		shown = (n as VisualInstance3D).visible
	else:
		return
	if not shown:
		return
	var cls_name: String = n.get_class()
	var prev: int = int(_rest_cls.get(cls_name, 0))
	_rest_cls[cls_name] = prev + 1
	_rest_nodes.append(n)
	_rest_on.append(true)

static func _child_covered(n: Node, tag: String, under: bool) -> bool:
	if tag != "":
		return true
	if under:
		return true
	if n is Node3D and not (n as Node3D).visible:
		return true
	if n is CanvasItem and not (n as CanvasItem).visible:
		return true
	if n is CanvasLayer and not (n as CanvasLayer).visible:
		return true
	return false

static func _gather(host: Node) -> void:
	host._iso_all.clear()
	host._iso_on.clear()
	host._iso_tag = PackedStringArray()
	_clear_extra()
	var tree: SceneTree = host.get_tree()
	if tree == null or tree.root == null:
		return
	var stack: Array[Node] = [tree.root]
	var covered: Array[bool] = [false]
	while stack.size() > 0:
		var n: Node = stack.pop_back()
		var under: bool = covered.pop_back()
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
		elif not under:
			_note_rest(n)
		if tag == "floor" or tag == "walls" or tag == "sprites" or tag == "hud":
			continue
		var child_under: bool = _child_covered(n, tag, under)
		for c in n.get_children():
			stack.append(c)
			covered.append(child_under)

static func _counts(host: Node) -> String:
	var floor_n: int = 0
	var wall_n: int = 0
	var sprite_n: int = 0
	var prop_n: int = 0
	var light_n: int = 0
	var hud_n: int = 0
	var i: int = 0
	while i < host._iso_tag.size():
		var tag: String = host._iso_tag[i]
		if tag == "floor":
			floor_n += 1
		elif tag == "walls":
			wall_n += 1
		elif tag == "sprites":
			sprite_n += 1
		elif tag == "props":
			prop_n += 1
		elif tag == "lights":
			light_n += 1
		elif tag == "hud":
			hud_n += 1
		i += 1
	var vp_px: String = "0x0"
	var scale_s: String = "0"
	var msaa_s: String = "0"
	var vp: Viewport = host.get_viewport()
	if vp != null:
		vp_px = "%dx%d" % [vp.size.x, vp.size.y]
		scale_s = "%.2f" % vp.scaling_3d_scale
		msaa_s = str(int(vp.msaa_3d))
	return "floor=%d walls=%d sprites=%d props=%d lights=%d hud=%d env=%d rest=%d vp=%s scale=%s msaa=%s cls=%s" % [floor_n, wall_n, sprite_n, prop_n, light_n, hud_n, _env_nodes.size(), _rest_nodes.size(), vp_px, scale_s, msaa_s, _cls_text()]

static func _cls_text() -> String:
	var keys: Array = _rest_cls.keys()
	keys.sort()
	if keys.is_empty():
		return "-"
	var parts: PackedStringArray = PackedStringArray()
	var i: int = 0
	while i < keys.size():
		var cls_name: String = str(keys[i])
		parts.append("%s:%d" % [cls_name, int(_rest_cls[cls_name])])
		i += 1
	return ",".join(parts)

static func _restore_env() -> void:
	var i: int = 0
	while i < _env_nodes.size():
		var e: Environment = _env_saved[i]
		e.tonemap_mode = _tone_saved[i] as Environment.ToneMapper
		_env_nodes[i].environment = e
		i += 1

static func _restore_rest() -> void:
	var i: int = 0
	while i < _rest_nodes.size():
		var n: Node = _rest_nodes[i]
		var on: bool = _rest_on[i]
		if n is CanvasItem:
			(n as CanvasItem).visible = on
		elif n is Node3D:
			(n as Node3D).visible = on
		i += 1

static func _root_vp(host: Node) -> Viewport:
	var tree: SceneTree = host.get_tree()
	if tree != null and tree.root != null:
		return tree.root
	return host.get_viewport()

## Last write before the draw. DynRes.tick already ran in App._process.
static func pin_draw(host: Node) -> void:
	if _scale_pin < 0.0:
		return
	var vp: Viewport = _root_vp(host)
	if vp == null:
		return
	if not is_equal_approx(vp.scaling_3d_scale, _scale_pin):
		vp.scaling_3d_scale = _scale_pin

static func _restore(host: Node) -> void:
	if _scale_pin >= 0.0:
		_scale_pin = -1.0
		var vp: Viewport = _root_vp(host)
		if vp != null:
			vp.scaling_3d_scale = 1.0
	var i: int = 0
	while i < host._iso_all.size():
		var n: Node = host._iso_all[i]
		var on: bool = host._iso_on[i]
		if n is Node3D:
			(n as Node3D).visible = on
		elif n is CanvasLayer:
			(n as CanvasLayer).visible = on
		i += 1
	_restore_env()
	_restore_rest()

static func _clear_env() -> void:
	var i: int = 0
	while i < _env_nodes.size():
		_env_nodes[i].environment = null
		i += 1

static func _set_linear() -> void:
	var i: int = 0
	while i < _env_saved.size():
		_env_saved[i].tonemap_mode = Environment.TONE_MAPPER_LINEAR
		i += 1

static func _hide_rest() -> void:
	var i: int = 0
	while i < _rest_nodes.size():
		var n: Node = _rest_nodes[i]
		if n is CanvasItem:
			(n as CanvasItem).visible = false
		elif n is Node3D:
			(n as Node3D).visible = false
		i += 1

static func _empty_kind(kind: String) -> bool:
	return kind == "empty" or kind == "empty1" or kind == "empty05"

static func _bare_kind(kind: String) -> bool:
	return kind == "bare" or kind == "noenv" or kind == "linear" or kind == "rest" or _empty_kind(kind)

static func _hide(host: Node, tag: String) -> void:
	var i: int = 0
	while i < host._iso_all.size():
		if tag == "bare" or host._iso_tag[i] == tag:
			var n: Node = host._iso_all[i]
			if n is Node3D:
				(n as Node3D).visible = false
			elif n is CanvasLayer:
				(n as CanvasLayer).visible = false
		i += 1

static func _apply(host: Node, kind: String) -> void:
	_restore(host)
	var hide_kind: String = kind
	if kind == "base2":
		hide_kind = "base"
	if _bare_kind(hide_kind):
		_hide(host, "bare")
	elif hide_kind != "base":
		_hide(host, hide_kind)
	if kind == "noenv" or _empty_kind(kind):
		_clear_env()
	if kind == "linear":
		_set_linear()
	if kind == "rest" or _empty_kind(kind):
		_hide_rest()
	if kind == "empty1":
		_scale_pin = 1.0
	elif kind == "empty05":
		_scale_pin = 0.5
	pin_draw(host)

static func _mid(vals: Array[float]) -> float:
	if vals.is_empty():
		return 0.0
	var ordered: Array[float] = vals.duplicate()
	ordered.sort()
	var at: int = int(round(float(ordered.size() - 1) * 0.5))
	return ordered[at]

static func _p95(host: Node) -> float:
	if host._iso_dts.is_empty():
		return 0.0
	var ordered: Array[float] = host._iso_dts.duplicate()
	ordered.sort()
	var at: int = int(round(float(ordered.size() - 1) * 0.95))
	return ordered[at]

static func _report(host: Node, kind: String) -> void:
	var n: int = host._iso_dts.size()
	var good: int = 0
	for dt: float in host._iso_dts:
		if dt <= 0.020:
			good += 1
	var pct: float = 0.0
	if n > 0:
		pct = 100.0 * float(good) / float(n)
	var draws: int = int(Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME))
	host._hb("HB: isolate layer=%s n=%d p50=%.1f p95=%.1f fps=%.1f draw=%d proc=%.1f phys=%.1f submit=%.1f scale=%.2f walk=1" % [
		kind, n, _mid(host._iso_dts) * 1000.0, _p95(host) * 1000.0, pct, draws, _mid(host._iso_proc), _mid(host._iso_phys), _mid(host._iso_submit), _mid(_scale_seen),
	])

static func _sample(host: Node, delta: float) -> void:
	if host._iso_t < 0.35:
		return
	host._iso_dts.append(delta)
	host._iso_proc.append(float(Performance.get_monitor(Performance.TIME_PROCESS)) * 1000.0)
	host._iso_phys.append(float(Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS)) * 1000.0)
	host._iso_submit.append(HitchLog.frame_submit_ms())
	var vp: Viewport = _root_vp(host)
	if vp != null:
		_scale_seen.append(vp.scaling_3d_scale)

## Called once the dungeon has already been visible for 2 s. Returns true when the pass is done.
static func tick(host: Node, delta: float) -> bool:
	if not host._iso_ready:
		_gather(host)
		host._iso_ready = true
		host._iso_i = 0
		host._iso_applied = -1
		host._iso_t = 0.0
		host._hb("HB: isolate counts %s" % _counts(host))
	var kinds: PackedStringArray = _kinds()
	if host._iso_i >= kinds.size():
		_restore(host)
		return true
	var kind: String = kinds[host._iso_i]
	if host._iso_applied != host._iso_i:
		host._iso_applied = host._iso_i
		host._iso_t = 0.0
		host._iso_dts.clear()
		host._iso_proc.clear()
		host._iso_phys.clear()
		host._iso_submit.clear()
		_scale_seen.clear()
	_apply(host, kind)
	_sample(host, delta)
	host._iso_t += delta
	var hold: float = 3.0 if kind == "base" or kind == "base2" else 2.5
	if host._iso_t < hold:
		return false
	_report(host, kind)
	host._iso_i += 1
	host._iso_applied = -1
	if host._iso_i >= kinds.size():
		_restore(host)
		return true
	return false
