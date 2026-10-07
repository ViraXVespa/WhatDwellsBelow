extends Object

const ThemeS := preload("res://scripts/ui/theme.gd")
const Text := preload("res://scripts/ui/gear_board/board_text.gd")
const Act := preload("res://scripts/ui/gear_board/board_act.gd")
const Floor := preload("res://scripts/ui/gear_board/floor.gd")
const Build := preload("res://scripts/ui/gear_board/board_build.gd")
const PromptView := preload("res://scripts/ui/prompt_view.gd")

static func refresh(ui: CanvasLayer) -> void:
	if ui.get("gear_stats_title") != null and ui.gear_stats_title:
		ui.gear_stats_title.text = Text.stats_title(ui)
	if ui.get("gear_stats") != null and ui.gear_stats:
		ui.gear_stats.text = Text.stats_body(ui)
		_journal_stat_rows(ui)
	load("res://scripts/ui/gear_board.gd")._paint_hint(ui)
	if ui.get("gear_page_left") != null and ui.gear_page_left:
		PromptView.fill(ui.gear_page_left, [{"page_prev": true}], 16, ThemeS.INK_SOFT)
	if ui.get("gear_page_right") != null and ui.gear_page_right:
		PromptView.fill(ui.gear_page_right, [{"page_next": true}], 16, ThemeS.INK_SOFT)
	Floor.sync(ui)
	if load("res://scripts/ui/gear_board.gd")._on(ui, "gear_tip_ready") or load("res://scripts/ui/gear_board.gd")._on(ui, "gear_hover"):
		load("res://scripts/ui/gear_board.gd").place_tip(ui)
	else:
		load("res://scripts/ui/gear_board.gd").hide_tip(ui)

static func _journal_stat_rows(ui: CanvasLayer) -> void:
	if not ui.has_meta("journal_stat_rows"):
		return
	var rows: Node = ui.get_meta("journal_stat_rows")
	if not (rows is VBoxContainer) or not is_instance_valid(rows):
		return
	var box: VBoxContainer = rows as VBoxContainer
	for child: Node in box.get_children():
		child.queue_free()
	var body: String = ui.gear_stats.text
	var lines: PackedStringArray = body.split("\n")
	for line: String in lines:
		var shown: String = line.strip_edges()
		if shown == "":
			continue
		var bits: PackedStringArray = shown.rsplit("  ", true, 1)
		var name_lab: Label = Build.plain_lab(bits[0], 18, ThemeS.INK)
		name_lab.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var value_lab: Label = Build.plain_lab("", 18, ThemeS.INK)
		value_lab.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		value_lab.custom_minimum_size = Vector2(96, 0)
		if bits.size() > 1:
			value_lab.text = bits[1].strip_edges()
		var pair: HBoxContainer = HBoxContainer.new()
		pair.add_child(name_lab)
		pair.add_child(value_lab)
		box.add_child(pair)
		var rule: ColorRect = ColorRect.new()
		rule.color = Color(ThemeS.INK.r, ThemeS.INK.g, ThemeS.INK.b, 0.35)
		rule.custom_minimum_size = Vector2(0, 1)
		rule.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		box.add_child(rule)

static func slot_btn(ui: CanvasLayer, slot: String) -> Button:
	var _fac = load("res://scripts/ui/gear_board/board_host.gd")
	var b := Build.build_slot_btn(ui, slot)
	var key := "slot:" + slot
	b.set_meta("inv_key", key)
	_fac._watch_hover(ui, b, key)
	var blocked := str(ui.get("gear_mode")) == "anvil" and (slot == "potion" or slot == "food")
	if blocked:
		b.disabled = true
		b.focus_mode = Control.FOCUS_NONE
	elif str(ui.get("gear_mode")) == "extract":
		b.pressed.connect(func():
			load("res://scripts/ui/progress_ui/inv.gd").send_slot(ui, slot)
		)
	else:
		b.pressed.connect(func():
			if bool(ui.get("gear_sub")):
				return
			ui.inv_sel = key
			load("res://scripts/ui/gear_board.gd")._arm_tip(ui)
			Act.open_sub(ui, slot)
		)
	b.focus_entered.connect(func():
		if load("res://scripts/ui/gear_board.gd")._on(ui, "gear_sub"):
			return
		ui.inv_sel = key
		if load("res://scripts/ui/gear_board.gd")._on(ui, "gear_booting"):
			return
		load("res://scripts/ui/gear_board.gd")._arm_tip(ui)
		refresh(ui)
	)
	return b
