extends Object

## Journal two-sheet spread on any host (pause menu today; the recap and a Quest tab can reuse it): the leather +
## paper page node over a panel rect, the sheet rects in screen space, and content columns for a scroll width.
## Drawing stays in pause_menu/journal_page.gd.

const Journal: GDScript = preload("res://scripts/ui/pause_menu/journal_page.gd")

## Add the page node to host over the panel rect, two sheets split by share (Journal.*_LEFT).
static func add(host: Node, panel_pos: Vector2, panel_size: Vector2, share: float = 0.5, node_name: String = "journal_page") -> Control:
	var page: Control = Journal.new()
	page.name = node_name
	host.add_child(page)
	Journal.place(page, panel_pos, panel_size)
	page.call("set_layout", Journal.KIND_TWO, share)
	return page

## Screen-space sheet rects of a spread placed at panel_pos/panel_size.
static func sheets(panel_pos: Vector2, panel_size: Vector2, share: float, kind: int = 1) -> Array[Rect2]:
	var out: Array[Rect2] = []
	for r: Rect2 in Journal.sheets_in(panel_size, kind, share):
		out.append(Rect2(r.position + panel_pos, r.size))
	return out

## Left/right content columns (x offsets inside the host's scroll) for a share; span falls back when the scroll
## is not laid out yet.
static func cols(host: Node, share: float, fallback_span: float = 1752.0) -> Array[Rect2]:
	var span: float = fallback_span
	var scroll: Variant = host.get("scroll")
	if scroll is Control and (scroll as Control).size.x > 10.0:
		span = (scroll as Control).size.x
	return Journal.pair(span, share)
