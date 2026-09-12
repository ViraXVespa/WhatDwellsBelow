extends Object

const ThemeS := preload("res://scripts/ui/theme.gd")
const CatalogS := preload("res://scripts/data/catalog.gd")
const T := preload("res://scripts/data/tunables.gd")
const PauseInv := preload("res://scripts/ui/pause_inv.gd")
const PauseSkills := preload("res://scripts/ui/pause_skills.gd")
const PauseSettings := preload("res://scripts/ui/pause_settings.gd")
const GearAct := preload("res://scripts/ui/gear_board_act.gd")
const Board := preload("res://scripts/ui/gear_board.gd")
const Util := preload("res://scripts/ui/pause_menu_util.gd")
const View := preload("res://scripts/ui/pause_menu_view.gd")
const Pad := preload("res://scripts/ui/menu_pad.gd")
const Prompts := preload("res://scripts/input/prompts.gd")
const PromptView := preload("res://scripts/ui/prompt_view.gd")
const UiText := preload("res://scripts/ui/ui_text.gd")
const Disp := preload("res://scripts/display_mode.gd")
const Confirm := preload("res://scripts/ui/confirm_dlg.gd")
const Split := preload("res://scripts/ui/split_menu.gd")

static func toggle(host: CanvasLayer) -> void:
	if host.open:
		host.close_ui()
	else:
		host.show_menu()



static func show_menu(host: CanvasLayer) -> void:
	host.open = true
	host.visible = true
	App.ui_open = true
	host.get_tree().paused = true
	host.tab = host.TAB_SETTINGS
	host.sys_page = "main"
	host.pending = false
	host.pending_id = ""
	host.rebind_action = ""
	host.inv_sel = "slot:weapon"
	host.gear_mode = "inv"
	host.gear_sub = false
	host.gear_sub_slot = ""
	host.gear_hover = false
	host.set_meta("gear_tip_restore", false)
	Util.hide_tip(host)
	Board.hide_tip(host)
	Board._flag(host, "gear_hover", false)
	Board._flag(host, "gear_tip_ready", false)
	host._rebuild()



static func show_inventory(host: CanvasLayer) -> void:
	if not host.open:
		host.show_menu()
	if host.tab != host.TAB_INV:
		host.tab = host.TAB_INV
		host.sys_page = "main"
		host._rebuild()



static func close_ui(host: CanvasLayer) -> void:
	host.open = false
	host.visible = false
	host.pending = false
	host.pending_id = ""
	host.rebind_action = ""
	host.sys_page = "main"
	host.gear_sub = false
	host.gear_sub_slot = ""
	host.gear_hover = false
	host.set_meta("gear_tip_restore", false)
	Confirm.close(host)
	var old: Node = host.get_node_or_null("gear_sub_panel")
	if old:
		old.queue_free()
	if host.gear_tip_host:
		host.gear_tip_host.visible = false
	Util.hide_tip(host)
	Board.hide_tip(host)
	Board._flag(host, "gear_hover", false)
	Board._flag(host, "gear_tip_ready", false)
	App.ui_open = false
	host.get_tree().paused = false
	App.save_now()
	App.swallow_close_pad()
	App.wake_web_pad()
	Disp.consume_web_esc()



static func _wipe(_host: CanvasLayer, n: Node) -> void:
	while n.get_child_count() > 0:
		var c: Node = n.get_child(0)
		n.remove_child(c)
		c.queue_free()



static func _store_tip_restore(host: CanvasLayer) -> void:
	var tip: Control = host.gear_tip_host
	host.set_meta("gear_tip_restore", tip != null and tip.visible)



