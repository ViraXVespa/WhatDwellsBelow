# Page building and utility functions for CrystalUI

const ThemeS := preload("res://scripts/ui/theme.gd")
const CrystalNet := preload("res://scripts/world/crystal_net.gd")

const ZOOM_NEAR := 96


static func zoom_view(ui: CanvasLayer, host: Node) -> int:
	if host == null:
		return ZOOM_NEAR
	var full: int = maxi(int(host.data.w), int(host.data.h))
	var near: int = mini(ZOOM_NEAR, full)
	if ui.zoom_lv == 2:
		return full
	if ui.zoom_lv == 1:
		return maxi(near, int(round((near + full) * 0.5)))
	return near


static func zoom_tip(ui: CanvasLayer) -> String:
	match ui.zoom_lv:
		1:
			return "Zoom: mid  ·  Y / Tab cycles"
		2:
			return "Zoom: full floor  ·  Y / Tab cycles"
		_:
			return "Zoom: close  ·  Y / Tab cycles"


static func zoom_event(event: InputEvent) -> bool:
	if event is InputEventKey and event.pressed and not event.echo:
		return event.keycode == KEY_TAB or event.physical_keycode == KEY_TAB
	if event is InputEventJoypadButton and event.pressed:
		return event.button_index == JOY_BUTTON_Y
	return false


static func place_mark(ui: CanvasLayer, cell: Vector2i, rx: int, ry: int, rw: int, rh: int) -> void:
	if ui.map_mark == null or ui.map_clip == null:
		return
	if rw <= 0 or rh <= 0:
		ui.map_mark.visible = false
		return
	var box: Vector2 = ui.map_clip.size
	var fit: float = minf(box.x / float(rw), box.y / float(rh))
	var drawn := Vector2(float(rw) * fit, float(rh) * fit)
	var origin := (box - drawn) * 0.5
	var lx: float = (float(cell.x - rx) + 0.5) / float(rw)
	var ly: float = (float(cell.y - ry) + 0.5) / float(rh)
	var px: float = origin.x + lx * drawn.x
	var py: float = origin.y + ly * drawn.y
	var mark: float = clampf(fit * 2.4, 8.0, 18.0)
	ui.map_mark.size = Vector2(mark, mark)
	ui.map_mark.position = Vector2(px - mark * 0.5, py - mark * 0.5)
	ui.map_mark.visible = true
	ui.map_mark.color = Color(1.0, 0.92, 0.35, 0.95)


static func panel(ui: CanvasLayer, pos: Vector2, size: Vector2) -> ColorRect:
	var panel := ColorRect.new()
	panel.color = Color(0.14, 0.11, 0.09, 0.96)
	panel.position = pos
	panel.size = size
	ui.add_child(panel)
	var edge := ColorRect.new()
	edge.color = Color(0.55, 0.42, 0.22, 1)
	edge.position = pos
	edge.size = Vector2(size.x, 8)
	ui.add_child(edge)
	return panel
