extends Object

## Recap panel chrome.

const ThemeS := preload("res://scripts/ui/theme.gd")


static func build(host: CanvasLayer) -> void:
	layer = 70
	visible = false
	process_mode = Node.PROCESS_MODE_ALWAYS
	var dim := ColorRect.new()
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.color = Color(0.04, 0.03, 0.03, 0.92)
	host.add_child(dim)
	var panel := ColorRect.new()
	panel.color = Color(0.12, 0.09, 0.07, 0.96)
	panel.position = Vector2(220, 40)
	panel.size = Vector2(1480, 1000)
	host.add_child(panel)
	var edge := ColorRect.new()
	edge.color = Color(0.55, 0.42, 0.22, 1)
	edge.position = Vector2(220, 40)
	edge.size = Vector2(1480, 8)
	host.add_child(edge)
	host.scroll = ScrollContainer.new()
	host.scroll.position = Vector2(244, 72)
	host.scroll.size = Vector2(1432, 940)
	host.scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	host.scroll.focus_mode = Control.FOCUS_NONE
	host.scroll.follow_focus = true
	host.add_child(host.scroll)
	host.box = VBoxContainer.new()
	host.box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	host.box.custom_minimum_size = Vector2(1400, 0)
	host.box.add_theme_constant_override("separation", 8)
	host.scroll.add_child(host.box)
	make_tip(host)

static func make_tip(host: CanvasLayer) -> void:
	host.tip_host = PanelContainer.new()
	host.tip_host.visible = false
	host.tip_host.mouse_filter = Control.MOUSE_FILTER_IGNORE
	host.tip_host.z_index = 20
	host.tip_host.add_theme_stylebox_override("panel", ThemeS.sb(Color(0.09, 0.07, 0.05, 0.97), Color(0.85, 0.68, 0.32)))
	host.tip_lab = Label.new()
	host.tip_lab.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	host.tip_lab.custom_minimum_size = Vector2(380, 0)
	host.tip_lab.add_theme_font_size_override("font_size", 18)
	host.tip_lab.add_theme_color_override("font_color", Color(0.93, 0.86, 0.72))
	host.tip_lab.add_theme_color_override("font_outline_color", Color(0.05, 0.03, 0.02))
	host.tip_lab.add_theme_constant_override("outline_size", 6)
	host.tip_host.add_child(host.tip_lab)
	host.add_child(host.tip_host)