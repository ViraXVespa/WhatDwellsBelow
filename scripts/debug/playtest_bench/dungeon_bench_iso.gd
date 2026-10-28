extends Object

## --wdb-dungeon-walk-layers: during visible play, hide one group at a time.
## The playtest keeps acting. This does not score the 99% bar.

const CliArgs := preload("res://scripts/app/cli_args.gd")
const HitchLog := preload("res://scripts/debug/hitch_log.gd")

const FLAG := "--wdb-dungeon-walk-layers"

static func active() -> bool:
	return CliArgs.has(FLAG)

static func _kinds() -> PackedStringArray:
	return PackedStringArray([
		"base", "floor", "walls", "sprites", "props", "lights", "hud", "bare", "base2",
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

static func _gather(host: Node) -> void:
	host._iso_all.clear()
	host._iso_on.clear()
	host._iso_tag = PackedStringArray()
	var tree: SceneTree = host.get_tree()
	if tree == null or tree.root == null:
		return
	var stack: Array[Node] = [tree.root]
	while stack.size() > 0:
		var n: Node = stack.pop_back()
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
			if tag == "floor" or tag == "walls" or tag == "sprites" or tag == "hud":
				continue
		for c in n.get_children():
			stack.append(c)

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
	return "floor=%d walls=%d sprites=%d props=%d lights=%d hud=%d" % [floor_n, wall_n, sprite_n, prop_n, light_n, hud_n]

static func _restore(host: Node) -> void:
	var i: int = 0
	while i < host._iso_all.size():
		var n: Node = host._iso_all[i]
		var on: bool = host._iso_on[i]
		if n is Node3D:
			(n as Node3D).visible = on
		elif n is CanvasLayer:
			(n as CanvasLayer).visible = on
		i += 1

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
	if hide_kind == "bare":
		_hide(host, "bare")
	elif hide_kind != "base":
		_hide(host, hide_kind)

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
	host._hb("HB: isolate layer=%s n=%d p50=%.1f p95=%.1f fps=%.1f draw=%d proc=%.1f phys=%.1f submit=%.1f walk=1" % [
		kind, n, _mid(host._iso_dts) * 1000.0, _p95(host) * 1000.0, pct, draws, _mid(host._iso_proc), _mid(host._iso_phys), _mid(host._iso_submit),
	])

static func _sample(host: Node, delta: float) -> void:
	if host._iso_t < 0.35:
		return
	host._iso_dts.append(delta)
	host._iso_proc.append(float(Performance.get_monitor(Performance.TIME_PROCESS)) * 1000.0)
	host._iso_phys.append(float(Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS)) * 1000.0)
	host._iso_submit.append(HitchLog.frame_submit_ms())

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
