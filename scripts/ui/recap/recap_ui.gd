extends Object

## Recap panel chrome.

const ScrollBox := preload("res://scripts/ui/scroll_box.gd")
const JournalSpread := preload("res://scripts/ui/journal_spread.gd")
const Journal: GDScript = preload("res://scripts/ui/pause_menu/journal_page.gd")

## Same binder rect as the pause menu, so the Skills sheets land in the same place.
const PANEL_POS: Vector2 = Vector2(32, 16)
const PANEL_SIZE: Vector2 = Vector2(1856, 1048)

static func build(host: CanvasLayer) -> void:
	host.layer = 70
	host.visible = false
	host.process_mode = Node.PROCESS_MODE_ALWAYS
	host.set_meta("journal_sheet", true)
	var dim: ColorRect = ColorRect.new()
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	dim.color = Color(0.04, 0.02, 0.015, 0.78)
	host.add_child(dim)
	var panel: ColorRect = ColorRect.new()
	panel.name = "menu_panel"
	panel.color = Color(0, 0, 0, 0)
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.position = PANEL_POS
	panel.size = PANEL_SIZE
	host.add_child(panel)
	JournalSpread.add(host, PANEL_POS, PANEL_SIZE, Journal.SKILLS_LEFT)
	var sheets: Array[Rect2] = JournalSpread.sheets(PANEL_POS, PANEL_SIZE, Journal.SKILLS_LEFT)
	if sheets.size() < 2:
		push_error("recap journal sheets missing")
		return
	var left: Rect2 = sheets[0]
	host.tip_sheet = sheets[1]
	var top: float = left.position.y + Journal.TEXT_DROP
	var box_h: float = left.size.y - Journal.TEXT_DROP
	host.sheet_rect = Rect2(Vector2(left.position.x, top), Vector2(left.size.x, box_h))
	ScrollBox.build(host, host.sheet_rect.position, host.sheet_rect.size, 4)
	host.box.custom_minimum_size = Vector2(left.size.x, 0.0)

static func fit(host: CanvasLayer) -> void:
	var sheet: Rect2 = host.sheet_rect
	var header: VBoxContainer = host.header
	var footer: VBoxContainer = host.footer
	if header == null or footer == null or sheet.size.x < 8.0:
		return
	var span: Vector2 = Vector2(sheet.size.x, 0.0)
	header.position = sheet.position
	header.size = span
	footer.size = span
	var head_h: float = header.get_combined_minimum_size().y
	var foot_h: float = footer.get_combined_minimum_size().y
	header.size = Vector2(sheet.size.x, head_h)
	footer.position = Vector2(sheet.position.x, sheet.position.y + sheet.size.y - foot_h)
	footer.size = Vector2(sheet.size.x, foot_h)
	var gap: float = 6.0
	var y: float = sheet.position.y + head_h + gap
	var h: float = sheet.size.y - head_h - foot_h - gap * 2.0
	host.scroll.position = Vector2(sheet.position.x, y)
	host.scroll.size = Vector2(sheet.size.x, maxf(80.0, h))
