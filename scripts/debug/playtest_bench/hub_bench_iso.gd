extends Object

## Split from hub_bench.gd: _iso_kinds, _iso_gather, _iso_counts....

const BU := preload("res://scripts/debug/playtest_bench/bench_util.gd")
const CliArgs := preload("res://scripts/app/cli_args.gd")
const HitchLog := preload("res://scripts/debug/hitch_log.gd")
const End := preload("res://scripts/debug/playtest_bench/hub_bench_end.gd")
const Visit := preload("res://scripts/debug/playtest_bench/hub_bench_visit.gd")
const IsoUtil := preload("res://scripts/debug/playtest_bench/dungeon_bench_iso/iso_util.gd")

static func _iso_kinds() -> PackedStringArray:
	return PackedStringArray([
		"warm", "base", "fence", "ground", "build", "sprites", "marks", "hud", "bare",
	])

static func _iso_gather(host: Node) -> void:
	host._iso_all.clear()
	host._iso_on.clear()
	host._iso_lits.clear()
	host._iso_tag = PackedStringArray()
	var tree: SceneTree = host.get_tree()
	if tree == null or tree.root == null:
		return
	var stack: Array[Node] = [tree.root]
	while stack.size() > 0:
		var n: Node = stack.pop_back()
		var tag: String = ""
		if n.is_in_group("hub_fence"):
			tag = "fence"
		elif n.is_in_group("hub_ground"):
			tag = "ground"
		elif n.is_in_group("hub_build"):
			tag = "build"
		elif n is Sprite3D:
			tag = "sprites"
		elif str(n.name) == "ActorLit":
			host._iso_lits.append(n)
			var kids: Array = n.get_children()
			var k: int = 0
			while k < kids.size():
				var mark_child: Node = kids[k]
				if mark_child is Node3D:
					var mark: Node3D = mark_child as Node3D
					host._iso_all.append(mark)
					host._iso_on.append(mark.visible)
					host._iso_tag.append("marks")
				k += 1
		if n is Node3D and tag != "":
			var body: Node3D = n as Node3D
			host._iso_all.append(body)
			host._iso_on.append(body.visible)
			host._iso_tag.append(tag)
		elif n is CanvasLayer:
			var layer: CanvasLayer = n as CanvasLayer
			host._iso_all.append(layer)
			host._iso_on.append(layer.visible)
			host._iso_tag.append("hud")
		for c in n.get_children():
			stack.append(c)

static func _iso_counts(host: Node) -> String:
	return BU.tag_counts(host._iso_tag, PackedStringArray(["fence", "ground", "build", "sprites", "marks", "hud"]))

static func _iso_restore(host: Node) -> void:
	var i: int = 0
	while i < host._iso_all.size():
		var n: Node = host._iso_all[i]
		var on: bool = host._iso_on[i]
		if n is Node3D:
			(n as Node3D).visible = on
		elif n is CanvasLayer:
			(n as CanvasLayer).visible = on
		i += 1


static func _iso_apply(host: Node, kind: String) -> void:
	_iso_restore(host)
	var pause_lits: bool = kind == "marks" or kind == "bare"
	for lit: Node in host._iso_lits:
		lit.set_process(not pause_lits)
	if kind == "bare":
		IsoUtil._hide(host, "bare")
	elif kind != "warm" and kind != "base":
		IsoUtil._hide(host, kind)

static func _iso_stand(host: Node, actor: Node3D) -> void:
	if host._iso_spot == Vector3.ZERO:
		host._iso_spot = load("res://scripts/world/camp/layout_spec.gd").SPOTS["Dummy"]
		var camp: Node = Visit._camp(host)
		if camp != null:
			var dummy_v: Variant = camp.get("dummy")
			if dummy_v is Node3D:
				host._iso_spot = (dummy_v as Node3D).global_position
	if actor.global_position.distance_squared_to(host._iso_spot) > 0.16:
		actor.global_position = host._iso_spot
	if "velocity" in actor:
		actor.set("velocity", Vector3.ZERO)
	App.playtest.move = Vector2.ZERO
	App.playtest.aim = Vector2(-1.0, 0.0)
	App.playtest.attack = false

static func _iso_mid(vals: Array[float]) -> float:
	if vals.is_empty():
		return 0.0
	var ordered: Array[float] = vals.duplicate()
	ordered.sort()
	var at: int = int(round(float(ordered.size() - 1) * 0.5))
	return ordered[at]

