extends Object

## Shared builders for the UI: a chrome label, image pieces, painted button states, scroll-bar handling, tooltip parts.
## Colours and weights come from ui_tokens.gd through ThemeS; object frames call these instead of repeating them.

const ThemeS: GDScript = preload("res://scripts/ui/theme.gd")
const Tok: GDScript = preload("res://scripts/ui/ui_tokens.gd")

static var _empty: StyleBoxEmpty

## A label for a frame's chrome: named, never takes the mouse.
static func chrome_label(node_name: String, size_px: int, col: Color, wrap: bool, text: String = "") -> Label:
	var lab: Label = ThemeS.lab(text, size_px, col, HORIZONTAL_ALIGNMENT_CENTER, wrap)
	lab.name = node_name
	lab.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return lab

## A stretched, nearest-filtered picture child that ignores the mouse.
static func piece(parent: Control, node_name: String, tex: Texture2D) -> TextureRect:
	var rect: TextureRect = TextureRect.new()
	rect.name = node_name
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	rect.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	rect.stretch_mode = TextureRect.STRETCH_SCALE
	rect.texture = tex
	parent.add_child(rect)
	return rect

static func place(chrome: Control, node_name: String, pos: Vector2, span: Vector2) -> void:
	var rect: Control = chrome.get_node(node_name) as Control
	rect.position = pos
	rect.size = span

## Store a generated image in a frame's cache and return its texture.
static func keep(cache: Dictionary, key: String, img: Image) -> Texture2D:
	var tex: ImageTexture = ImageTexture.create_from_image(img)
	cache[key] = tex
	return tex

static func dot(img: Image, cx: int, cy: int, radius: int, col: Color) -> void:
	for y: int in range(cy - radius, cy + radius + 1):
		for x: int in range(cx - radius, cx + radius + 1):
			if x < 0 or y < 0 or x >= img.get_width() or y >= img.get_height():
				continue
			var dx: int = x - cx
			var dy: int = y - cy
			if dx * dx + dy * dy <= radius * radius:
				img.set_pixel(x, y, col)

static func blank_box() -> StyleBoxEmpty:
	if _empty == null:
		_empty = StyleBoxEmpty.new()
	return _empty

## A textured button state: `edge` px of the picture stay unstretched, `foot` px of ink under it, `tile` repeats the face across.
static func tex_box(tex: Texture2D, edge: int, top: int, foot: int, tile: bool, pad_x: int, pad_y: int) -> StyleBoxTexture:
	var box: StyleBoxTexture = StyleBoxTexture.new()
	box.texture = tex
	box.draw_center = true
	box.texture_margin_left = edge
	box.texture_margin_right = edge
	box.texture_margin_top = top
	box.texture_margin_bottom = maxi(foot, 1)
	box.axis_stretch_horizontal = StyleBoxTexture.AXIS_STRETCH_MODE_TILE_FIT if tile else StyleBoxTexture.AXIS_STRETCH_MODE_STRETCH
	box.axis_stretch_vertical = StyleBoxTexture.AXIS_STRETCH_MODE_STRETCH
	box.content_margin_left = pad_x
	box.content_margin_right = pad_x
	box.content_margin_top = pad_y
	box.content_margin_bottom = pad_y
	return box

## Centered text, nearest filter, fills its row: the base of every frame's button.
static func button_base(button: Button) -> void:
	button.alignment = HORIZONTAL_ALIGNMENT_CENTER
	button.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL

## Ink-coloured text in every state (faint when disabled).
static func ink_text(button: Button) -> void:
	button.add_theme_color_override("font_color", ThemeS.INK)
	button.add_theme_color_override("font_hover_color", ThemeS.INK)
	button.add_theme_color_override("font_focus_color", ThemeS.INK)
	button.add_theme_color_override("font_pressed_color", ThemeS.INK)
	button.add_theme_color_override("font_disabled_color", ThemeS.INK_FAINT)

## The five button states from five boxes.
static func states(button: Button, normal: StyleBox, hover: StyleBox, pressed: StyleBox, focus: StyleBox, disabled: StyleBox) -> void:
	button.add_theme_stylebox_override("normal", normal)
	button.add_theme_stylebox_override("hover", hover)
	button.add_theme_stylebox_override("pressed", pressed)
	button.add_theme_stylebox_override("focus", focus)
	button.add_theme_stylebox_override("disabled", disabled)

## Scroll bars off (the rows still scroll with the pad), or back to the engine default.
static func bars(scroll: ScrollContainer, shown: bool) -> void:
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO if shown else ScrollContainer.SCROLL_MODE_DISABLED
	scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO if shown else ScrollContainer.SCROLL_MODE_SHOW_NEVER

## Tooltip shell: the dark panel every tooltip uses.
static func tip_panel(z: int) -> PanelContainer:
	var panel: PanelContainer = PanelContainer.new()
	panel.visible = false
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.z_index = z
	panel.add_theme_stylebox_override("panel", ThemeS.sb(Color(0.09, 0.07, 0.05, 0.97), Color(0.85, 0.68, 0.32)))
	return panel

## Tooltip text: ink with the shared outline.
static func tip_text(lab: Label, font_px: int) -> void:
	lab.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	lab.add_theme_font_size_override("font_size", font_px)
	lab.add_theme_color_override("font_color", ThemeS.INK)
	lab.add_theme_color_override("font_outline_color", ThemeS.OUTLINE)
	lab.add_theme_constant_override("outline_size", Tok.OUTLINE_SIZE)
