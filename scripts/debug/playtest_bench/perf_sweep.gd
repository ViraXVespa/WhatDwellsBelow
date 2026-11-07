extends Node

## --wdb-perf-sweep: one process, no quit between states.
## Cold boot, hub walk, dungeon (seed from --wdb-seed, Great Axe, time scale 1),
## dispel when that acting timer ends, hub walk, dungeon walk, then quit.
## Dungeon entry is App.enter_dungeon (cover, paint wait, scene change).
## Dispel is the player's exit, then the recap camp handoff (wake cover, go_camp).
## Frames count while camp or the dungeon is showing and the loader bar is down.
## HB: seg=<place><n> is that stretch. Each of the four stretches is its own 99% bar.
## The last fps_pct line is the whole run. Hitch rows carry seg for the cold/warm pair.
## tree_ms splits into script_ms, queue_ms, and tail_ms. The sweep node stays at priority 0.
## submit_ms is the pre-draw to post-draw window. The same post-draw stamps
## obj/prim/draw for the visible, shadow, and canvas passes.
## script_ms further splits into bench_ms (hub bench _process), lit_ms (ActorLit),
## and sample_ms (LightRt.sample_xz; actor tint does not call it).
## lit_ms further splits into tint_ms, drive_ms, geo_ms, sync_ms, and shade_ms.
## foot_ms, quad_ms, albedo_ms, and contact_ms sit inside sync_ms.
## sole_ms and pin_ms sit inside geo_ms. sync_rest_ms, geo_rest_ms, and lit_rest_ms
## are the part of that total the named pieces do not cover. lit_max_ms is the
## slowest ActorLit, and lit_who is that node's parent. cpu_ms and gpu_ms are the
## viewport's previous-frame render times (0 means the renderer returned nothing).
## wake_ms, phys_span_ms, and post_phys_ms split the gap from post-draw to the
## hitch tick (App._process, where dt is measured). head_ms is that tick until
## this node's _process. phys_ms stays the engine monitor.
## floor_ms, torch_ms, and bar_ms are armed here and copied at post-draw.
## phys_obj, phys_pairs, and phys_islands are read on the hitch row when wake_ms is set.

const FLAG := "--wdb-perf-sweep"
const CliArgs := preload("res://scripts/app/cli_args.gd")
const BU := preload("res://scripts/debug/playtest_bench/bench_util.gd")
const HitchLog := preload("res://scripts/debug/hitch_log.gd")
const ActorLit := preload("res://scripts/graphics/actor_lit.gd")
const LightRt := preload("res://scripts/graphics/light_rt.gd")
const DungeonBoot := preload("res://scripts/world/dungeon/dungeon_boot.gd")
const TorchBill := preload("res://scripts/graphics/torch_bill.gd")
const HpBar := preload("res://scripts/combat/hp_bar.gd")

const Draw := preload("res://scripts/debug/playtest_bench/perf_sweep/sweep_draw.gd")
const Journey := preload("res://scripts/debug/playtest_bench/perf_sweep/journey.gd")
const Score := preload("res://scripts/debug/playtest_bench/perf_sweep/score.gd")
const ST_HUB := 0
const ST_DUNG := 1
const ST_DISPEL := 2
const ST_BACK := 3

const HARD_SEC := 900.0
const LOAD_SEC := 240.0
## Last idle _process. The sweep node stays at the default priority. Moving that
## node later made tree_ms collapse into after_ms. This probe only brackets tree_ms.
const TAIL_PRIORITY := 1000000
## Wrap every other _physics_process. Lower priority runs first.
const PHYS_HEAD_PRIORITY := -1000000
const PHYS_TAIL_PRIORITY := 1000000

static var _inst: Node = null

static func active() -> bool:
	return CliArgs.has(FLAG)

static func _hb(msg: String) -> void:
	BU.hb(msg)

static func start() -> void:
	if not BU.start_fresh("hub"):
		return
	var scr: GDScript = load("res://scripts/debug/playtest_bench/perf_sweep.gd") as GDScript
	var node: Node = scr.new() as Node
	node.name = "PerfSweep"
	App.add_child(node)
	var hub_scr: GDScript = load("res://scripts/debug/playtest_bench/hub_bench.gd") as GDScript
	if hub_scr != null:
		hub_scr.spawn()
	_hb("HB: sweep pt_sec=%.0f" % float(node.get("_act_limit")))
	App.call_deferred("play_from_menu")

static func claim_hub(_host: Node, miss: String) -> bool:
	if _inst == null or not is_instance_valid(_inst):
		return false
	return _inst._claim_hub(miss)

