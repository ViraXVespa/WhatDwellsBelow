extends Object

## Menu escape sweep (phase 6, camp). Opens every hub menu, sends each bound Back event
## (ui_cancel and pause, key and pad), and asserts the menu closed, the tree unpaused and
## a focus owner existed while it was open. Then taps the footer Back chip (mouse/touch).
## Prints "P6: esc_<menu>_<how>=true|false" rows and "P6: escape_ok=".

const PromptView := preload("res://scripts/ui/prompt_view.gd")
const Tok: GDScript = preload("res://scripts/ui/ui_tokens.gd")

static func run(host: Node) -> void:
	var tree: SceneTree = host.get_tree()
	var ui: Variant = host.get("ui")
	var ok: bool = true
	var menus: Array = [
		["crystal", func(): load("res://scripts/ui/crystal_ui.gd").open(_spot(host))],
		["inv", func(): ui.open_inventory()],
		["extract", func(): ui.open_extract("gate", null)],
		["shop", func(): ui.open_shop(null)],
		["vendor", func(): ui.open_vendor()],
		["controls", func(): ui.open_controls()],
		["flavor", func(): ui.open_flavor("Dumpster", "x")],
		["quest", func(): ui.open_quest()],
		["anvil", func(): ui.open_anvil()],
		["loadout", func(): ui.open_loadout()],
		["pause", func(): App.pause_menu.show_menu()],
	]
	for m: Array in menus:
		for depth: int in [1, 2, 3]:
			(m[1] as Callable).call()
			for i: int in 3:
				await tree.process_frame
			for d: int in depth:
				var f: Control = host.get_viewport().gui_get_focus_owner()
				if f is BaseButton:
					(f as BaseButton).pressed.emit()
				await tree.create_timer(0.15, true, false, true).timeout
			var lost: bool = App.ui_open and host.get_viewport().gui_get_focus_owner() == null
			var n: int = 0
			while App.ui_open and n < 6:
				var a := InputEventAction.new()
				a.action = "ui_cancel"
				_send(a, true)
				await tree.process_frame
				_send(a, false)
				await tree.create_timer(0.15, true, false, true).timeout
				n += 1
			printerr("P6: deep_%s_%d closed=%s backs=%d focus_lost=%s" % [m[0], depth, not App.ui_open, n, lost])
			ok = ok and not App.ui_open and n <= depth + 1
			_force_close(tree)
			for i: int in 2:
				await tree.process_frame
	var hows: Array = []
	for act: String in ["ui_cancel", "pause"]:
		for ev: InputEvent in InputMap.action_get_events(act):
			if ev is InputEventKey or ev is InputEventJoypadButton:
				hows.append([act + "_" + ev.get_class().replace("InputEvent", "").to_lower(), ev])
	hows.append(["action", null])
	hows.append(["chip_tap", "tap"])
	for m: Array in menus:
		for h: Array in hows:
			var name: String = str(m[0]) + "_" + str(h[0])
			(m[1] as Callable).call()
			for i: int in 3:
				await tree.process_frame
			var focus: Control = host.get_viewport().gui_get_focus_owner()
			var fname: String = str(focus.name) if focus else "none"
			var opened: bool = App.ui_open
			if h[1] is String:
				var chip: Control = _chip(tree, "ui_cancel")
				if chip == null:
					printerr("P6: esc_%s=false no_chip" % name)
					ok = false
					_force_close(tree)
					continue
				var c: Vector2 = chip.get_global_rect().get_center()
				var mm := InputEventMouseMotion.new()
				mm.position = c
				mm.global_position = c
				tree.root.push_input(mm, true)
				await tree.process_frame
				_click(c, true)
				await tree.process_frame
				_click(c, false)
			else:
				var ev: InputEvent
				if h[1] == null:
					var a := InputEventAction.new()
					a.action = "ui_cancel"
					ev = a
				else:
					ev = (h[1] as InputEvent).duplicate()
				_send(ev, true)
				await tree.process_frame
				_send(ev, false)
			for i: int in 4:
				await tree.process_frame
			var closed: bool = not App.ui_open and not tree.paused
			var stuck: bool = Input.is_action_pressed("ui_cancel") or Input.is_action_pressed("ui_accept")
			var row_ok: bool = opened and closed and fname != "none" and not stuck
			printerr("P6: esc_%s=%s opened=%s closed=%s stuck=%s focus=%s" % [name, row_ok, opened, closed, stuck, fname])
			ok = ok and row_ok
			_force_close(tree)
			for i: int in 2:
				await tree.process_frame
	for m2: Array in [["controls", func(): ui.open_controls()], ["flavor", func(): ui.open_flavor("Dumpster", "x")]]:
		(m2[1] as Callable).call()
		for i: int in 3:
			await tree.process_frame
		var chip2: Control = _chip(tree, "ui_accept")
		if chip2:
			var c2: Vector2 = chip2.get_global_rect().get_center()
			_click(c2, true)
			await tree.process_frame
			_click(c2, false)
			for i: int in 4:
				await tree.process_frame
		var tap_ok: bool = chip2 != null and not App.ui_open
		printerr("P6: tap_accept_%s=%s" % [m2[0], tap_ok])
		ok = ok and tap_ok
		_force_close(tree)
		await tree.process_frame
	ui.open_vendor()
	for i: int in 3:
		await tree.process_frame
	var tc: Control = _chip(tree, "ui_cancel")
	var tint_ok: bool = false
	if tc:
		tc.mouse_entered.emit()
		var hov: bool = tc.modulate == Tok.CHIP_HOVER
		tc.mouse_exited.emit()
		tint_ok = hov and tc.modulate == Tok.CHIP_REST and tc.focus_mode == Control.FOCUS_NONE
	printerr("P6: chip_tint_ok=" + str(tint_ok))
	ok = ok and tint_ok
	_force_close(tree)
	App.recap.play("death")
	for i: int in 3:
		await tree.process_frame
	var rb: Control = _chip(tree, "ui_cancel")
	var rc: Control = _chip(tree, "ui_accept")
	var recap_ok: bool = rb == null and rc != null
	printerr("P6: recap_no_back=" + str(recap_ok))
	ok = ok and recap_ok
	App.recap.set("open", false)
	App.recap.set("draining", false)
	App.recap.visible = false
	_force_close(tree)
	for i: int in 3:
		await tree.process_frame
	var bleed_ok: bool = await _bleed(host, tree, ui)
	printerr("P6: no_bleed_ok=" + str(bleed_ok))
	ok = ok and bleed_ok
	printerr("P6: escape_ok=" + str(ok))
	assert(ok)

