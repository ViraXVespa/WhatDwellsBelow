extends Object

const Board := preload("res://scripts/ui/gear_board.gd")
const Sub := preload("res://scripts/ui/gear_board/board_sub.gd")
const Items := preload("res://scripts/ui/gear_board/act_items.gd")
const Inp := preload("res://scripts/ui/gear_board/act_input.gd")

static func locked_slot(slot: String) -> bool:
	return Items.locked_slot(slot)

static func swallow_cancel() -> void:
	Inp.swallow_cancel()

static func swallowing() -> bool:
	return Inp.swallowing()

static func town_kit(ui: CanvasLayer) -> bool:
	if str(ui.get("gear_mode")) == "anvil":
		return false
	return Board.is_loadout(ui) or not App.in_dungeon

static func rebuild(ui: CanvasLayer) -> void:
	Items.rebuild(ui)

static func st(ui: CanvasLayer, msg: String) -> void:
	Items.st(ui, msg)

static func open_sub(ui: CanvasLayer, slot: String) -> void:
	Sub.open_sub(ui, slot)

static func close_sub(ui: CanvasLayer) -> void:
	Sub.close_sub(ui)

static func pick(ui: CanvasLayer, slot: String, row: Dictionary) -> void:
	Sub.pick(ui, slot, row)

static func bag_primary(ui: CanvasLayer) -> void:
	Items.bag_primary(ui)

static func drop(ui: CanvasLayer) -> void:
	Items.drop(ui)

static func floor_step(ui: CanvasLayer, d: int) -> void:
	ui.loadout_floor = clampi(int(ui.loadout_floor) + d, 1, App.prog.deepest)
	Board.refresh(ui)

static func enter(ui: CanvasLayer) -> void:
	if App.present and App.present.has_method("cover_enter"):
		App.present.cover_enter()
	App.prog.tool_type = str(ui.loadout_tool)
	App.prog.pick_weapon = str(ui.loadout_wpn)
	App.prog.start_floor = int(ui.loadout_floor)
	App.weapon = str(ui.loadout_wpn)
	Board.pending_kit.clear()
	for s: String in App.prog.SLOTS:
		var it: Dictionary = App.prog.slots.get(s, {})
		if it is Dictionary and not it.is_empty():
			Board.pending_kit[s] = it.duplicate(true)
	App.enter_dungeon()

static func tick_x(ui: CanvasLayer, delta: float) -> void:
	Inp.tick_x(ui, delta)

static func input_tick(ui: CanvasLayer, event: InputEvent) -> bool:
	return Inp.input_tick(ui, event)

static func handle_event(ui: CanvasLayer, event: InputEvent) -> bool:
	return Inp.handle_event(ui, event)
