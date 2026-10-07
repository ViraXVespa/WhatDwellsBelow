extends Object

## Scroll pane + content box + tooltip shared by the pause menu and the recap panel.
## Fills host.scroll, host.box, host.tip_host, host.tip_lab (the host declares the vars).

const ThemeS := preload("res://scripts/ui/theme.gd")
const UiText := preload("res://scripts/ui/ui_text.gd")
const UiBuild: GDScript = preload("res://scripts/ui/ui_build.gd")

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
	host.tip_host = UiBuild.tip_panel(20)
	host.tip_lab = Label.new()
	host.tip_lab.custom_minimum_size = UiText.min_size(380.0, 0.0)
	UiBuild.tip_text(host.tip_lab, UiText.font_px(18))
	host.tip_host.add_child(host.tip_lab)
	host.add_child(host.tip_host)
