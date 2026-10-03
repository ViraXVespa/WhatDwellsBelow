extends Object

const Board := preload("res://scripts/ui/gear_board.gd")
const Text := preload("res://scripts/ui/pause_inv/inv_text.gd")

static func build(ui: CanvasLayer) -> void:
	Board.build(ui, "inv")

static func selected(ui: CanvasLayer) -> Dictionary:
	return Board.selected(ui)

static func selected_slot(ui: CanvasLayer) -> String:
	return Board.selected_slot(ui)

static func from_bag(ui: CanvasLayer) -> bool:
	return str(ui.inv_sel).begins_with("bag:")

static func find_sel(ui: CanvasLayer) -> Control:
	return Board.find_sel(ui)

static func refresh_detail(ui: CanvasLayer) -> void:
	Board.refresh(ui)

static func can_use_item(it: Dictionary) -> bool:
	return Text.can_use_item(it)

static func can_equip_item(ui: CanvasLayer, it: Dictionary) -> bool:
	return Text.can_equip_item(ui, it)
