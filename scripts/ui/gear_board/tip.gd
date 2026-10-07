extends Object
const TipPlace := preload("res://scripts/ui/tip_place.gd")

const UiBuild: GDScript = preload("res://scripts/ui/ui_build.gd")
const Text := preload("res://scripts/ui/gear_board/board_text.gd")

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
	var panel: PanelContainer = UiBuild.tip_panel(80)
	panel.name = "gear_tip_host"
	var pad := MarginContainer.new()
	pad.name = "pad"
	pad.add_theme_constant_override("margin_left", 10)
	pad.add_theme_constant_override("margin_right", 10)
	pad.add_theme_constant_override("margin_top", 8)
	pad.add_theme_constant_override("margin_bottom", 8)
	panel.add_child(pad)
	var lab := Label.new()
	lab.name = "lab"
	lab.clip_text = false
	lab.custom_minimum_size = Vector2(360, 0)
	UiBuild.tip_text(lab, 18)
	pad.add_child(lab)
	ui.add_child(panel)
	ui.gear_tip_host = panel
	ui.gear_tip = lab

static func _as_int(v: Variant, fallback: int) -> int:
	if v is int:
		return v
	if v is float:
		return int(v)
	if v is String and str(v).is_valid_int():
		return int(str(v))
	return fallback

static func _tip_anchor(ui: CanvasLayer) -> Control:
	var inv_tab: int = 1
	if ui.get("TAB_INV") != null:
		inv_tab = _as_int(ui.TAB_INV, 1)
	var tab_v: Variant = ui.get("tab")
	if tab_v is int or tab_v is float or (tab_v is String and str(tab_v).is_valid_int()):
		if _as_int(tab_v, inv_tab) != inv_tab:
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
		TipPlace.defer_next_frame(ui.get_tree(), func():
			if is_instance_valid(ui):
				_place_now(ui)
		)
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
	if pos.y + sz.y > view.y - 16.0:
		pos.y = rr.position.y - sz.y - 8.0
	host.global_position = TipPlace.clamp_pos(pos, sz, view)
