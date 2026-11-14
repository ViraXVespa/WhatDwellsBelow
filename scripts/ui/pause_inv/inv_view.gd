extends Object

const Board := preload("res://scripts/ui/gear_board.gd")
const Text := preload("res://scripts/ui/pause_inv/inv_text.gd")

static func build(ui: CanvasLayer) -> void:
	Board.build(ui, "inv")

static func selected(ui: CanvasLayer) -> Dictionary:
	return Board.selected(ui)

static func find_sel(ui: CanvasLayer) -> Control:
	return Board.find_sel(ui)
