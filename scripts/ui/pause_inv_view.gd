extends Object

const Board := preload("res://scripts/ui/gear_board.gd")
const Text := preload("res://scripts/ui/pause_inv_text.gd")


static func build(ui: CanvasLayer) -> void:
	Board.build(ui, "inv")


static func status_line() -> String:
	return ""


static func sets_line_text() -> String:
	return ""


static func slot_btn(ui: CanvasLayer, slot: String) -> Button:
	return Board.slot_btn(ui, slot)


static func bag_cell(ui: CanvasLayer, it: Dictionary, _index: int) -> Button:
	return Board.bag_cell(ui, it)


static func item_short(it: Dictionary) -> String:
	return Text.item_short(it)


static func item_cell(it: Dictionary) -> String:
	return Text.item_cell(it)


static func item_color(it: Dictionary) -> Color:
	return Text.item_color(it)


static func selected(ui: CanvasLayer) -> Dictionary:
	return Board.selected(ui)


static func selected_slot(ui: CanvasLayer) -> String:
	return Board.selected_slot(ui)


static func selected_uid(ui: CanvasLayer) -> int:
	return Text.selected_uid(ui)


static func from_bag(ui: CanvasLayer) -> bool:
	return str(ui.inv_sel).begins_with("bag:")


static func find_sel(ui: CanvasLayer) -> Control:
	return Board.find_sel(ui)


static func refresh_detail(ui: CanvasLayer) -> void:
	Board.refresh(ui)


static func detail_text(ui: CanvasLayer, it: Dictionary) -> String:
	return Text.detail_text(ui, it)


static func stat_line(ui: CanvasLayer, it: Dictionary) -> String:
	return Text.stat_line(ui, it)


static func extract_note(it: Dictionary) -> String:
	return Text.extract_note(it)


static func can_use_item(it: Dictionary) -> bool:
	return Text.can_use_item(it)


static func can_equip_item(ui: CanvasLayer, it: Dictionary) -> bool:
	return Text.can_equip_item(ui, it)
