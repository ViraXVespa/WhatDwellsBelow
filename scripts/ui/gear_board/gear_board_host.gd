extends Object

const ThemeS := preload("res://scripts/ui/theme.gd")
const Text := preload("res://scripts/ui/gear_board/gear_board_text.gd")
const Act := preload("res://scripts/ui/gear_board/gear_board_act.gd")
const Floor := preload("res://scripts/ui/gear_board/gear_board_floor.gd")
const Tip := preload("res://scripts/ui/gear_board/gear_board_tip.gd")
const Build := preload("res://scripts/ui/gear_board/gear_board_build.gd")
const PromptView := preload("res://scripts/ui/prompt_view.gd")
const HostBuild := preload("res://scripts/ui/gear_board/gear_board_host_build.gd")
const Sync := preload("res://scripts/ui/gear_board/gear_board_host_sync.gd")

static func ensure_host(ui: CanvasLayer) -> void:
	HostBuild.ensure_host(ui)

static func _watch_hover(ui: CanvasLayer, b: Control, key: String) -> void:
	b.mouse_entered.connect(func():
		if bool(ui.get("gear_sub")):
			return
		load("res://scripts/ui/gear_board/gear_board.gd")._flag(ui, "gear_hover", true)
		load("res://scripts/ui/gear_board/gear_board.gd")._arm_tip(ui)
		ui.inv_sel = key
		Sync.refresh(ui)
	)
	b.mouse_exited.connect(func():
		if bool(ui.get("gear_sub")):
			return
		load("res://scripts/ui/gear_board/gear_board.gd")._flag(ui, "gear_hover", false)
		var tree := ui.get_tree()
		if tree == null:
			return
		tree.process_frame.connect(func():
			if not is_instance_valid(ui):
				return
			if bool(ui.get("gear_sub")):
				return
			if load("res://scripts/ui/gear_board/gear_board.gd")._on(ui, "gear_hover"):
				return
			load("res://scripts/ui/gear_board/gear_board.gd").hide_tip(ui)
		, CONNECT_ONE_SHOT)
	)

static func build(ui: CanvasLayer, mode: String) -> void:
	HostBuild.build(ui, mode)

static func slot_btn(ui: CanvasLayer, slot: String) -> Button:
	return Sync.slot_btn(ui, slot)

static func bag_grid(ui: CanvasLayer) -> void:
	ui.box.add_child(ThemeS.lab("Bag", 20, Color(0.88, 0.82, 0.7)))
	var grid := GridContainer.new()
	grid.columns = 7
	grid.add_theme_constant_override("h_separation", 8)
	grid.add_theme_constant_override("v_separation", 8)
	var cap: int = maxi(int(App.bal.bag_cap), App.prog.bag.size())
	for i: int in cap:
		var it: Dictionary = {}
		if i < App.prog.bag.size() and App.prog.bag[i] is Dictionary:
			it = App.prog.bag[i]
		grid.add_child(bag_cell(ui, it))
	ui.box.add_child(grid)

static func bag_cell(ui: CanvasLayer, it: Dictionary) -> Button:
	var b := Build.build_bag_cell(ui, it)
	if not it.is_empty():
		var key := "bag:" + str(int(it.uid))
		b.set_meta("inv_key", key)
		_watch_hover(ui, b, key)
		b.pressed.connect(func():
			if bool(ui.get("gear_sub")):
				return
			ui.inv_sel = key
			load("res://scripts/ui/gear_board/gear_board.gd")._arm_tip(ui)
			Sync.refresh(ui)
			Act.bag_primary(ui)
		)
		b.focus_entered.connect(func():
			if load("res://scripts/ui/gear_board/gear_board.gd")._on(ui, "gear_sub"):
				return
			ui.inv_sel = key
			if load("res://scripts/ui/gear_board/gear_board.gd")._on(ui, "gear_booting"):
				return
			load("res://scripts/ui/gear_board/gear_board.gd")._arm_tip(ui)
			Sync.refresh(ui)
		)
	return b

static func find_sel(ui: CanvasLayer) -> Control:
	if str(ui.inv_sel) == "":
		return null
	var sub: Node = ui.get_node_or_null("gear_sub_panel")
	if sub and not sub.is_queued_for_deletion():
		for n2: Node in sub.find_children("*", "Button", true, false):
			if n2.is_queued_for_deletion():
				continue
			if str(n2.get_meta("inv_key", "")) == ui.inv_sel:
				return n2 as Control
	if ui.box:
		for n: Node in ui.box.find_children("*", "Control", true, false):
			if n.is_queued_for_deletion():
				continue
			if str(n.get_meta("inv_key", "")) == ui.inv_sel:
				return n as Control
	return null

static func refresh(ui: CanvasLayer) -> void:
	Sync.refresh(ui)

static func apply_pending() -> void:
	Sync.apply_pending()
