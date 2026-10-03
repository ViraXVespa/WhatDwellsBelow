extends Object

const View := preload("res://scripts/ui/pause_inv/inv_view.gd")
const Act := preload("res://scripts/ui/pause_inv/inv_act.gd")
const GearAct := preload("res://scripts/ui/gear_board/board_act.gd")

static func build(ui: CanvasLayer) -> void:
	View.build(ui)

static func selected(ui: CanvasLayer) -> Dictionary:
	return View.selected(ui)

static func find_sel(ui: CanvasLayer) -> Control:
	return View.find_sel(ui)

static func act(ui: CanvasLayer, msg: String) -> void:
	Act.act(ui, msg)

static func primary(ui: CanvasLayer) -> void:
	Act.primary(ui)

static func drop_item(ui: CanvasLayer) -> void:
	GearAct.drop(ui)
