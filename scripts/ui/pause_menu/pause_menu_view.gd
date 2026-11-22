extends Object

const ScrollBox := preload("res://scripts/ui/scroll_box.gd")
const Plate := preload("res://scripts/ui/plate_chrome.gd")
const Journal: GDScript = preload("res://scripts/ui/pause_menu/journal_page.gd")
const JournalSpread := preload("res://scripts/ui/journal_spread.gd")
const Touch := preload("res://scripts/input/touch_pad.gd")

## The journal at the 1920x1080 base (32, 16, 1856, 1048). A wider (phone) or taller (4:3) canvas centres it in the
## safe area; a short or notched one shrinks it to fit (the settings list then packs its rows: split_menu_view).
const PANEL_MAX := Vector2(1856, 1048)
const PANEL_MARGIN := Vector2(64, 32)

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
	panel.size = PANEL_MAX
	host.add_child(panel)
	JournalSpread.add(host, panel.position, panel.size)
	var edge: ColorRect = ColorRect.new()
	edge.name = "menu_edge"
	edge.visible = false
	edge.color = Plate.EDGE
	host.add_child(edge)
	var page_w: float = (panel.size.x - Journal.PAD * 2.0 - Journal.GUTTER) * 0.5
	var content_w: float = page_w * 2.0 + Journal.GUTTER
	var left_x: float = panel.position.x + Journal.PAD
	host.tab_wrap = HBoxContainer.new()
	host.tab_wrap.alignment = BoxContainer.ALIGNMENT_BEGIN
	host.tab_wrap.position = Vector2(left_x, panel.position.y + Journal.TOP - 46.0)
	host.tab_wrap.size = Vector2(content_w, 58)
	host.tab_wrap.grow_vertical = Control.GROW_DIRECTION_BEGIN
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
	ScrollBox.build(host, Vector2(left_x, panel.position.y + Journal.TOP + Journal.TEXT_DROP), Vector2(content_w, panel.size.y - Journal.TOP - Journal.BOTTOM - Journal.TEXT_DROP), 8)
	layout(host)
	host.get_viewport().size_changed.connect(func() -> void:
		if layout(host) and bool(host.get("open")):
			host._rebuild())

## Journal rect for a canvas `vp` (logical px) with safe-area insets `ins` (left, top, right, bottom).
static func rect_for(vp: Vector2, ins: Vector4) -> Rect2:
	var safe := Rect2(ins.x, ins.y, vp.x - ins.x - ins.z, vp.y - ins.y - ins.w)
	var sz := Vector2(minf(PANEL_MAX.x, safe.size.x - PANEL_MARGIN.x), minf(PANEL_MAX.y, safe.size.y - PANEL_MARGIN.y))
	return Rect2((safe.position + (safe.size - sz) * 0.5).floor(), sz)

## Place the journal, tabs and scroll for the current canvas. True when anything moved.
static func layout(host: CanvasLayer) -> bool:
	var vp: Vector2 = host.get_viewport().get_visible_rect().size
	var r: Rect2 = rect_for(vp, Touch.safe_insets(vp))
	var panel: ColorRect = host.get_node("menu_panel") as ColorRect
	if host.has_meta("journal_rect") and host.get_meta("journal_rect") == r:
		return false
	host.set_meta("journal_rect", r)
	panel.position = r.position
	panel.size = r.size
	Journal.place(host.get_node("journal_page") as Control, r.position, r.size)
	var edge: ColorRect = host.get_node("menu_edge") as ColorRect
	edge.position = r.position
	edge.size = Vector2(r.size.x, Plate.EDGE_H)
	var page_w: float = (r.size.x - Journal.PAD * 2.0 - Journal.GUTTER) * 0.5
	var content_w: float = page_w * 2.0 + Journal.GUTTER
	var left_x: float = r.position.x + Journal.PAD
	host.tab_wrap.position = Vector2(left_x, r.position.y + Journal.TOP - 46.0)
	host.tab_wrap.size = Vector2(content_w, 58)
	host.scroll.position = Vector2(left_x, r.position.y + Journal.TOP + Journal.TEXT_DROP)
	host.scroll.size = Vector2(content_w, r.size.y - Journal.TOP - Journal.BOTTOM - Journal.TEXT_DROP)
	return true
