extends Object

const View := preload("res://scripts/ui/pause_inv_view.gd")
const Act := preload("res://scripts/ui/pause_inv_act.gd")
const GearAct := preload("res://scripts/ui/gear_board_act.gd")


static func build(ui: CanvasLayer) -> void:
	View.build(ui)


static func status_line() -> String:
	return View.status_line()


static func sets_line_text() -> String:
	return View.sets_line_text()


static func slot_btn(ui: CanvasLayer, slot: String) -> Button:
	return View.slot_btn(ui, slot)


static func bag_cell(ui: CanvasLayer, it: Dictionary, index: int) -> Button:
	return View.bag_cell(ui, it, index)


static func item_short(it: Dictionary) -> String:
	return View.item_short(it)


static func item_cell(it: Dictionary) -> String:
	return View.item_cell(it)


static func item_color(it: Dictionary) -> Color:
	return View.item_color(it)


static func selected(ui: CanvasLayer) -> Dictionary:
	return View.selected(ui)


static func selected_slot(ui: CanvasLayer) -> String:
	return View.selected_slot(ui)


static func selected_uid(ui: CanvasLayer) -> int:
	return View.selected_uid(ui)


static func from_bag(ui: CanvasLayer) -> bool:
	return View.from_bag(ui)


static func find_sel(ui: CanvasLayer) -> Control:
	return View.find_sel(ui)


static func refresh_detail(ui: CanvasLayer) -> void:
	View.refresh_detail(ui)


static func detail_text(ui: CanvasLayer, it: Dictionary) -> String:
	return View.detail_text(ui, it)


static func stat_line(ui: CanvasLayer, it: Dictionary) -> String:
	return View.stat_line(ui, it)


static func extract_note(it: Dictionary) -> String:
	return View.extract_note(it)


static func can_use_item(it: Dictionary) -> bool:
	return View.can_use_item(it)


static func can_equip_item(ui: CanvasLayer, it: Dictionary) -> bool:
	return View.can_equip_item(ui, it)


static func act(ui: CanvasLayer, msg: String) -> void:
	Act.act(ui, msg)


static func primary(ui: CanvasLayer) -> void:
	Act.primary(ui)


static func use_item(ui: CanvasLayer) -> void:
	Act.use_item(ui)


static func equip_item(ui: CanvasLayer) -> void:
	Act.equip_item(ui)


static func unequip_item(ui: CanvasLayer) -> void:
	Act.unequip_item(ui)


static func drop_item(ui: CanvasLayer) -> void:
	GearAct.drop(ui)
