extends Object

const Plate := preload("res://scripts/ui/plate_chrome.gd")
const UiBuild: GDScript = preload("res://scripts/ui/ui_build.gd")
const CrystalArt: GDScript = preload("res://scripts/ui/progress_ui/crystal_art.gd")
const CrystalFrame: GDScript = preload("res://scripts/ui/progress_ui/crystal_frame.gd")

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
			return App.tr("ui_util.zoom_mid")
		2:
			return App.tr("ui_util.zoom_full_floor")
		_:
			return App.tr("ui_util.zoom_close")

static func zoom_event(event: InputEvent) -> bool:
	return event.is_action_pressed("crystal_zoom")

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

## Floor-crystal backdrop (the hub loadout frame's art, same place and scale) for the transport pages.
## Returns the pale facet rect, inset, where a page lays out its content.
static func crystal_panel(ui: CanvasLayer) -> Rect2:
	var art := TextureRect.new()
	art.name = "crystal_body"
	art.texture = CrystalArt.body()
	art.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	art.stretch_mode = TextureRect.STRETCH_SCALE
	art.mouse_filter = Control.MOUSE_FILTER_IGNORE
	art.position = CrystalFrame.FRAME_POS
	art.size = CrystalFrame.FRAME_SIZE
	ui.add_child(art)
	var pale: Rect2i = CrystalArt.PALE
	var s: float = CrystalFrame.SCALE
	return Rect2(CrystalFrame.FRAME_POS + Vector2(pale.position) * s + Vector2(24, 18), Vector2(pale.size) * s - Vector2(48, 36))

## Scrolling column inside rect (pad focus scrolls it; no bar).
static func column(ui: CanvasLayer, rect: Rect2, sep: int) -> VBoxContainer:
	var sc := ScrollContainer.new()
	sc.position = rect.position
	sc.size = rect.size
	sc.follow_focus = true
	sc.focus_mode = Control.FOCUS_NONE
	sc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	sc.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_SHOW_NEVER
	ui.add_child(sc)
	var box := VBoxContainer.new()
	box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	box.add_theme_constant_override("separation", sep)
	sc.add_child(box)
	return box
