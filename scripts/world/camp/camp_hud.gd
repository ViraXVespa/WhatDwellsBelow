extends Object

const UiText := preload("res://scripts/ui/ui_text.gd")

## Split from camp.gd: _hud.

static func _hud(host: Node3D) -> void:
	var layer := CanvasLayer.new()
	host.hud = layer
	host.add_child(layer)
	follow_menus(layer)
	var panel := ColorRect.new()
	panel.color = Color(0.1, 0.08, 0.06, 0.82)
	panel.position = Vector2(32, 28)
	panel.size = Vector2(980, 150)
	layer.add_child(panel)
	host.hint = Label.new()
	host.hint.position = Vector2(48, 40)
	host.hint.size = Vector2(950, 80)
	host.hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	host.hint.add_theme_font_size_override("font_size", UiText.font_px(20))
	host.hint.add_theme_color_override("font_color", Color(0.92, 0.86, 0.72))
	host.hint.add_theme_color_override("font_outline_color", Color(0.05, 0.04, 0.03))
	host.hint.add_theme_constant_override("outline_size", 6)
	layer.add_child(host.hint)
	host.prompt = Label.new()
	host.prompt.position = Vector2(48, 118)
	host.prompt.size = Vector2(900, 40)
	host.prompt.add_theme_font_size_override("font_size", UiText.font_px(22))
	host.prompt.add_theme_color_override("font_color", Color(0.95, 0.82, 0.4))
	host.prompt.add_theme_color_override("font_outline_color", Color(0.05, 0.04, 0.03))
	host.prompt.add_theme_constant_override("outline_size", 6)
	layer.add_child(host.prompt)


## Camp menus (receptionist, vendor, crystal...) own the screen: hide the bar while one is open, restore it after.
## process_frame fires while the tree is paused, so this follows menus that pause the hub.
static func follow_menus(layer: CanvasLayer) -> void:
	var tree := layer.get_tree()
	var cb := func():
		if not is_instance_valid(layer):
			return
		if App.ui_open and layer.visible:
			layer.visible = false
			layer.set_meta("menu_hid", true)
		elif not App.ui_open and bool(layer.get_meta("menu_hid", false)):
			layer.visible = true
			layer.set_meta("menu_hid", false)
	tree.process_frame.connect(cb)
	layer.tree_exiting.connect(func(): if tree.process_frame.is_connected(cb): tree.process_frame.disconnect(cb))
