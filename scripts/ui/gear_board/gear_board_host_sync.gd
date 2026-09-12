extends Object

const ThemeS := preload("res://scripts/ui/theme.gd")
const Text := preload("res://scripts/ui/gear_board/gear_board_text.gd")
const Act := preload("res://scripts/ui/gear_board/gear_board_act.gd")
const Floor := preload("res://scripts/ui/gear_board/gear_board_floor.gd")
const Tip := preload("res://scripts/ui/gear_board/gear_board_tip.gd")
const Build := preload("res://scripts/ui/gear_board/gear_board_build.gd")
const PromptView := preload("res://scripts/ui/prompt_view.gd")
static func apply_pending() -> void:
	var Board = load("res://scripts/ui/gear_board/gear_board.gd")
	if Board.pending_kit.is_empty():
		return
	for slot: Variant in Board.pending_kit.keys():
		var s := str(slot)
		var it: Dictionary = Board.pending_kit[slot]
		if it.is_empty():
			continue
		if str(it.get("kit_src", "")) == "bank":
			var uid := int(it.get("uid", 0))
			var keep: Array = []
			for raw: Variant in App.prog.bank_items:
				if raw is Dictionary and int(raw.uid) != uid:
					keep.append(raw)
			App.prog.bank_items = keep
		App.prog.slots[s] = it.duplicate(true)
		if s == "weapon":
			App.prog.pick_weapon = str(it.get("weapon", App.prog.pick_weapon))
			App.weapon = App.prog.pick_weapon
		if s == "tool":
			App.prog.tool_type = str(it.get("tool", App.prog.tool_type))
	Board.pending_kit.clear()
	if App.prog.has_method("_clamp_food_slot"):
		App.prog._clamp_food_slot()
	if App.prog.has_method("_refresh_player_hp"):
		App.prog._refresh_player_hp()

static func refresh(ui: CanvasLayer) -> void:
	if ui.get("gear_stats_title") != null and ui.gear_stats_title:
		ui.gear_stats_title.text = Text.stats_title(ui)
	if ui.get("gear_stats") != null and ui.gear_stats:
		ui.gear_stats.text = Text.stats_body(ui)
	load("res://scripts/ui/gear_board/gear_board.gd")._paint_hint(ui)
	if ui.get("gear_page_left") != null and ui.gear_page_left:
		PromptView.fill(ui.gear_page_left, [{"page_prev": true}], 16, Color(0.72, 0.66, 0.52))
	if ui.get("gear_page_right") != null and ui.gear_page_right:
		PromptView.fill(ui.gear_page_right, [{"page_next": true}], 16, Color(0.72, 0.66, 0.52))
	Floor.sync(ui)
	if load("res://scripts/ui/gear_board/gear_board.gd")._on(ui, "gear_tip_ready") or load("res://scripts/ui/gear_board/gear_board.gd")._on(ui, "gear_hover"):
		load("res://scripts/ui/gear_board/gear_board.gd").place_tip(ui)
	else:
		load("res://scripts/ui/gear_board/gear_board.gd").hide_tip(ui)

static func slot_btn(ui: CanvasLayer, slot: String) -> Button:
	var _fac = load("res://scripts/ui/gear_board/gear_board_host.gd")
	var b := Build.build_slot_btn(ui, slot)
	var key := "slot:" + slot
	b.set_meta("inv_key", key)
	_fac._watch_hover(ui, b, key)
	var blocked := str(ui.get("gear_mode")) == "anvil" and (slot == "potion" or slot == "food")
	if blocked:
		b.disabled = true
		b.focus_mode = Control.FOCUS_NONE
	else:
		b.pressed.connect(func():
			if bool(ui.get("gear_sub")):
				return
			ui.inv_sel = key
			load("res://scripts/ui/gear_board/gear_board.gd")._arm_tip(ui)
			Act.open_sub(ui, slot)
		)
	b.focus_entered.connect(func():
		if load("res://scripts/ui/gear_board/gear_board.gd")._on(ui, "gear_sub"):
			return
		ui.inv_sel = key
		if load("res://scripts/ui/gear_board/gear_board.gd")._on(ui, "gear_booting"):
			return
		load("res://scripts/ui/gear_board/gear_board.gd")._arm_tip(ui)
		refresh(ui)
	)
	return b
