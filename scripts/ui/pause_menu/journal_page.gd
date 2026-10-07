extends Control

## Open field journal behind the pause menu. Real copy stays in the controls.

const PAPER_PATH: String = "res://assets/ui/journal/paper.png"
const LEATHER_PATH: String = "res://assets/ui/journal/leather.png"
const PAD: float = 52.0
const TOP: float = 86.0
const GUTTER: float = 34.0
const BOTTOM: float = 52.0
## Bookmarks hang on the top of the paper. Text starts below that overlap.
const TEXT_DROP: float = 18.0
const KIND_ONE: int = 0
const KIND_TWO: int = 1
## Share of the usable width given to the left sheet. The gap sits after it.
const SETTINGS_LEFT: float = 0.34
const SKILLS_LEFT: float = 0.68
const EVEN_LEFT: float = 0.5

static var _tex: Dictionary = {}
var kind: int = KIND_TWO
var left_share: float = EVEN_LEFT

static func _tex_at(rel: String) -> Texture2D:
	if _tex.has(rel) and _tex[rel] is Texture2D:
		return _tex[rel]
	var loaded: Resource = load(rel)
	if not loaded is Texture2D:
		push_error("journal page texture missing: %s" % rel)
		assert(loaded is Texture2D, "journal page texture missing: %s" % rel)
		return loaded as Texture2D
	_tex[rel] = loaded
	return loaded as Texture2D

static func pair(span: float, share: float) -> Array[Rect2]:
	var out: Array[Rect2] = []
	var usable: float = maxf(8.0, span - GUTTER)
	var clamped: float = clampf(share, 0.22, 0.78)
	var left_w: float = usable * clamped
	out.append(Rect2(0.0, 0.0, left_w, 0.0))
	out.append(Rect2(left_w + GUTTER, 0.0, usable - left_w, 0.0))
	return out

static func place(node: Control, panel_pos: Vector2, panel_size: Vector2) -> void:
	node.mouse_filter = Control.MOUSE_FILTER_IGNORE
	node.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	node.position = panel_pos
	node.size = panel_size
	node.queue_redraw()

func set_layout(next_kind: int, share: float) -> void:
	if kind == next_kind and is_equal_approx(left_share, share):
		return
	kind = next_kind
	left_share = share
	queue_redraw()

func _draw() -> void:
	if size.x < 32.0 or size.y < 32.0:
		return
	draw_texture_rect(_tex_at(LEATHER_PATH), Rect2(Vector2.ZERO, size), true)
	var sheets: Array[Rect2] = _sheets()
	if sheets.is_empty():
		return
	var page_tex: Texture2D = _tex_at(PAPER_PATH)
	var last: int = sheets.size() - 1
	for i: int in sheets.size():
		var sheet: Rect2 = sheets[i]
		_drop(sheet)
		draw_texture_rect(page_tex, sheet, true)
		_rule(sheet)
		_sheet_edges(sheet, i == 0, i == last)

func _sheets() -> Array[Rect2]:
	var page_h: float = size.y - TOP - BOTTOM
	var out: Array[Rect2] = []
	if page_h < 8.0:
		return out
	if kind == KIND_TWO:
		var cols: Array[Rect2] = pair(size.x - PAD * 2.0, left_share)
		if cols[0].size.x < 8.0 or cols[1].size.x < 8.0:
			return out
		out.append(Rect2(PAD + cols[0].position.x, TOP, cols[0].size.x, page_h))
		out.append(Rect2(PAD + cols[1].position.x, TOP, cols[1].size.x, page_h))
		return out
	var one_w: float = size.x - PAD * 2.0
	if one_w < 8.0:
		return out
	out.append(Rect2(PAD, TOP, one_w, page_h))
	return out

func _drop(sheet: Rect2) -> void:
	draw_rect(Rect2(sheet.position.x + 10.0, sheet.position.y + sheet.size.y - 2.0, sheet.size.x - 20.0, 14.0), Color(0.04, 0.02, 0.01, 0.32))

func _rule(sheet: Rect2) -> void:
	var tone: Color = Color(0.55, 0.40, 0.26, 0.55)
	var origin: Vector2 = sheet.position
	var far: Vector2 = sheet.position + sheet.size
	draw_line(origin, Vector2(far.x, origin.y), tone, 1.0)
	draw_line(origin, Vector2(origin.x, far.y), tone, 1.0)
	draw_line(Vector2(far.x, origin.y), far, tone, 1.0)
	draw_line(Vector2(origin.x, far.y), far, tone, 1.0)

func _sheet_edges(sheet: Rect2, stack_left: bool, stack_right: bool) -> void:
	var tones: Array[Color] = [
		Color(0.78, 0.68, 0.52, 1.0),
		Color(0.62, 0.50, 0.36, 1.0),
		Color(0.48, 0.36, 0.24, 1.0),
	]
	for i: int in tones.size():
		var tone: Color = tones[i]
		var step: float = float(i) * 4.0
		if stack_left:
			draw_rect(Rect2(sheet.position.x - 4.0 - step, sheet.position.y + 8.0 + step, 4.0, sheet.size.y - 10.0), tone)
		if stack_right:
			draw_rect(Rect2(sheet.position.x + sheet.size.x + step, sheet.position.y + 8.0 + step, 4.0, sheet.size.y - 10.0), tone)
		draw_rect(Rect2(sheet.position.x + 12.0, sheet.position.y + sheet.size.y + step, sheet.size.x - 24.0, 4.0), tone)
