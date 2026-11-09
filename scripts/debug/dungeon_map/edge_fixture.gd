extends SceneTree

## Fixed-expectation fixtures for the shared edge marker (dungeon/gen/edge_mark.gd), the outline seal pass
## (dungeon/gen/outline_seal.gd) and the debug rim check (debug/dungeon_map/map_rim.gd). Every expected key and
## fragment below is written by hand, not computed by the code under test.
## Run: python tools/perf.py map --fixtures  (godot --headless --script this file; exit 1 on any FAIL).

const Edge := preload("res://scripts/dungeon/gen/edge_mark.gd")
const Seal := preload("res://scripts/dungeon/gen/outline_seal.gd")
const Rim := preload("res://scripts/debug/dungeon_map/map_rim.gd")
const WallMesh: GDScript = preload("res://scripts/graphics/wall_mesh.gd")

var fails: int = 0
var passes: int = 0

func _initialize() -> void:
	_marks()
	_seal()
	_rim()
	print("EDGE_FIX: RESULT %s pass=%d fail=%d" % ["PASS" if fails == 0 else "FAIL", passes, fails])
	quit(1 if fails > 0 else 0)

func _ok(name: String, good: bool, got: Variant, want: Variant) -> void:
	if good:
		passes += 1
		print("EDGE_FIX: PASS %s" % name)
	else:
		fails += 1
		print("EDGE_FIX: FAIL %s got=%s want=%s" % [name, str(got), str(want)])

func _keys(o: Vector2, d: Vector2) -> Array:
	var m: Dictionary = {}
	var axis: bool = Edge.mark_axis(m, o, d)
	var ks: Array = m.keys()
	ks.sort()
	return [axis, ks]

func _mark(name: String, o: Vector2, d: Vector2, axis: bool, want: Array) -> void:
	var got: Array = _keys(o, d)
	var w: Array = want.duplicate()
	w.sort()
	_ok(name, got[0] == axis and got[1] == w, got, [axis, w])

## name, origin, delta, counts as an axis span, expected edge keys (hand-written).
func _marks() -> void:
	var row2: Array = [Vector3i(0, 2, 0), Vector3i(0, 2, 1), Vector3i(0, 2, 2)]
	var row2_mid: Array = [Vector3i(0, 2, 2), Vector3i(0, 2, 3)]
	var col4: Array = [Vector3i(1, 4, 1), Vector3i(1, 4, 2)]
	var cases: Array = [
		["horiz_whole", Vector2(0, 2), Vector2(3, 0), true, row2],
		["horiz_reversed", Vector2(3, 2), Vector2(-3, 0), true, row2],
		["horiz_fractional_ends", Vector2(0.5, 2), Vector2(2.0, 0), true, row2],
		["horiz_endpoint_contact_only", Vector2(1.9995, 2), Vector2(2.001, 0), true, row2_mid],
		["horiz_reversed_endpoint_contact", Vector2(4.0005, 2), Vector2(-2.001, 0), true, row2_mid],
		["horiz_near_line_kept", Vector2(0, 2.3), Vector2(3, 0), true, row2],
		["horiz_off_grid_rejected", Vector2(0, 2.4), Vector2(3, 0), false, []],
		["horiz_off_axis_rejected", Vector2(0, 2), Vector2(3, 0.3), false, []],
		["horiz_short_rejected", Vector2(0, 2), Vector2(0.4, 0), false, []],
		["vert_whole", Vector2(4, 1), Vector2(0, 2), true, col4],
		["vert_reversed", Vector2(4, 3), Vector2(0, -2), true, col4],
		["vert_fractional_ends", Vector2(4, 1.25), Vector2(0, 1.5), true, col4],
		["vert_endpoint_contact_only", Vector2(4, 0.9995), Vector2(0, 2.001), true, col4],
		["vert_off_grid_rejected", Vector2(4.4, 1), Vector2(0, 2), false, []],
	]
	for c: Array in cases:
		_mark(c[0], c[1], c[2], c[3], c[4])

## 4x3 fine grid, solid cells (1,1) and (2,1) only.
func _grid() -> PackedByteArray:
	var g: PackedByteArray = PackedByteArray()
	g.resize(12)
	g[5] = 1
	g[6] = 1
	return g

func _span(o: Vector2, d: Vector2) -> Dictionary:
	return {"origin": o, "delta": d, "normal": Vector2.ZERO, "thick": 0.25}

func _frags(spans: Array, skip: int) -> Array:
	var out: Array = []
	for i: int in range(skip, spans.size()):
		var sp: Dictionary = spans[i]
		out.append([sp["origin"], sp["delta"], sp["normal"], sp["thick"]])
	return out

func _seal_case(name: String, given: Array, want: Array) -> Array:
	var spans: Array = given.duplicate()
	Seal._seal_gaps(_grid(), 4, 3, spans)
	var got: Array = _frags(spans, given.size())
	_ok(name, got == want, got, want)
	return spans

func _seal() -> void:
	var s: Array = [Vector2(3, 2), Vector2(-2, 0), Vector2(0, -1), 0.25]
	var w: Array = [Vector2(1, 2), Vector2(0, -1), Vector2(1, 0), 0.25]
	var e: Array = [Vector2(3, 1), Vector2(0, 1), Vector2(-1, 0), 0.25]
	_seal_case("seal_bare_grid", [], [[Vector2(1, 1), Vector2(2, 0), Vector2(0, 1), 0.25], s, w, e])
	_seal_case("seal_partial_north", [_span(Vector2(1, 1), Vector2(1, 0))], [[Vector2(2, 1), Vector2(1, 0), Vector2(0, 1), 0.25], s, w, e])
	var loop: Array = [_span(Vector2(3, 1), Vector2(-2, 0)), _span(Vector2(1, 2), Vector2(2, 0)), _span(Vector2(1, 1), Vector2(0, 1)), _span(Vector2(3, 2), Vector2(0, -1))]
	_seal_case("seal_closed_reversed_loop", loop, [])

func _rim() -> void:
	var data: Dictionary = {"solid": _grid(), "solid_w": 4, "solid_h": 3, "solid_n": 1, "outline_spans": []}
	var bare: Dictionary = Rim.rim_report(data)
	_ok("rim_no_spans_six_holes", int(bare["holes"]) == 6, bare, "holes=6")
	var spans: Array = []
	Seal._seal_gaps(_grid(), 4, 3, spans)
	data["outline_spans"] = spans
	var full: Dictionary = Rim.rim_report(data)
	_ok("rim_sealed_prepared_closed", int(full["holes"]) == 0, full, "holes=0")
	var kept: Array = []
	for sp: Dictionary in WallMesh.prepare(spans):
		var o: Vector2 = sp["origin"]
		var d: Vector2 = sp["delta"]
		if not (absf(d.y) < 0.01 and absf(o.y - 1.0) < 0.01):
			kept.append(sp)
	var dropped: Dictionary = Rim.rim_holes(data, kept)
	_ok("rim_prepare_drops_north_fails", int(dropped["holes"]) == 2 and dropped["cells"] == [Vector2i(1, 1), Vector2i(2, 1)] and str(dropped["sample"]) == "1,1n:na,2,1n:na", dropped, "holes=2 cells=[(1,1),(2,1)] sample=1,1n:na,2,1n:na")
