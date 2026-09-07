extends Object

const ThemeS := preload("res://scripts/ui/theme.gd")
const Text := preload("res://scripts/ui/gear_board_text.gd")

static func on(ui: CanvasLayer, key: String) -> bool:
	if ui.has_meta(key):
		return ui.get_meta(key) == true
	return ui.get(key) == true


static func hide_tip(ui: CanvasLayer) -> void:
	ensure_tip(ui)
	var host: Control = ui.get("gear_tip_host")
	if host:
		host.visible = false


static func ensure_tip(ui: CanvasLayer) -> void:
	var host: Node = ui.get_node_or_null("gear_tip_host")
	if host:
		ui.gear_tip_host = host
		var existing: Node = host.get_node_or_null("pad/lab")
		if existing is Label:
			ui.gear_tip = existing
		host.z_index = 80
		return
	var panel := PanelContainer.new()
	panel.name = "gear_tip_host"
	panel.visible = false
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.z_index = 80
	panel.add_theme_stylebox_override("panel", ThemeS.sb(Color(0.09, 0.07, 0.05, 0.97), Color(0.85, 0.68, 0.32)))
	var pad := MarginContainer.new()
	pad.name = "pad"
	pad.add_theme_constant_override("margin_left", 10)
	pad.add_theme_constant_override("margin_right", 10)
	pad.add_theme_constant_override("margin_top", 8)
	pad.add_theme_constant_override("margin_bottom", 8)
	panel.add_child(pad)
	var lab := Label.new()
	lab.name = "lab"
	lab.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	lab.clip_text = false
	lab.custom_minimum_size = Vector2(360, 0)
	lab.add_theme_font_size_override("font_size", 18)
	lab.add_theme_color_override("font_color", Color(0.93, 0.86, 0.72))
	lab.add_theme_color_override("font_outline_color", Color(0.05, 0.03, 0.02))
	lab.add_theme_constant_override("outline_size", 6)
	pad.add_child(lab)
	ui.add_child(panel)
	ui.gear_tip_host = panel
	ui.gear_tip = lab


static func _tip_anchor(ui: CanvasLayer) -> Control:
	var inv_tab: int = 1
	if ui.get("TAB_INV") != null:
		inv_tab = int(ui.TAB_INV)
	if int(ui.get("tab")) != inv_tab:
		return null
	if str(ui.inv_sel) == "stats" or str(ui.inv_sel) == "" or str(ui.inv_sel) == "back":
		return null
	if on(ui, "gear_hover"):
		var Board = load("res://scripts/ui/gear_board.gd")
		var hovered: Control = Board.find_sel(ui)
		if hovered and not hovered.is_queued_for_deletion() and str(hovered.get_meta("inv_key", "")) != "":
			return hovered
		return null
	var f: Control = ui.get_viewport().gui_get_focus_owner()
	if f == null or f.is_queued_for_deletion():
		return null
	if str(f.get_meta("inv_key", "")) == "":
		return null
	return f


static func place_tip(ui: CanvasLayer) -> void:
	if not on(ui, "gear_tip_ready") and not on(ui, "gear_hover"):
		hide_tip(ui)
		return
	var anchor: Control = _tip_anchor(ui)
	if anchor == null:
		hide_tip(ui)
		return
	ensure_tip(ui)
	var host: Control = ui.get("gear_tip_host")
	var lab: Label = ui.get("gear_tip")
	if host == null or lab == null:
		return
	var txt := Text.tooltip(ui)
	if txt == "":
		host.visible = false
		return
	lab.text = txt
	var r: Rect2 = anchor.get_global_rect()
	if not _rect_ready(ui, r):
		var tree := ui.get_tree()
		if tree:
			tree.process_frame.connect(func():
				if is_instance_valid(ui):
					_place_now(ui)
			, CONNECT_ONE_SHOT)
		return
	_place_now(ui)


static func _rect_ready(ui: CanvasLayer, r: Rect2) -> bool:
	if r.size.x < 8.0 or r.size.y < 8.0:
		return false
	var view := ui.get_viewport().get_visible_rect()
	if r.position.x < view.position.x - 8.0:
		return false
	if r.position.y < view.position.y - 8.0:
		return false
	if r.position.y > view.position.y + view.size.y - 8.0:
		return false
	return true


static func _place_now(ui: CanvasLayer) -> void:
	if not on(ui, "gear_tip_ready") and not on(ui, "gear_hover"):
		hide_tip(ui)
		return
	var host: Control = ui.get("gear_tip_host")
	var lab: Label = ui.get("gear_tip")
	if host == null or lab == null:
		return
	var txt := Text.tooltip(ui)
	if txt == "":
		host.visible = false
		return
	var anchor: Control = _tip_anchor(ui)
	if anchor == null or anchor.is_queued_for_deletion():
		hide_tip(ui)
		return
	var rr: Rect2 = anchor.get_global_rect()
	if not _rect_ready(ui, rr):
		hide_tip(ui)
		return
	lab.text = txt
	host.visible = true
	host.reset_size()
	var view := ui.get_viewport().get_visible_rect().size
	var sz: Vector2 = host.get_combined_minimum_size()
	if sz.x < 360.0:
		sz.x = 360.0
	var pos: Vector2
	if bool(ui.get("gear_sub")):
		pos = Vector2(rr.position.x + rr.size.x * 0.5, rr.position.y + rr.size.y + 8.0)
	else:
		pos = Vector2(rr.position.x + maxf(rr.size.x, 1.0) + 12.0, rr.position.y)
		if pos.x + sz.x > view.x - 16.0:
			pos.x = rr.position.x - sz.x - 12.0
	pos.x = clampf(pos.x, 16.0, view.x - sz.x - 16.0)
	if pos.y + sz.y > view.y - 16.0:
		pos.y = rr.position.y - sz.y - 8.0
	pos.y = clampf(pos.y, 16.0, view.y - maxf(sz.y, 80.0) - 16.0)
	host.global_position = pos