var _state: int = ST_HUB
var _act_limit: float = 30.0
var _done: bool = false
var _wall0: int = 0
var _state_t: float = 0.0
var _post_t: float = 0.0
var _wait_hb: float = 0.0
var _hub_done: int = 0
var _dispel_sent: bool = false
var _camp_sent: bool = false
var _hub_restarted: bool = false
var _visit_saw: bool = false
var _seg_place: String = ""
var _seg_name: String = ""
var _hub_i: int = 0
var _dung_i: int = 0
var _base_frames: int = 0
var _base_slow: int = 0
var _play: float = 0.0
var _proc_us: int = 0
var _pre_us: int = 0
var _post_us: int = 0
var _tree_ms: float = -1.0
var _script_ms: float = -1.0
var _queue_ms: float = -1.0
var _tail_ms: float = -1.0
var _tail: _TreeTail = null
var _measure_rid: RID = RID()

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_inst = self
	_act_limit = CliArgs.float_arg("--wdb-pt-sec", 30.0)
	_wall0 = Time.get_ticks_msec()
	if not RenderingServer.frame_pre_draw.is_connected(_on_pre_draw):
		RenderingServer.frame_pre_draw.connect(_on_pre_draw)
	if not RenderingServer.frame_post_draw.is_connected(_on_post_draw):
		RenderingServer.frame_post_draw.connect(_on_post_draw)
	var tail: _TreeTail = _TreeTail.new()
	tail.name = "TreeTail"
	tail.process_mode = Node.PROCESS_MODE_ALWAYS
	tail.process_priority = TAIL_PRIORITY
	_tail = tail
	add_child(tail)
	_add_phys_edge(false, PHYS_HEAD_PRIORITY, "PhysHead")
	_add_phys_edge(true, PHYS_TAIL_PRIORITY, "PhysTail")
	BU.vsync_off()
	Draw._arm_render(self)

func _process(delta: float) -> void:
	if _done:
		ActorLit.mark_off()
		LightRt.mark_off()
		DungeonBoot.disarm_floor()
		TorchBill.disarm_torch()
		HpBar.disarm_bar()
		return
	var now: int = Time.get_ticks_usec()
	var tick_us: int = HitchLog.tick_us()
	if tick_us > 0 and now >= tick_us:
		HitchLog.set_head_ms(float(now - tick_us) / 1000.0)
	Draw._arm_render(self)
	if _post_us > 0:
		var after_ms: float = float(now - _post_us) / 1000.0 - HitchLog.harness_in_after_ms()
		if after_ms < 0.0:
			after_ms = 0.0
		HitchLog.set_after_ms(after_ms)
	_proc_us = now
	HitchLog.set_bench_ms(-1.0)
	ActorLit.arm_mark()
	LightRt.arm_mark()
	DungeonBoot.arm_floor()
	TorchBill.arm_torch()
	HpBar.arm_bar()
	_post_t += delta
	if _post_t >= 0.5:
		_post_t = 0.0
		HitchLog.flush_web()
	_state_t += delta
	Score._note_place(self, delta)
	if Score._wall_s(self) >= HARD_SEC:
		Score._finish(self, "timeout")
		return
	if _state == ST_DUNG:
		Journey._tick_dungeon(self)
	elif _state == ST_DISPEL:
		Journey._tick_dispel(self)
	elif _state == ST_BACK:
		Journey._tick_back(self)
	elif not Score._scoring_place(self):
		_wait_hb += delta
		if _wait_hb >= 2.0:
			_wait_hb = 0.0
			_hb("HB: wait")

func _player() -> Node:
	return Journey._player(self)

func _add_phys_edge(is_tail: bool, pri: int, node_name: String) -> void:
	var edge: _PhysEdge = _PhysEdge.new()
	edge.name = node_name
	edge.process_mode = Node.PROCESS_MODE_ALWAYS
	edge.process_priority = pri
	edge._is_tail = is_tail
	add_child(edge)

## End of idle _process, then the deferred flush. pre_draw reads these against the sweep stamp.
class _TreeTail extends Node:
	var script_us: int = 0
	var queue_us: int = 0

	func _process(_delta: float) -> void:
		var sweep: Node = get_parent()
		if sweep == null or bool(sweep.get("_done")):
			return
		script_us = Time.get_ticks_usec()
		call_deferred("_stamp_queue")

	func _stamp_queue() -> void:
		queue_us = Time.get_ticks_usec()

## First and last _physics_process. Stamps the sweep edge on the hitch row.
class _PhysEdge extends Node:
	const HitchLog := preload("res://scripts/debug/hitch_log.gd")
	var _is_tail: bool = false

	func _physics_process(_delta: float) -> void:
		var sweep: Node = get_parent()
		if sweep == null or bool(sweep.get("_done")):
			return
		if _is_tail:
			HitchLog.note_phys_tail()
		else:
			HitchLog.note_phys_head()

func _on_pre_draw() -> void:
	Draw._on_pre_draw(self)

func _on_post_draw() -> void:
	Draw._on_post_draw(self)
