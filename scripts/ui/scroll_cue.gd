extends Object

## Scroll cue: small gold chevrons at the bottom (more below) and top (more above) of a
## ScrollContainer, so clipped lists read as scrollable. Purely visual; input is untouched.

const CUE_NAME := "scroll_cue"
const COL := Color(1.0, 0.84, 0.42, 0.95)
const EDGE := Color(0.10, 0.07, 0.05, 0.9)
const W := 22.0
const H := 12.0

static func attach(sc: ScrollContainer) -> void:
	if sc == null or sc.get_node_or_null(CUE_NAME) != null:
		return
	var cue := Control.new()
	cue.name = CUE_NAME
	cue.top_level = true
	cue.mouse_filter = Control.MOUSE_FILTER_IGNORE
	cue.z_index = 5
	sc.add_child(cue, false, Node.INTERNAL_MODE_BACK)
	cue.draw.connect(func(): _paint(sc, cue))
	var bar := sc.get_v_scroll_bar()
	var poke := func(_a = null): _sync(sc, cue)
	bar.changed.connect(poke)
	bar.value_changed.connect(poke)
	sc.item_rect_changed.connect(poke)
	sc.visibility_changed.connect(poke)
	sc.sort_children.connect(poke)
	_sync.call_deferred(sc, cue)

static func _sync(sc, cue) -> void:
	if not is_instance_valid(sc) or not is_instance_valid(cue):
		return
	cue.global_position = sc.global_position
	cue.size = sc.size
	cue.queue_redraw()

static func more(sc: ScrollContainer) -> Vector2i:
	var bar := sc.get_v_scroll_bar()
	var below := bar.value + bar.page < bar.max_value - 2.0
	var above := bar.value > 2.0
	return Vector2i(int(above), int(below))

static func _paint(sc: ScrollContainer, cue: Control) -> void:
	if not is_instance_valid(sc):
		return
	if absf(cue.global_position.x - sc.global_position.x) > 0.5 or absf(cue.global_position.y - sc.global_position.y) > 0.5:
		_sync.call_deferred(sc, cue)
	var m := more(sc)
	var cx := cue.size.x * 0.5
	if m.y == 1:
		_chev(cue, Vector2(cx, cue.size.y - 4.0), 1.0)
	if m.x == 1:
		_chev(cue, Vector2(cx, 4.0), -1.0)

static func _chev(cue: Control, tip: Vector2, dir: float) -> void:
	var a := tip + Vector2(-W * 0.5, -H * dir)
	var b := tip + Vector2(W * 0.5, -H * dir)
	cue.draw_colored_polygon(PackedVector2Array([a - Vector2(3, 2 * dir), b + Vector2(3, -2 * dir), tip + Vector2(0, 3 * dir)]), EDGE)
	cue.draw_colored_polygon(PackedVector2Array([a, b, tip]), COL)
