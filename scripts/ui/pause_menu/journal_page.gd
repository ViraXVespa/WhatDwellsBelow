extends Control

## Open field journal behind the pause menu. Real copy stays in the controls.

const PAPER_PATH: String = "res://assets/ui/journal/paper.png"
const LEATHER_PATH: String = "res://assets/ui/journal/leather.png"

static var _tex: Dictionary = {}

static func _tex_at(rel: String) -> Texture2D:
	if _tex.has(rel) and _tex[rel] is Texture2D:
		return _tex[rel]
	var img: Image = Image.new()
	var err: Error = img.load(rel)
	var made: ImageTexture = ImageTexture.create_from_image(img) if err == OK else ImageTexture.new()
	_tex[rel] = made
	return made

const PAD: float = 52.0
const TOP: float = 86.0
const GUTTER: float = 34.0
const BOTTOM: float = 52.0

static func place(node: Control, panel_pos: Vector2, panel_size: Vector2) -> void:
	node.mouse_filter = Control.MOUSE_FILTER_IGNORE
	node.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	node.position = panel_pos
	node.size = panel_size
	node.queue_redraw()

func _draw() -> void:
	if size.x < 32.0 or size.y < 32.0:
		return
	draw_texture_rect(_tex_at(LEATHER_PATH), Rect2(Vector2.ZERO, size), true)
	var page_w: float = (size.x - PAD * 2.0 - GUTTER) * 0.5
	var page_h: float = size.y - TOP - BOTTOM
	if page_w < 8.0 or page_h < 8.0:
		return
	var left: Rect2 = Rect2(PAD, TOP, page_w, page_h)
	var right: Rect2 = Rect2(PAD + page_w + GUTTER, TOP, page_w, page_h)
	draw_rect(Rect2(left.position.x + 6.0, left.position.y + left.size.y - 2.0, page_w - 22.0, 14.0), Color(0.04, 0.02, 0.01, 0.35))
	draw_rect(Rect2(right.position.x + 16.0, right.position.y + right.size.y - 2.0, page_w - 22.0, 14.0), Color(0.04, 0.02, 0.01, 0.32))
	var page_tex: Texture2D = _tex_at(PAPER_PATH)
	draw_texture_rect(page_tex, left, true)
	draw_texture_rect(page_tex, right, true)
	_crease(left, right)
	draw_line(left.position, left.position + Vector2(0.0, page_h), Color(0.55, 0.40, 0.26, 0.45), 1.0)
	draw_line(right.position + Vector2(page_w, 0.0), right.position + Vector2(page_w, page_h), Color(0.55, 0.40, 0.26, 0.45), 1.0)
	_sheet_edges(left, right)

func _sheet_edges(left: Rect2, right: Rect2) -> void:
	var tones: Array[Color] = [
		Color(0.78, 0.68, 0.52, 1.0),
		Color(0.62, 0.50, 0.36, 1.0),
		Color(0.48, 0.36, 0.24, 1.0),
	]
	for i: int in tones.size():
		var tone: Color = tones[i]
		var step: float = float(i) * 4.0
		draw_rect(Rect2(left.position.x - 4.0 - step, left.position.y + 8.0 + step, 4.0, left.size.y - 10.0), tone)
		draw_rect(Rect2(right.position.x + right.size.x + step, right.position.y + 8.0 + step, 4.0, right.size.y - 10.0), tone)
		draw_rect(Rect2(left.position.x + 10.0, left.position.y + left.size.y + step, left.size.x - 26.0, 4.0), tone)
		draw_rect(Rect2(right.position.x + 16.0, right.position.y + right.size.y + step, right.size.x - 26.0, 4.0), tone)

func _crease(left: Rect2, right: Rect2) -> void:
	var y: float = left.position.y
	var h: float = left.size.y
	var x: float = left.position.x + left.size.x
	draw_rect(Rect2(x - 12.0, y, 12.0, h), Color(0.28, 0.18, 0.10, 0.16))
	draw_rect(Rect2(right.position.x, y, 12.0, h), Color(0.28, 0.18, 0.10, 0.16))
	draw_rect(Rect2(x, y, GUTTER, h), Color(0.36, 0.22, 0.13, 0.72))
	draw_rect(Rect2(x + GUTTER * 0.5 - 2.0, y, 4.0, h), Color(0.14, 0.08, 0.05, 0.45))
	draw_line(Vector2(x + 1.0, y), Vector2(x + 1.0, y + h), Color(0.96, 0.91, 0.82, 0.45), 1.0)
	draw_line(Vector2(right.position.x - 1.0, y), Vector2(right.position.x - 1.0, y + h), Color(0.96, 0.91, 0.82, 0.35), 1.0)