static func _spot(host: Node) -> Node:
	var s := GDScript.new()
	s.source_code = "extends Node3D\nvar crystal_cl := 1\n"
	s.reload()
	var n: Node3D = s.new()
	host.add_child(n)
	return n

## The press that closes a menu (a Back-chip click is also the attack mouse button; pad A on Leave) must
## not reach the world while it is still held: no attack or interact, then a fresh press works again.
static func _bleed(host: Node, tree: SceneTree, ui: Variant) -> bool:
	var p: Node = tree.get_first_node_in_group("player")
	var ok: bool = true
	for how: String in ["chip", "pad_a"]:
		var w0: int = 0
		while int(p.get("atk_state")) != 0 and w0 < 240:
			await tree.process_frame
			w0 += 1
		ui.open_flavor("Dumpster", "x")
		for i: int in 3:
			await tree.process_frame
		if how == "chip":
			Input.action_press("attack")
			var c: Control = _chip(tree, "ui_cancel")
			var at: Vector2 = c.get_global_rect().get_center()
			_click(at, true)
		else:
			Input.action_press("interact")
			var a := InputEventJoypadButton.new()
			a.button_index = JOY_BUTTON_A
			_send(a, true)
			await tree.process_frame
			if App.ui_open:
				var f: Control = host.get_viewport().gui_get_focus_owner()
				if f is BaseButton:
					(f as BaseButton).pressed.emit()
		var leak: bool = false
		for i: int in 8:
			await tree.process_frame
			var w: Array = [App.pad_held("attack"), App.pad_held("interact"), App.pad_just("interact"), int(p.get("atk_state")), App.ui_open, i]
			if w[0] or w[1] or w[2] or w[3] != 0:
				leak = true
				printerr("P6: leak_%s %s" % [how, w])
		var closed: bool = not App.ui_open
		Input.action_release("attack")
		Input.action_release("interact")
		var up := InputEventJoypadButton.new()
		up.button_index = JOY_BUTTON_A
		_send(up, false)
		_click(Vector2.ZERO, false)
		for i: int in 3:
			await tree.process_frame
		Input.action_press("attack")
		await tree.process_frame
		var fresh: bool = App.pad_held("attack")
		Input.action_release("attack")
		for i: int in 30:
			await tree.process_frame
		printerr("P6: bleed_%s closed=%s leak=%s fresh_ok=%s" % [how, closed, leak, fresh])
		ok = ok and closed and not leak and fresh
		_force_close(tree)
	return ok

static func _send(ev: InputEvent, down: bool) -> void:
	if ev is InputEventKey:
		(ev as InputEventKey).pressed = down
	elif ev is InputEventJoypadButton:
		(ev as InputEventJoypadButton).pressed = down
	elif ev is InputEventAction:
		(ev as InputEventAction).pressed = down
	Input.parse_input_event(ev)

static func _click(pos: Vector2, down: bool) -> void:
	var mb := InputEventMouseButton.new()
	mb.button_index = MOUSE_BUTTON_LEFT
	mb.pressed = down
	mb.position = pos
	mb.global_position = pos
	(Engine.get_main_loop() as SceneTree).root.push_input(mb, true)

static func _chip(tree: SceneTree, action: String) -> Control:
	for n: Node in tree.root.find_children(PromptView.BAR_NAME, "", true, false):
		if not (n is Control) or not (n as Control).is_visible_in_tree():
			continue
		for c: Node in n.get_children():
			if c is Control and str(c.get_meta("prompt_action", "")) == action:
				return c as Control
	return null

static func _force_close(tree: SceneTree) -> void:
	for n: Node in tree.get_nodes_in_group("crystal_ui"):
		n.call("close_ui")
	if App.pause_menu and bool(App.pause_menu.get("open")):
		App.pause_menu.close_ui()
	var ui: Node = tree.current_scene.get("ui") if tree.current_scene else null
	if ui and bool(ui.get("open")):
		ui.close_ui()
	if App.present and App.present.visible:
		App.present.hide_overlay()
	App.ui_open = false
	tree.paused = false
