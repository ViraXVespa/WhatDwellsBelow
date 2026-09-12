extends Object

const Edit := preload("res://scripts/ui/gear_board_anvil_forge_edit.gd")
const Pick := preload("res://scripts/ui/gear_board_anvil_forge_pick.gd")
const Job := preload("res://scripts/ui/gear_board_anvil_forge_job.gd")

const QTY_MAX := 9
const HOLD_CAP := 3

static func reset(ui: CanvasLayer) -> void:
	ui.forge_type = ""
	ui.forge_rarity = "green"
	ui.forge_ilvl = 1
	ui.forge_qty = 1
	ui.forge_locks = PackedStringArray()
	reset_job(ui)
	ui.set_meta("forge_focus", "")

static func reset_job(ui: CanvasLayer) -> void:
	ui.forge_t = 0.0
	ui.forge_wait = 0.0
	ui.forge_it = {}
	ui.forge_new = {}
	ui.forge_batch = []
	ui.forge_picks = []
	ui.forge_left = 0
	ui.forge_need = 0
	ui.forge_phase = ""

static func fill(ui: CanvasLayer, box: Control, slot: String) -> Control:
	var phase := str(ui.get("forge_phase"))
	if phase == "work":
		return Job._fill_work(ui, box)
	if phase == "pick":
		return Pick._fill_pick(ui, box, slot)
	return Edit._fill_edit(ui, box, slot)

static func start(ui: CanvasLayer) -> void:
	Job.start(ui)

static func finish(ui: CanvasLayer) -> void:
	Job.finish(ui)

static func cancel_job(ui: CanvasLayer) -> void:
	Job.cancel_job(ui)

static func keep_old(ui: CanvasLayer) -> void:
	ui.forge_batch = []
	ui.forge_picks = []
	ui.forge_phase = ""
	ui._st("Kept the old holds. New rolls are gone.")
	_reload(ui, str(ui.gear_sub_slot))

static func refresh_bar(ui: CanvasLayer) -> void:
	Job.refresh_bar(ui)

static func hint_parts(ui: CanvasLayer) -> Array:
	var phase := str(ui.get("forge_phase"))
	if phase == "work":
		return [{"action": "ui_cancel", "verb": "stop queue", "gap": true}]
	if phase == "pick":
		return [
			{"action": "ui_accept", "verb": "toggle", "gap": true},
			{"action": "gear_tip", "verb": "stats", "gap": true},
			{"action": "ui_cancel", "verb": "keep old holds", "gap": true},
		]
	return [
		{"action": "ui_accept", "verb": "set / forge", "gap": true},
		{"action": "ui_cancel", "verb": "close", "gap": true},
	]

static func _reload(ui: CanvasLayer, slot: String) -> void:
	ui.gear_sub = true
	ui.gear_sub_slot = slot
	var Sub = load("res://scripts/ui/gear_board_sub.gd")
	Sub.open_sub(ui, slot)

static func _keep(ui: CanvasLayer, ctl: Control) -> Control:
	if ctl == null or ctl.focus_mode == Control.FOCUS_NONE:
		return ctl
	var tree := ui.get_tree()
	if tree:
		var keep: Control = ctl
		tree.process_frame.connect(func():
			if is_instance_valid(keep) and keep.is_inside_tree() and keep.focus_mode != Control.FOCUS_NONE:
				keep.grab_focus()
		, CONNECT_ONE_SHOT)
	return ctl

