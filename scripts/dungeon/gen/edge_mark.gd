extends Object

## Straight span -> solid edge keys. Shared by outline_seal (which solid/void edges still need a wall) and the debug
## map_rim check (which edges the prepared wall mesh covers). Fixed expectations: debug/dungeon_map/edge_fixture.gd.
## Keys: Vector3i(0, y_edge, x) is the horizontal edge on line y_edge over cell column x;
## Vector3i(1, x_edge, y) is the vertical edge on line x_edge over cell row y.

## [origin, delta, span] for every Dictionary span (other entries skipped).
static func parts(spans: Array) -> Array[Array]:
	var out: Array[Array] = []
	for raw_span: Variant in spans:
		if raw_span is Dictionary:
			var sp: Dictionary = raw_span
			out.append([Vector2(sp.get("origin", Vector2.ZERO)), Vector2(sp.get("delta", Vector2.ZERO)), sp])
	return out

## Marks a span that runs along one grid line (within 0.35 of it, at most 0.2 off axis, at least 0.5 long).
## False, marking nothing, for any other span.
static func mark_axis(marked: Dictionary, o: Vector2, d: Vector2) -> bool:
	if absf(d.y) <= 0.2 and absf(d.x) >= 0.5 and absf(o.y - float(roundi(o.y))) <= 0.35:
		mark_horiz(marked, roundi(o.y), o.x, o.x + d.x)
		return true
	if absf(d.x) <= 0.2 and absf(d.y) >= 0.5 and absf(o.x - float(roundi(o.x))) <= 0.35:
		mark_vert(marked, roundi(o.x), o.y, o.y + d.y)
		return true
	return false

## Cells whose extent overlaps x0..x1 by more than 0.001 (touching at an end does not count).
static func mark_horiz(marked: Dictionary, y_edge: int, x0: float, x1: float) -> void:
	var lo: float = minf(x0, x1)
	var hi: float = maxf(x0, x1)
	var x: int = int(floor(lo))
	var last: int = int(ceil(hi))
	while x < last:
		if float(x + 1) > lo + 0.001 and float(x) < hi - 0.001:
			marked[Vector3i(0, y_edge, x)] = true
		x += 1

static func mark_vert(marked: Dictionary, x_edge: int, y0: float, y1: float) -> void:
	var lo: float = minf(y0, y1)
	var hi: float = maxf(y0, y1)
	var y: int = int(floor(lo))
	var last: int = int(ceil(hi))
	while y < last:
		if float(y + 1) > lo + 0.001 and float(y) < hi - 0.001:
			marked[Vector3i(1, x_edge, y)] = true
		y += 1