static func _iso_report(host: Node, kind: String) -> void:
	var n: int = host._iso_dts.size()
	var good: int = 0
	for dt: float in host._iso_dts:
		if dt <= 0.020:
			good += 1
	var pct: float = 0.0
	if n > 0:
		pct = 100.0 * float(good) / float(n)
	var draws: int = int(Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME))
	var walking: int = 1 if CliArgs.has(host.WALK_FLAG) else 0
	host._hb("HB: isolate layer=%s n=%d p50=%.1f p95=%.1f fps=%.1f draw=%d proc=%.1f phys=%.1f submit=%.1f walk=%d" % [
		kind, n, _iso_mid(host._iso_dts) * 1000.0, _iso_p95(host) * 1000.0, pct, draws, _iso_mid(host._iso_proc), _iso_mid(host._iso_phys), _iso_mid(host._iso_submit), walking,
	])

static func _iso_p95(host: Node) -> float:
	if host._iso_dts.is_empty():
		return 0.0
	var ordered: Array[float] = host._iso_dts.duplicate()
	ordered.sort()
	var at: int = int(round(float(ordered.size() - 1) * 0.95))
	return ordered[at]

static func _iso_sample(host: Node, delta: float) -> void:
	if host._iso_t < 0.35:
		return
	host._iso_dts.append(delta)
	host._iso_proc.append(float(Performance.get_monitor(Performance.TIME_PROCESS)) * 1000.0)
	host._iso_phys.append(float(Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS)) * 1000.0)
	host._iso_submit.append(HitchLog.frame_submit_ms())

static func _fill_layers(host: Node, delta: float) -> void:
	# Full bench has already walked the facings, stations, and the strike.
	# The scored fill is the miss, so the layer times start there.
	if not host._iso_ready:
		_iso_gather(host)
		host._iso_ready = true
		host._hb("HB: isolate counts %s" % _iso_counts(host))
	var kinds: PackedStringArray = _iso_kinds()
	kinds.append("base")
	if host._iso_i >= kinds.size():
		End._finish(host, "isolate")
		return
	var kind: String = kinds[host._iso_i]
	BU.iso_enter(host)
	_iso_apply(host, kind)
	BU.walk_leg(host, delta)
	_iso_sample(host, delta)
	host._iso_t += delta
	var hold: float = 1.5 if kind == "warm" else 2.5
	if host._iso_t < hold:
		return
	_iso_report(host, kind)
	host._iso_i += 1
	host._iso_applied = -1
	if host._iso_i >= kinds.size():
		End._finish(host, "isolate")

## One scored-length fill: normal, every tagged group hidden, normal again.
## The first window has to stay near a 40 ms submit or the run is discarded.
static func _fill_aba(host: Node, delta: float) -> void:
	if host._iso_i >= 3:
		return
	if not host._iso_ready:
		_iso_gather(host)
		host._iso_ready = true
		host._iso_i = 0
		host._iso_applied = -1
		host._hb("HB: isolate counts %s" % _iso_counts(host))
	var kind: String = "base"
	if host._iso_i == 1:
		kind = "bare"
	elif host._iso_i == 2:
		kind = "base2"
	BU.iso_enter(host)
	var apply_kind: String = "base" if kind == "base2" else kind
	_iso_apply(host, apply_kind)
	BU.walk_leg(host, delta)
	_iso_sample(host, delta)
	host._iso_t += delta
	var closed: bool = host._clock >= host.PLAY_SEC
	if host._iso_i < 2 and host._iso_t >= 3.0:
		closed = true
	if not closed:
		return
	_iso_report(host, kind)
	host._iso_i += 1
	host._iso_applied = -1
	if host._iso_i >= 3 or host._clock >= host.PLAY_SEC:
		_iso_restore(host)
		host._iso_i = 3

static func _isolate(host: Node, actor: Node3D, delta: float) -> void:
	if not host._iso_ready:
		_iso_gather(host)
		host._iso_ready = true
		host._hb("HB: isolate counts %s" % _iso_counts(host))
	_iso_stand(host, actor)
	var kinds: PackedStringArray = _iso_kinds()
	if host._iso_i >= kinds.size():
		End._finish(host, "isolate")
		return
	var kind: String = kinds[host._iso_i]
	BU.iso_enter(host)
	_iso_apply(host, kind)
	_iso_sample(host, delta)
	host._iso_t += delta
	var hold: float = 1.5 if kind == "warm" else 2.5
	if host._iso_t < hold:
		return
	_iso_report(host, kind)
	host._iso_i += 1
	host._iso_applied = -1
	if host._iso_i >= kinds.size():
		End._finish(host, "isolate")
