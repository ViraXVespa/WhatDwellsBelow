extends Object

## First/second open time of every hub menu, after a real title -> hub load.
## Run: --wdb-load-timing-smoke --wdb-open-timing (headless or with a renderer).
## Line per open: OPEN: <name> pass=<1|2> call_ms (the open call) frame_ms (slowest of the next 4 frames)
## extra_ms (call + frame over the idle frame). Exit 1 when a first open costs over BUDGET_MS and more than
## SLACK_MS over its second open (a menu that is slow every time is a build cost, not a first-open stall).

const FLAG := "--wdb-open-timing"
const BUDGET_MS := 16.0
const SLACK_MS := 6.0
const CliArgs := preload("res://scripts/debug/cli_args.gd")

static func active() -> bool:
	return CliArgs.has(FLAG)

static func run_and_quit(tree: SceneTree) -> void:
	var ok: bool = await run(tree)
	tree.quit(0 if ok else 1)

static func run(tree: SceneTree) -> bool:
	var scene: Node = tree.current_scene
	var player: Node = tree.get_first_node_in_group("player")
	var rows: Array = [
		["anvil", func(): _interact(tree, "anvil", player)],
		["loadout_crystal", func(): _interact(tree, "loadout_crystal", player)],
		["quest_board", func(): _interact(tree, "quest_board", player)],
		["receptionist", func(): _interact(tree, "receptionist", player)],
		["vendor", func(): _interact(tree, "vendor", player)],
		["dumpster", func(): _interact(tree, "dumpster", player)],
		["controls_billboard", func(): _interact(tree, "billboard", player)],
		["inventory", func(): scene.world_ui().open_inventory()],
		["extraction_gate", func(): scene.world_ui().open_extract("gate", null)],
		["ghost_shop", func(): scene.world_ui().open_shop(null)],
		["pause", func(): App.pause_menu.show_menu()],
		["pause_inventory", func(): App.pause_menu.show_inventory()],
		["recap", func(): App.recap.play("death")],
	]
	var ok: bool = true
	var extras: Dictionary = {}
	for i: int in 10:
		await tree.process_frame
	for pass_i: int in 2:
		for r: Array in rows:
			var base: float = await _idle(tree)
			var t0: int = Time.get_ticks_usec()
			(r[1] as Callable).call()
			var call_ms: float = float(Time.get_ticks_usec() - t0) / 1000.0
			var shown: bool = App.ui_open
			var worst: float = 0.0
			var last: int = Time.get_ticks_usec()
			for i: int in 4:
				await tree.process_frame
				var now: int = Time.get_ticks_usec()
				worst = maxf(worst, float(now - last) / 1000.0)
				last = now
			var extra: float = call_ms + maxf(0.0, worst - base)
			printerr("OPEN: %s pass=%d call_ms=%.1f frame_ms=%.1f idle_ms=%.1f extra_ms=%.1f shown=%s" % [r[0], pass_i + 1, call_ms, worst, base, extra, shown])
			if pass_i == 0:
				extras[r[0]] = extra
			elif float(extras[r[0]]) > maxf(BUDGET_MS, extra + SLACK_MS) or not shown:
				printerr("OPEN: slow_first " + str(r[0]))
				ok = false
			_close(scene.world_ui())
	printerr("OPEN: ok=" + str(ok))
	return ok

## Median frame time with nothing opening.
static func _idle(tree: SceneTree) -> float:
	var ts: Array[float] = []
	var last: int = Time.get_ticks_usec()
	for i: int in 5:
		await tree.process_frame
		var now: int = Time.get_ticks_usec()
		ts.append(float(now - last) / 1000.0)
		last = now
	ts.sort()
	return ts[2]

static func _interact(tree: SceneTree, kind: String, player: Node) -> void:
	for n: Node in tree.get_nodes_in_group("interact"):
		if str(n.get("kind")) == kind and n.has_method("interact"):
			n.interact(player)
			return
	assert(false, "open timing: no interact kind " + kind)

static func _close(ui: CanvasLayer) -> void:
	var rc: CanvasLayer = App.recap
	if rc and bool(rc.get("open")):
		rc.set("draining", false)
		rc.set_process(false)
		rc.set("open", false)
		rc.visible = false
	var pm: CanvasLayer = App.pause_menu
	if pm and bool(pm.get("open")):
		pm.set("open", false)
		pm.visible = false
	if bool(ui.get("open")):
		ui.close_ui()
	App.ui_open = false
	App.get_tree().paused = false
