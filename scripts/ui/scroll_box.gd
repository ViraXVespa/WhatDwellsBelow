extends Object

## Scroll pane + content box + tooltip shared by the pause menu and the recap panel.
## Fills host.scroll, host.box, host.tip_host, host.tip_lab (the host declares the vars).

const ThemeS := preload("res://scripts/ui/theme.gd")
const UiText := preload("res://scripts/ui/ui_text.gd")

static func build(host: CanvasLayer, pos: Vector2, size: Vector2, sep: int) -> void:
	host.scroll = ScrollContainer.new()
	host.scroll.position = pos
	host.scroll.size = size
	host.scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	host.scroll.focus_mode = Control.FOCUS_NONE
	host.scroll.follow_focus = true
	host.add_child(host.scroll)
	host.box = VBoxContainer.new()
	host.box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	host.box.custom_minimum_size = Vector2(1400, 0)
	host.box.add_theme_constant_override("separation", sep)
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
	host.tip_lab.add_theme_color_override("font_color", ThemeS.INK)
	host.tip_lab.add_theme_color_override("font_outline_color", Color(0.05, 0.03, 0.02))
	host.tip_lab.add_theme_constant_override("outline_size", 6)
	host.tip_host.add_child(host.tip_lab)
	host.add_child(host.tip_host)
