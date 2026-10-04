extends Object

const ScrollBox := preload("res://scripts/ui/scroll_box.gd")
const Plate := preload("res://scripts/ui/plate_chrome.gd")
const Journal: GDScript = preload("res://scripts/ui/pause_menu/journal_page.gd")

static func build(host: CanvasLayer) -> void:
	host.layer = 55
	host.visible = false
	host.process_mode = Node.PROCESS_MODE_ALWAYS
	host.set_meta("journal_sheet", true)
	var dim: ColorRect = ColorRect.new()
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.color = Color(0.04, 0.02, 0.015, 0.78)
	host.add_child(dim)
	var panel: ColorRect = ColorRect.new()
	panel.name = "menu_panel"
	panel.color = Color(0, 0, 0, 0)
	panel.position = Vector2(32, 16)
	panel.size = Vector2(1856, 1048)
	host.add_child(panel)
	var page: Control = Journal.new()
	page.name = "journal_page"
	host.add_child(page)
	Journal.place(page, panel.position, panel.size)
	var edge: ColorRect = ColorRect.new()
	edge.name = "menu_edge"
	edge.visible = false
	edge.color = Plate.EDGE
	edge.position = panel.position
	edge.size = Vector2(panel.size.x, Plate.EDGE_H)
	host.add_child(edge)
	var page_w: float = (panel.size.x - Journal.PAD * 2.0 - Journal.GUTTER) * 0.5
	var content_w: float = page_w * 2.0 + Journal.GUTTER
	var left_x: float = panel.position.x + Journal.PAD
	host.tab_wrap = HBoxContainer.new()
	host.tab_wrap.alignment = BoxContainer.ALIGNMENT_BEGIN
	host.tab_wrap.position = Vector2(left_x, panel.position.y + Journal.TOP - 46.0)
	host.tab_wrap.size = Vector2(content_w, 58)
	host.tab_wrap.add_theme_constant_override("separation", 8)
	host.add_child(host.tab_wrap)
	host.tab_left = HBoxContainer.new()
	host.tab_left.mouse_filter = Control.MOUSE_FILTER_IGNORE
	host.tab_left.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	host.tab_left.custom_minimum_size = Vector2(36, 22)
	host.tab_right = HBoxContainer.new()
	host.tab_right.mouse_filter = Control.MOUSE_FILTER_IGNORE
	host.tab_right.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	host.tab_right.custom_minimum_size = Vector2(36, 22)
	host.tab_scroll = ScrollContainer.new()
	host.tab_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	host.tab_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	host.tab_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	host.tab_scroll.follow_focus = true
	host.tabs = HBoxContainer.new()
	host.tabs.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	host.tabs.add_theme_constant_override("separation", 12)
	host.tab_scroll.add_child(host.tabs)
	host.tab_wrap.add_child(host.tab_left)
	host.tab_wrap.add_child(host.tab_scroll)
	host.tab_wrap.add_child(host.tab_right)
	ScrollBox.build(host, Vector2(left_x, panel.position.y + Journal.TOP), Vector2(content_w, panel.size.y - Journal.TOP - Journal.BOTTOM), 8)
