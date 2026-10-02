extends Object

## Torch plan grid tests: thin cells, ring exits, room touch.

const Gen := preload("res://scripts/dungeon/gen/gen.gd")

const DIRS: Array[Vector2i] = [Vector2i(0, -1), Vector2i(0, 1), Vector2i(-1, 0), Vector2i(1, 0)]
const RING: Array[Vector2i] = [
	Vector2i(0, -1), Vector2i(1, -1), Vector2i(1, 0), Vector2i(1, 1),
	Vector2i(0, 1), Vector2i(-1, 1), Vector2i(-1, 0), Vector2i(-1, -1),
]

static func _thin_arr(
	mask: PackedByteArray, mouths: PackedByteArray, w: int, h: int, live_src: PackedInt32Array
) -> void:
	var live: PackedInt32Array = PackedInt32Array()
	var s0: int = 0
	while s0 < live_src.size():
		var i0: int = live_src[s0]
		s0 += 1
		if mask[i0] != 0 and mouths[i0] == 0:
			live.append(i0)
	var step: int = 0
	while step < 6:
		step += 1
		var peel: PackedInt32Array = PackedInt32Array()
		var keep: PackedInt32Array = PackedInt32Array()
		var k: int = 0
		while k < live.size():
			var i: int = live[k]
			k += 1
			if mask[i] == 0:
				continue
			var y: int = int(float(i) / float(w))
			var x: int = i - y * w
			if _peelable_arr(mask, mouths, w, h, x, y):
				peel.append(i)
			else:
				keep.append(i)
		var j: int = 0
		while j < peel.size():
			mask[peel[j]] = 0
			j += 1
		if peel.is_empty():
			break
		live = keep

static func _peelable_arr(mask: PackedByteArray, mouths: PackedByteArray, w: int, h: int, x: int, y: int) -> bool:
	var i: int = y * w + x
	if mouths[i] != 0:
		return false
	var orth: int = 0
	var pos_side: bool = false
	for d: Vector2i in DIRS:
		var nx: int = x + d.x
		var ny: int = y + d.y
		var ni: int = ny * w + nx
		if mask[ni] != 0:
			orth += 1
		elif (d.x > 0 or d.y > 0) and mask[i - d.y * w - d.x] != 0:
			pos_side = true
	if orth < 2 or not pos_side:
		return false
	return _ring_exits_arr(mask, w, h, Vector2i(x, y)) == 1

static func _ring_exits_arr(mask: PackedByteArray, w: int, h: int, cell: Vector2i) -> int:
	var any: bool = false
	var on0: bool = false
	var prev: bool = false
	var exits: int = 0
	var i: int = 0
	while i < 8:
		var n: Vector2i = cell + RING[i]
		var hit: bool = n.x >= 0 and n.y >= 0 and n.x < w and n.y < h and mask[n.y * w + n.x] != 0
		if i == 0:
			on0 = hit
		else:
			if hit and not prev:
				exits += 1
		if hit:
			any = true
		prev = hit
		i += 1
	if on0 and not prev:
		exits += 1
	if not any:
		return 0
	return exits

static func _touches_room_arr(
	grid: PackedByteArray,
	inside: PackedInt32Array,
	map_w: int,
	map_h: int,
	x: int,
	y: int
) -> bool:
	for d: Vector2i in DIRS:
		var nx: int = x + d.x
		var ny: int = y + d.y
		if nx < 0 or ny < 0 or nx >= map_w or ny >= map_h:
			continue
		var ni: int = ny * map_w + nx
		if inside[ni] < 0:
			continue
		if grid[ni] == Gen.FLOOR:
			return true
	return false
