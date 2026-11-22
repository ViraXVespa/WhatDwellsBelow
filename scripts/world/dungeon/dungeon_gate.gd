extends Object

## Extraction Gates hang on a top (north, camera-facing) wall only: the room's own
## top wall first, then the nearest top-wall slot around the room. Never a side wall,
## never a free-standing floor spot (design/dungeon-gates.md).

const SpotS := preload("res://scripts/world/interact.gd")
const GateSlot := preload("res://scripts/dungeon/gen/gate_slot.gd")

## Fallback search half-size (cells) around the room centre.
const NEAR_RAD := 12

static func _clear(host: Node, c: Vector2i) -> bool:
	for dx: int in range(-1, 2):
		if not host._cell_clear(Vector2i(c.x + dx, c.y + 1), 1):
			return false
	return true

## Middle wall cell of the gate's top-wall slot, or (-1, -1) when none is free.
static func pick(host: Node, r: Dictionary) -> Vector2i:
	var grid: PackedByteArray = host.data.grid
	var w: int = int(host.data.w)
	var h: int = int(host.data.h)
	var c: Vector2i = GateSlot.room_slot(grid, w, h, r)
	if c.x >= 0 and _clear(host, c):
		return c
	for s: Vector2i in GateSlot.near_slots(grid, w, h, host._center_room(r), NEAR_RAD):
		if _clear(host, s):
			return s
	return Vector2i(-1, -1)

## Places one gate for room r; false (and no gate) when no top-wall slot is free.
static func place(host: Node, r: Dictionary) -> bool:
	var mid: Vector2i = pick(host, r)
	if mid.x < 0:
		push_warning("extract_gate: no top-wall slot near room %s,%s" % [str(r.get("x")), str(r.get("y"))])
		return false
	var pos: Vector3 = host._cell_pos(mid)
	pos.z += 0.55
	var g := SpotS.new()
	g.setup_extract_gate(pos)
	host.add_child(g)
	for dx in range(-1, 2):
		host._mark_cell(Vector2i(mid.x + dx, mid.y))
	host._note("extract_gate")
	return true
