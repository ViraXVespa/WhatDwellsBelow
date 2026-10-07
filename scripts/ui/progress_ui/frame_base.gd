extends Object

## Object-frame base for the progress panel host (progress_ui.gd). A frame is a skin script with static hooks:
##   spec()          Dictionary: mode, chrome (node name), pos, size, footer, rows_pos, rows_size, sep, blank_rows
##   build(chrome)   make the pieces and labels once, when the host mounts
##   place(chrome)   position them each time the frame opens
## The base owns what every frame shares: the chrome layer under the host, the cream plate that every other
## mode keeps, the footer room under a frame, and the button row (the host's scroll area).

const Plate: GDScript = preload("res://scripts/ui/plate_chrome.gd")
const UiBuild: GDScript = preload("res://scripts/ui/ui_build.gd")
const PromptView: GDScript = preload("res://scripts/ui/prompt_view.gd")

const PLATE_POS: Vector2 = Vector2(360, 80)
const PLATE_SIZE: Vector2 = Vector2(1200, 920)
const SCROLL_POS: Vector2 = Vector2(384, 104)
const SCROLL_SIZE: Vector2 = Vector2(1152, 832)

static func mount(host: CanvasLayer, skin: GDScript) -> void:
	var spec: Dictionary = skin.spec()
	var chrome: Control = Control.new()
	chrome.name = str(spec["chrome"])
	chrome.visible = false
	chrome.mouse_filter = Control.MOUSE_FILTER_IGNORE
	host.add_child(chrome)
	host.move_child(chrome, 1)
	skin.build(chrome)

## Cream plate for every mode, then the one skin whose mode is active takes the plate over.
static func apply(host: CanvasLayer, skins: Array) -> void:
	var plate: ColorRect = host.get_node_or_null("plate") as ColorRect
	var edge: ColorRect = host.get_node_or_null("plate_edge") as ColorRect
	var scroll: ScrollContainer = host.get_node_or_null("plate_scroll") as ScrollContainer
	if plate == null or edge == null or scroll == null:
		return
	for skin: GDScript in skins:
		if host.get_node_or_null(str(skin.spec()["chrome"])) == null:
			return
	plate.color = Plate.PLATE
	plate.position = PLATE_POS
	plate.size = PLATE_SIZE
	edge.visible = true
	edge.position = PLATE_POS
	edge.size = Vector2(PLATE_SIZE.x, float(Plate.EDGE_H))
	scroll.position = SCROLL_POS
	scroll.size = SCROLL_SIZE
	scroll.remove_theme_stylebox_override("panel")
	UiBuild.bars(scroll, true)
	host.box.add_theme_constant_override("separation", 8)
	var mode: String = str(host.get("mode"))
	for skin: GDScript in skins:
		var spec: Dictionary = skin.spec()
		var chrome: Control = host.get_node(str(spec["chrome"])) as Control
		var active: bool = mode == str(spec["mode"])
		chrome.visible = active
		if active:
			_fit(host, chrome, spec, plate, edge, scroll)
			skin.place(chrome)

static func _fit(host: CanvasLayer, chrome: Control, spec: Dictionary, plate: ColorRect, edge: ColorRect, scroll: ScrollContainer) -> void:
	var pos: Vector2 = spec["pos"]
	var span: Vector2 = spec["size"]
	chrome.position = pos
	chrome.size = span
	edge.visible = false
	plate.color = UiBuild.Tok.CLEAR
	var inset: Vector2 = spec.get("plate_inset", Vector2.ZERO)
	plate.position = pos + Vector2(inset.x, 0.0)
	plate.size = Vector2(span.x - inset.x * 2.0, span.y - inset.y + float(spec["footer"]))
	PromptView.place_bar(host)
	scroll.position = spec["rows_pos"]
	scroll.size = spec["rows_size"]
	UiBuild.bars(scroll, false)
	if bool(spec["blank_rows"]):
		scroll.add_theme_stylebox_override("panel", UiBuild.blank_box())
	host.box.add_theme_constant_override("separation", int(spec["sep"]))
