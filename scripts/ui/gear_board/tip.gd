extends Object
const TipPlace := preload("res://scripts/ui/tip_place.gd")
const BtnSkin := preload("res://scripts/ui/btn_skin.gd")

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
	for side: String in ["left", "right", "top", "bottom"]:
		pad.add_theme_constant_override("margin_" + side, 10 if side == "left" or side == "right" else 8)
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

static func _tip_anchor(ui: CanvasLayer) -> Control:
	# Pause menu: tips only on its inventory tab (tab ids). The progress panel has no tabs.
	if ui.get("TAB_INV") != null and str(ui.get("tab")) != str(ui.TAB_INV):
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
	var skin: String = BtnSkin.skin_of(host)
	if str(host.get_meta("skin_now", "")) != skin:
		host.set_meta("skin_now", skin)
		BtnSkin.restyle(host)
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
	pos = _off_stats_head(ui, pos, sz, rr)
	pos = _off_sub(ui, pos, sz, view)
	host.global_position = TipPlace.clamp_pos(pos, sz, view)

## Keep the tip off the "Bonuses from this kit" header row: above the slot if it fits, else under the header.
static func _off_stats_head(ui: CanvasLayer, pos: Vector2, sz: Vector2, rr: Rect2) -> Vector2:
	var mid: Control = ui.get("gear_stats_title") as Control
	if mid == null or not is_instance_valid(mid) or not mid.is_visible_in_tree():
		return pos
	var row: Control = mid.get_parent_control() if mid.get_parent_control() else mid
	var hr: Rect2 = row.get_global_rect()
	if not Rect2(pos, sz).intersects(hr):
		return pos
	var up: float = rr.position.y - sz.y - 8.0
	if up >= 16.0:
		return Vector2(pos.x, up)
	return Vector2(pos.x, hr.end.y + 6.0)

## Keep the tip off the open slot picker: beside it (left, else right), else above/below it.
static func _off_sub(ui: CanvasLayer, pos: Vector2, sz: Vector2, view: Vector2) -> Vector2:
	var p: Control = ui.get_node_or_null("gear_sub_panel") as Control
	if p == null or not p.is_visible_in_tree():
		return pos
	var pr: Rect2 = p.get_global_rect()
	if not Rect2(pos, sz).intersects(pr):
		return pos
	if pr.position.x - sz.x - 8.0 >= 16.0:
		return Vector2(pr.position.x - sz.x - 8.0, pos.y)
	if pr.end.x + 8.0 + sz.x <= view.x - 16.0:
		return Vector2(pr.end.x + 8.0, pos.y)
	if pr.position.y - sz.y - 8.0 >= 16.0:
		return Vector2(pos.x, pr.position.y - sz.y - 8.0)
	return Vector2(pos.x, pr.end.y + 8.0)
