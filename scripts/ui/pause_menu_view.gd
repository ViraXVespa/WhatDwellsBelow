extends Object

const ThemeS := preload("res://scripts/ui/theme.gd")
const UiText := preload("res://scripts/ui/ui_text.gd")


static func build(host: CanvasLayer) -> void:
	host.layer = 55
	host.visible = false
	host.process_mode = Node.PROCESS_MODE_ALWAYS
	var dim: ColorRect = ColorRect.new()
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.color = Color(0.03, 0.02, 0.02, 0.78)
	host.add_child(dim)
	var panel: ColorRect = ColorRect.new()
	panel.color = Color(0.13, 0.1, 0.08, 0.96)
	panel.position = Vector2(220, 40)
	panel.size = Vector2(1480, 1000)
	host.add_child(panel)
	var edge: ColorRect = ColorRect.new()
	edge.color = Color(0.55, 0.42, 0.22, 1)
	edge.position = Vector2(220, 40)
	edge.size = Vector2(1480, 8)
	host.add_child(edge)
	host.tab_wrap = HBoxContainer.new()
	host.tab_wrap.position = Vector2(244, 60)
	host.tab_wrap.size = Vector2(1432, 56)
	host.tab_wrap.add_theme_constant_override("separation", 10)
	host.add_child(host.tab_wrap)
	host.tab_left = HBoxContainer.new()
	host.tab_left.mouse_filter = Control.MOUSE_FILTER_IGNORE
	host.tab_left.custom_minimum_size = Vector2(36, 28)
	host.tab_right = HBoxContainer.new()
	host.tab_right.mouse_filter = Control.MOUSE_FILTER_IGNORE
	host.tab_right.custom_minimum_size = Vector2(36, 28)
	host.tab_scroll = ScrollContainer.new()
	host.tab_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	host.tab_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	host.tab_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_SHOW_NEVER
	host.tab_scroll.follow_focus = true
	host.tabs = HBoxContainer.new()
	host.tabs.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	host.tabs.add_theme_constant_override("separation", 12)
	host.tab_scroll.add_child(host.tabs)
	host.tab_wrap.add_child(host.tab_left)
	host.tab_wrap.add_child(host.tab_scroll)
	host.tab_wrap.add_child(host.tab_right)
	host.scroll = ScrollContainer.new()
	host.scroll.position = Vector2(244, 128)
	host.scroll.size = Vector2(1432, 840)
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
	host.tip_lab.custom_minimum_size = UiText.min_size(380.0, 0.0)
	host.tip_lab.add_theme_font_size_override("font_size", UiText.font_px(18))
	host.tip_lab.add_theme_color_override("font_color", Color(0.93, 0.86, 0.72))
	host.tip_lab.add_theme_color_override("font_outline_color", Color(0.05, 0.03, 0.02))
	host.tip_lab.add_theme_constant_override("outline_size", 6)
	host.tip_host.add_child(host.tip_lab)
	host.add_child(host.tip_host)
