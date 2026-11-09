extends Object

## Deep menu sweep (phase 6, camp; smoke_escape.gd): opens each hub menu, presses the focused button 1-3 times,
## then sends ui_cancel until it closes (at most depth + 1 backs, a focus owner while open). A press that takes the
## menu's way out of the hub (Loadout's enter) really changes scene since present.wait_painted returns headless
## (006b19cc): the row then checks the dungeon loaded and the camp came back with its ui, and the sweep goes on in
## the new camp. Callers re-resolve the scene (tree.current_scene) after run.

const WAIT := 900  # frames for one scene change
static var ESC: GDScript  # smoke_escape.gd (load at run: it preloads this file)

static func run(tree: SceneTree, menus: Array) -> bool:
	ESC = load("res://scripts/debug/smoke/smoke_escape.gd")
	var ok: bool = true
	for m: Array in menus:
		for depth: int in [1, 2, 3]:
			var scene0: int = tree.current_scene.get_instance_id()
			(m[1] as Callable).call()
			for i: int in 3:
				await tree.process_frame
			for d: int in depth:
				if _leaving(tree, scene0):
					break
				var f: Control = tree.root.gui_get_focus_owner()
				if f is BaseButton:
					(f as BaseButton).pressed.emit()
				await tree.create_timer(0.15, true, false, true).timeout
			if _leaving(tree, scene0):
				var back: String = await _round_trip(tree, scene0)
				printerr("P6: deep_%s_%d left_scene=true %s" % [m[0], depth, back])
				ok = ok and back == "dungeon=true camp=true"
				continue
			var lost: bool = App.ui_open and tree.root.gui_get_focus_owner() == null
			var n: int = 0
			while App.ui_open and n < 6:
				var a := InputEventAction.new()
				a.action = "ui_cancel"
				ESC._send(a, true)
				await tree.process_frame
				ESC._send(a, false)
				await tree.create_timer(0.15, true, false, true).timeout
				n += 1
			printerr("P6: deep_%s_%d closed=%s backs=%d focus_lost=%s" % [m[0], depth, not App.ui_open, n, lost])
			ok = ok and not App.ui_open and n <= depth + 1
			ESC._force_close(tree)
			for i: int in 2:
				await tree.process_frame
	return ok

## The enter cover is up, the dungeon flag is set, or the scene already changed.
static func _leaving(tree: SceneTree, scene0: int) -> bool:
	var enter: bool = App.present != null and bool(App.present.get("_enter_load"))
	return enter or App.in_dungeon or _sid(tree) != scene0

## Wait for the dungeon scene, send the player back to camp, wait for a ready camp with its ui.
static func _round_trip(tree: SceneTree, scene0: int) -> String:
	var n: int = 0
	while n < WAIT and not (_sid(tree) != scene0 and _ready(tree) and App.in_dungeon):
		await tree.process_frame
		n += 1
	var dungeon: bool = n < WAIT
	var left: int = _sid(tree)
	App.go_camp()
	n = 0
	while n < WAIT and not (_sid(tree) != left and _ready(tree) and tree.current_scene.get("ui") != null):
		await tree.process_frame
		n += 1
	for i: int in 10:
		await tree.process_frame
	ESC._force_close(tree)
	return "dungeon=%s camp=%s" % [dungeon, n < WAIT and not App.in_dungeon]

static func _ready(tree: SceneTree) -> bool:
	return tree.current_scene != null and tree.current_scene.is_node_ready()

static func _sid(tree: SceneTree) -> int:
	return 0 if tree.current_scene == null else tree.current_scene.get_instance_id()