static func _rebuild(host: CanvasLayer) -> void:
	Util.hide_tip(host)
	Board.hide_tip(host)
	Board._flag(host, "gear_hover", false)
	Board._flag(host, "gear_tip_ready", false)
	host.gear_sub = false
	host.gear_sub_slot = ""
	var old: Node = host.get_node_or_null("gear_sub_panel")
	if old:
		old.queue_free()
	host._wipe(host.tabs)
	host._wipe(host.box)
	host.focus_btn = null
	host.status = null
	host.inv_detail = null
	host.inv_btn_use = null
	host.inv_btn_equip = null
	host.inv_btn_unequip = null
	host.inv_btn_drop = null
	host.gear_tip = null
	host.gear_stats = null
	host.gear_stats_title = null
	host.gear_page_left = null
	host.gear_page_right = null
	var names: PackedStringArray = PackedStringArray(["Settings", "Inventory", "Skills"])
	for i: int in 3:
		var ii: int = i
		var b: Button = ThemeS.btn(names[i], func():
			if host.tab == host.TAB_INV and ii != host.TAB_INV:
				host._store_tip_restore()
			host.tab = ii
			host.sys_page = "main"
			host._rebuild()
		)
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.custom_minimum_size = UiText.min_size(160.0, 44.0)
		if i == host.tab:
			var ink := Color(0.92, 0.84, 0.62)
			b.add_theme_color_override("font_color", ink)
			b.add_theme_color_override("font_hover_color", ink)
			b.add_theme_color_override("font_focus_color", ink)
			b.add_theme_stylebox_override("normal", ThemeS.sb(Color(0.3, 0.22, 0.14), Color(0.75, 0.58, 0.28)))
			b.add_theme_stylebox_override("focus", ThemeS.sb(Color(0.3, 0.22, 0.14), Color(0.75, 0.58, 0.28)))
			b.add_theme_stylebox_override("hover", ThemeS.sb(Color(0.38, 0.28, 0.16), Color(0.95, 0.78, 0.35)))
			b.add_theme_stylebox_override("pressed", ThemeS.sb(Color(0.38, 0.28, 0.16), Color(0.95, 0.78, 0.35)))
		host.tabs.add_child(b)
	PromptView.fill(host.tab_left, [{"action": "tab_left"}], 16, Color(0.72, 0.66, 0.52))
	PromptView.fill(host.tab_right, [{"action": "tab_right"}], 16, Color(0.72, 0.66, 0.52))
	match host.tab:
		host.TAB_SETTINGS:
			host._system()
		host.TAB_INV:
			host._inv()
		_:
			host._skills()
	host._paint_menu_hint()
	host.call_deferred("_focus")
	if host.tab_scroll and host.tabs.get_child_count() > host.tab:
		host.tab_scroll.ensure_control_visible(host.tabs.get_child(host.tab) as Control)



static func _paint_menu_hint(host: CanvasLayer) -> void:
	if host.tab == host.TAB_INV:
		return
	PromptView.footer(host)



static func _cycle_tab(host: CanvasLayer, dir: int) -> void:
	if host.tab == host.TAB_INV:
		host._store_tip_restore()
	host.tab = posmod(host.tab + dir, 3)
	host.sys_page = "main"
	host.pending = false
	host.pending_id = ""
	host.rebind_action = ""
	host._rebuild()



static func _focus(host: CanvasLayer) -> void:
	if host.tab == host.TAB_INV:
		var hit: Control = host._inv_find_sel()
		if hit and not hit.is_queued_for_deletion():
			hit.grab_focus()
			Board._flag(host, "gear_booting", false)
			if bool(host.get_meta("gear_tip_restore", false)):
				Board._arm_tip(host)
			else:
				Board.hide_tip(host)
				Board._flag(host, "gear_tip_ready", false)
			Board.refresh(host)
			return
	if host.focus_btn and not host.focus_btn.is_queued_for_deletion() and not host.tabs.is_ancestor_of(host.focus_btn):
		host.focus_btn.grab_focus()
		return
	for n: Node in host.box.find_children("*", "Control", true, false):
		if n.is_queued_for_deletion():
			continue
		if n is BaseButton or n is Range:
			var c: Control = n as Control
			if c.focus_mode == Control.FOCUS_NONE:
				continue
			if n is BaseButton and (n as BaseButton).disabled:
				continue
			c.grab_focus()
			return
	if host.focus_btn and not host.focus_btn.is_queued_for_deletion():
		host.focus_btn.grab_focus()
		return
	for n: Node in host.find_children("*", "Button", true, false):
		if n.is_queued_for_deletion():
			continue
		(n as Button).grab_focus()
		return



static func _back(host: CanvasLayer) -> void:
	if Confirm.is_open(host):
		Confirm.close(host)
		return
	if host.gear_sub:
		GearAct.close_sub(host)
		return
	if host.tab == host.TAB_SETTINGS:
		var sh: Node = host._settings_host()
		if sh and Split.back(sh):
			return
	host.close_ui()



static func _process(host: CanvasLayer, delta: float) -> void:
	if host.open and Disp.consume_web_esc():
		host._back()
	if host.open and host.tab == host.TAB_INV:
		GearAct.tick_x(host, delta)



static func _input(host: CanvasLayer, event: InputEvent) -> void:
	if not host.open:
		return
	if Confirm.is_open(host):
		if Pad.is_back(event):
			Confirm.close(host)
			host.get_viewport().set_input_as_handled()
		return
	var td := Pad.tab_delta(event)
	if td != 0:
		host._cycle_tab(td)
		host.get_viewport().set_input_as_handled()
		return
	if Pad.is_back(event):
		host._back()
		host.get_viewport().set_input_as_handled()
		return



static func _unhandled_input(host: CanvasLayer, event: InputEvent) -> void:
	if not host.open:
		return
	if host.tab == host.TAB_INV:
		if GearAct.input_tick(host, event):
			host.get_viewport().set_input_as_handled()
			return

