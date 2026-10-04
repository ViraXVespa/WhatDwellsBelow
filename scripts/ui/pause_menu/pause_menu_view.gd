extends Object

const ScrollBox := preload("res://scripts/ui/scroll_box.gd")
const Plate := preload("res://scripts/ui/plate_chrome.gd")

static func build(host: CanvasLayer) -> void:
	host.layer = 55
	host.visible = false
	host.process_mode = Node.PROCESS_MODE_ALWAYS
	var dim: ColorRect = ColorRect.new()
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.color = Plate.DIM
	host.add_child(dim)
	var panel: ColorRect = ColorRect.new()
	panel.color = Plate.PLATE
	panel.position = Vector2(220, 36)
	panel.size = Vector2(1480, 980)
	host.add_child(panel)
	var edge: ColorRect = ColorRect.new()
	edge.color = Plate.EDGE
	edge.position = Vector2(220, 36)
	edge.size = Vector2(1480, Plate.EDGE_H)
	host.add_child(edge)
	host.tab_wrap = HBoxContainer.new()
	host.tab_wrap.position = Vector2(244, 56)
	host.tab_wrap.size = Vector2(1432, 52)
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
	ScrollBox.build(host, Vector2(244, 112), Vector2(1432, 868), 4)
