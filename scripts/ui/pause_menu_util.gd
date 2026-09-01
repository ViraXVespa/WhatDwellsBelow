# UI helper functions for PauseMenu

const ThemeS := preload("res://scripts/ui/theme.gd")


static func cap(ui: CanvasLayer, text: String, size: int = 18, col: Color = Color(0.9, 0.84, 0.7)) -> Label:
	var l: Label = Label.new()
	l.text = text
	l.autowrap_mode = TextServer.AUTOWRAP_OFF
	l.clip_text = false
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", col)
	return l


static func slider_row(ui: CanvasLayer, title: String, value: float, lo: float, hi: float, step: float, on_change: Callable) -> VBoxContainer:
	var row := VBoxContainer.new()
	row.add_theme_constant_override("separation", 4)
	var top := HBoxContainer.new()
	top.add_child(cap(ui, title, 18, Color(0.9, 0.84, 0.7)))
	top.add_spacer(false)
	top.add_child(cap(ui, "%.2f" % value, 16, Color(0.82, 0.76, 0.66)))
	row.add_child(top)
	var slider := HSlider.new()
	slider.min_value = lo
	slider.max_value = hi
	slider.step = step
	slider.value = value
	slider.custom_minimum_size = Vector2(300, 32)
	slider.value_changed.connect(on_change)
	row.add_child(slider)
	return row


static func blur_tip(ui: CanvasLayer) -> void:
	ui.tip_from = null
	ui.tip_id = ""
	ui.tip_kind = ""


static func hide_tip(ui: CanvasLayer) -> void:
	blur_tip(ui)
	if ui.tip_host:
		ui.tip_host.visible = false


static func paint_tip(ui: CanvasLayer) -> void:
	if ui.tip_lab == null:
		return
	var id: String = ui.tip_id
	var kind: String = ui.tip_kind
	var txt := ""
	if kind == "skill":
		txt = load("res://scripts/ui/pause_skills.gd").tip_for(id)
	elif kind == "sys":
		txt = load("res://scripts/ui/pause_system.gd").tip_for(id)
	if txt == "":
		ui.tip_host.visible = false
		return
	ui.tip_lab.text = txt
	var from: Control = ui.tip_from
	if from and ui.tip_host:
		ui.tip_host.visible = true
		var pos: Vector2 = from.global_position
		var sz: Vector2 = from.size
		var offset: Vector2 = Vector2(sz.x + 20, (sz.y - ui.tip_host.size.y) * 0.5)
		ui.tip_host.global_position = pos + offset


static func confirm(ui: CanvasLayer, fn: Callable, id: String = "anon") -> void:
	ui.pending = true
	ui.pending_id = id
	ui.pending_fn = fn
