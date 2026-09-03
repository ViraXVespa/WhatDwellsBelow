extends Object

const SpotS := preload("res://scripts/world/interact.gd")
const Gen := preload("res://scripts/dungeon/gen.gd")


static func _wall(host: Node, c: Vector2i) -> bool:
	var w: int = host.data.w
	var h: int = host.data.h
	if c.x < 0 or c.y < 0 or c.x >= w or c.y >= h:
		return false
	return host.data.grid[Gen.idx(c.x, c.y, w)] == Gen.WALL


static func north_mid(host: Node, r: Dictionary) -> Vector2i:
	var rx := int(r.x)
	var ry := int(r.y)
	var rw := int(r.w)
	if ry < 1 or rw < 3:
		return Vector2i(-1, -1)
	var wy := ry - 1
	var best := -1
	var best_d := 1 << 30
	var cx := rx + rw / 2
	for x in range(rx, rx + rw - 2):
		var ok := true
		for dx in 3:
			if not _wall(host, Vector2i(x + dx, wy)):
				ok = false
				break
			if not host._cell_clear(Vector2i(x + dx, ry), 1):
				ok = false
				break
		if not ok:
			continue
		var mid := x + 1
		var d := absi(mid - cx)
		if d < best_d:
			best_d = d
			best = mid
	if best < 0:
		return Vector2i(-1, -1)
	return Vector2i(best, wy)


static func place(host: Node, r: Dictionary) -> void:
	var mid: Vector2i = north_mid(host, r)
	if mid.x < 0:
		mid = host._free_cell(r)
		if mid.x < 0:
			return
	var pos: Vector3 = host._cell_pos(mid)
	pos.z += 0.55
	var g := SpotS.new()
	g.setup_extract_gate(pos)
	host.add_child(g)
	for dx in range(-1, 2):
		host._mark_cell(Vector2i(mid.x + dx, mid.y))
	host._note("extract_gate")
