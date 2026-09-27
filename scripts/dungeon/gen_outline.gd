extends Object

## Post-carve floor/void outline. The 1 m grid stays the logical map.
## Fine occupancy is the walk solid. Room corners are cut to a quarter-round.
## Hall cells are never cleared. Hall corners only gain an outward round.
## Long abyss edges pick up irregular 0.25–0.5 m steps.

const FLOOR := 1
const LONG_EDGE := 4
const K_HALL := 1
const K_INTERIOR := 2
const K_RIM := 3


static func stamp(data: Dictionary, rng: RandomNumberGenerator, bal: Object) -> void:
	var fine_m: float = _fine_m(bal)
	var n: int = _per_m(fine_m)
	var grid: PackedByteArray = data["grid"]
	var w: int = int(data["w"])
	var h: int = int(data["h"])
	var rooms: Array = data["rooms"]
	var kind: PackedByteArray = _kinds(grid, w, h, rooms)
	var sw: int = w * n
	var sh: int = h * n
	var solid := PackedByteArray()
	solid.resize(sw * sh)
	solid.fill(0)
	_upsample(grid, w, h, n, solid, sw)
	if n >= 2:
		_jag(rng, grid, w, h, n, kind, solid, sw, sh, _frac(bal, "outline_jag_frac", 0.35))
		_fillet(rng, grid, w, h, n, kind, solid, sw, sh, _frac(bal, "outline_fillet_frac", 0.40))
		_strip_nubs(solid, sw, sh)
	data["outline_fine_m"] = fine_m
	data["solid"] = solid
	data["solid_w"] = sw
	data["solid_h"] = sh
	data["solid_n"] = n


static func _fine_m(bal: Object) -> float:
	var m := 0.25
	if bal != null:
		m = float(bal.get("outline_fine_m"))
	if m >= 0.87:
		return 1.0
	if m >= 0.37:
		return 0.5
	return 0.25


static func _per_m(fine_m: float) -> int:
	return clampi(int(round(1.0 / fine_m)), 1, 4)


static func _frac(bal: Object, key: String, fallback: float) -> float:
	var v: float = fallback
	if bal != null:
		v = float(bal.get(key))
	return clampf(v, 0.0, 1.0)


static func _kinds(grid: PackedByteArray, w: int, h: int, rooms: Array) -> PackedByteArray:
	var kind := PackedByteArray()
	kind.resize(w * h)
	kind.fill(0)
	for y in h:
		var row: int = y * w
		for x in w:
			if grid[row + x] == FLOOR:
				kind[row + x] = K_HALL
	for room_v: Variant in rooms:
		var room: Dictionary = room_v
		var rx: int = int(room["x"])
		var ry: int = int(room["y"])
		var rw: int = int(room["w"])
		var rh: int = int(room["h"])
		var x1: int = rx + rw
		var y1: int = ry + rh
		for yy in range(ry, y1):
			if yy <= 0 or yy >= h - 1:
				continue
			for xx in range(rx, x1):
				if xx <= 0 or xx >= w - 1:
					continue
				if grid[yy * w + xx] != FLOOR:
					continue
				var inset: bool = xx > rx and yy > ry and xx < x1 - 1 and yy < y1 - 1
				kind[yy * w + xx] = K_INTERIOR if inset else K_RIM
	return kind


static func _upsample(grid: PackedByteArray, w: int, h: int, n: int, solid: PackedByteArray, sw: int) -> void:
	for y in h:
		var row: int = y * w
		for x in w:
			if grid[row + x] != FLOOR:
				continue
			var fx0: int = x * n
			var fy0: int = y * n
			for ly in n:
				var dst: int = (fy0 + ly) * sw + fx0
				for lx in n:
					solid[dst + lx] = 1


static func _floor_at(grid: PackedByteArray, w: int, h: int, x: int, y: int) -> bool:
	if x < 0 or y < 0 or x >= w or y >= h:
		return false
	return grid[y * w + x] == FLOOR


static func _fillet(rng: RandomNumberGenerator, grid: PackedByteArray, w: int, h: int, n: int, kind: PackedByteArray, solid: PackedByteArray, sw: int, sh: int, frac: float) -> void:
	if frac <= 0.0:
		return
	var corners: Array[Vector4i] = []
	for y in range(1, h - 1):
		var row: int = y * w
		for x in range(1, w - 1):
			var k: int = kind[row + x]
			if k != K_RIM and k != K_HALL:
				continue
			var q: int = _convex_q(grid, w, h, x, y)
			if q < 0:
				continue
			corners.append(Vector4i(x, y, q, k))
	if corners.is_empty():
		return
	var want: int = int(round(frac * float(corners.size())))
	if want < 1:
		want = 1
	if want > corners.size():
		want = corners.size()
	for i in want:
		var j: int = i + (rng.randi() % (corners.size() - i))
		var swap: Vector4i = corners[i]
		corners[i] = corners[j]
		corners[j] = swap
		var picked: Vector4i = corners[i]
		if picked.w == K_HALL:
			_bulge_quarter(solid, sw, sh, n, picked)
		else:
			_cut_quarter(solid, sw, n, picked)


static func _convex_q(grid: PackedByteArray, w: int, h: int, x: int, y: int) -> int:
	var west: bool = not _floor_at(grid, w, h, x - 1, y)
	var east: bool = not _floor_at(grid, w, h, x + 1, y)
	var north: bool = not _floor_at(grid, w, h, x, y - 1)
	var south: bool = not _floor_at(grid, w, h, x, y + 1)
	if west and north and not east and not south and not _floor_at(grid, w, h, x - 1, y - 1):
		return 0
	if east and north and not west and not south and not _floor_at(grid, w, h, x + 1, y - 1):
		return 1
	if west and south and not east and not north and not _floor_at(grid, w, h, x - 1, y + 1):
		return 2
	if east and south and not west and not north and not _floor_at(grid, w, h, x + 1, y + 1):
		return 3
	return -1


static func _cut_quarter(solid: PackedByteArray, sw: int, n: int, corner: Vector4i) -> void:
	var box: int = n - 1
	if box < 1:
		return
	var rad: float = 0.5 if n < 3 else float(n - 2)
	var rad2: float = rad * rad
	var inward: float = float(n - 1)
	var x0: int = corner.x * n
	var y0: int = corner.y * n
	var x_hi: bool = corner.z == 1 or corner.z == 3
	var y_hi: bool = corner.z == 2 or corner.z == 3
	for ly in box:
		for lx in box:
			var dx: float = float(lx) + 0.5 - inward
			var dy: float = float(ly) + 0.5 - inward
			if dx * dx + dy * dy <= rad2:
				continue
			var fx: int = x0 + (n - 1 - lx) if x_hi else x0 + lx
			var fy: int = y0 + (n - 1 - ly) if y_hi else y0 + ly
			solid[fy * sw + fx] = 0


static func _bulge_quarter(solid: PackedByteArray, sw: int, sh: int, n: int, corner: Vector4i) -> void:
	var box: int = n - 1
	if box < 1:
		return
	var rad: float = float(box)
	var rad2: float = rad * rad
	var x_sign: int = -1 if corner.z == 0 or corner.z == 2 else 1
	var y_sign: int = -1 if corner.z == 0 or corner.z == 1 else 1
	var px: int = corner.x * n if x_sign < 0 else (corner.x + 1) * n
	var py: int = corner.y * n if y_sign < 0 else (corner.y + 1) * n
	var cell_x0: int = corner.x * n
	var cell_y0: int = corner.y * n
	var cell_x1: int = cell_x0 + n
	var cell_y1: int = cell_y0 + n
	for fy in range(py - box, py + box):
		for fx in range(px - box, px + box):
			if fx >= cell_x0 and fx < cell_x1 and fy >= cell_y0 and fy < cell_y1:
				continue
			if fx < 0 or fy < 0 or fx >= sw or fy >= sh:
				continue
			var dx: float = float(fx) + 0.5 - float(px)
			var dy: float = float(fy) + 0.5 - float(py)
			if dx * dx + dy * dy > rad2:
				continue
			if solid[fy * sw + fx] != 0:
				continue
			if _void_gap(solid, sw, sh, fx, fy, x_sign, 0) < 2:
				continue
			if _void_gap(solid, sw, sh, fx, fy, 0, y_sign) < 2:
				continue
			solid[fy * sw + fx] = 1


static func _jag(rng: RandomNumberGenerator, grid: PackedByteArray, w: int, h: int, n: int, kind: PackedByteArray, solid: PackedByteArray, sw: int, sh: int, frac: float) -> void:
	if frac <= 0.0:
		return
	var runs: Array[Dictionary] = []
	_collect_h(runs, grid, w, h, 1)
	_collect_v(runs, grid, w, h, 1)
	if runs.is_empty():
		return
	var want: int = int(round(frac * float(runs.size())))
	if want < 1:
		want = 1
	if want > runs.size():
		want = runs.size()
	for i in want:
		var j: int = i + (rng.randi() % (runs.size() - i))
		var swap: Dictionary = runs[i]
		runs[i] = runs[j]
		runs[j] = swap
		_jag_run(rng, n, w, kind, solid, sw, sh, runs[i])


static func _collect_h(runs: Array[Dictionary], grid: PackedByteArray, w: int, h: int, dir: int) -> void:
	var y0: int = 1 if dir < 0 else 0
	var y1: int = h if dir < 0 else h - 1
	for y in range(y0, y1):
		var x := 0
		while x < w:
			if not _h_edge(grid, w, h, x, y, dir):
				x += 1
				continue
			var x0: int = x
			while x < w and _h_edge(grid, w, h, x, y, dir):
				x += 1
			if x - x0 >= LONG_EDGE:
				runs.append({"x0": x0, "x1": x - 1, "y": y, "dir": dir, "axis": 0})


static func _collect_v(runs: Array[Dictionary], grid: PackedByteArray, w: int, h: int, dir: int) -> void:
	var x0: int = 1 if dir < 0 else 0
	var x1: int = w if dir < 0 else w - 1
	for x in range(x0, x1):
		var y := 0
		while y < h:
			if not _v_edge(grid, w, h, x, y, dir):
				y += 1
				continue
			var y_start: int = y
			while y < h and _v_edge(grid, w, h, x, y, dir):
				y += 1
			if y - y_start >= LONG_EDGE:
				runs.append({"x": x, "y0": y_start, "y1": y - 1, "dir": dir, "axis": 1})


static func _h_edge(grid: PackedByteArray, w: int, h: int, x: int, y: int, dir: int) -> bool:
	return _floor_at(grid, w, h, x, y) and not _floor_at(grid, w, h, x, y + dir)


static func _v_edge(grid: PackedByteArray, w: int, h: int, x: int, y: int, dir: int) -> bool:
	return _floor_at(grid, w, h, x, y) and not _floor_at(grid, w, h, x + dir, y)


static func _jag_run(rng: RandomNumberGenerator, n: int, gw: int, kind: PackedByteArray, solid: PackedByteArray, sw: int, sh: int, run: Dictionary) -> void:
	var segs: Array[int] = [4, 6, 8, 12]
	var axis: int = int(run["axis"])
	var dir: int = int(run["dir"])
	if axis == 0:
		var fx: int = (int(run["x0"]) + 1) * n
		var fx_end: int = int(run["x1"]) * n
		var y: int = int(run["y"])
		while fx < fx_end:
			if fx_end - fx < n:
				break
			var seg: int = segs[rng.randi() % segs.size()]
			var depth: int = _depth(rng)
			var notch: bool = depth == 0 and rng.randf() < 0.4
			for _step in seg:
				if fx >= fx_end:
					break
				_jag_x(n, gw, kind, solid, sw, sh, fx, y, dir, depth, notch)
				fx += 1
			fx += 4 + rng.randi() % 5
		return
	var fy: int = (int(run["y0"]) + 1) * n
	var fy_end: int = int(run["y1"]) * n
	var x: int = int(run["x"])
	while fy < fy_end:
		if fy_end - fy < n:
			break
		var seg_y: int = segs[rng.randi() % segs.size()]
		var depth_y: int = _depth(rng)
		var notch_y: bool = depth_y == 0 and rng.randf() < 0.4
		for _step_y in seg_y:
			if fy >= fy_end:
				break
			_jag_y(n, gw, kind, solid, sw, sh, x, fy, dir, depth_y, notch_y)
			fy += 1
		fy += 4 + rng.randi() % 5


static func _depth(rng: RandomNumberGenerator) -> int:
	if rng.randf() > 0.72:
		return 0
	if rng.randf() < 0.5:
		return 1
	return 2


static func _jag_x(n: int, _gw: int, _kind: PackedByteArray, solid: PackedByteArray, sw: int, sh: int, fx: int, y: int, dir: int, depth: int, _notch: bool) -> void:
	var outward: int = -1 if dir < 0 else 1
	var edge: int = y * n if dir < 0 else (y + 1) * n - 1
	var d := 1
	while d <= depth:
		var fy: int = edge + outward * d
		if fy < 0 or fy >= sh or fx < 0 or fx >= sw:
			break
		if solid[fy * sw + fx] != 0:
			break
		if _void_gap(solid, sw, sh, fx, fy, 0, outward) < 2:
			break
		solid[fy * sw + fx] = 1
		d += 1


static func _jag_y(n: int, _gw: int, _kind: PackedByteArray, solid: PackedByteArray, sw: int, sh: int, x: int, fy: int, dir: int, depth: int, _notch: bool) -> void:
	var outward: int = -1 if dir < 0 else 1
	var edge: int = x * n if dir < 0 else (x + 1) * n - 1
	var d := 1
	while d <= depth:
		var fx: int = edge + outward * d
		if fx < 0 or fx >= sw or fy < 0 or fy >= sh:
			break
		if solid[fy * sw + fx] != 0:
			break
		if _void_gap(solid, sw, sh, fx, fy, outward, 0) < 2:
			break
		solid[fy * sw + fx] = 1
		d += 1


static func _notch_at(n: int, gw: int, kind: PackedByteArray, solid: PackedByteArray, sw: int, fx: int, fy: int) -> void:
	if fx < 0 or fy < 0:
		return
	var cx: int = int(float(fx) / float(n))
	var cy: int = int(float(fy) / float(n))
	var ki: int = cy * gw + cx
	if cx < 0 or cy < 0 or cx >= gw or ki < 0 or ki >= kind.size():
		return
	if kind[ki] != K_RIM:
		return
	solid[fy * sw + fx] = 0


static func _strip_nubs(solid: PackedByteArray, sw: int, sh: int) -> void:
	var dirs: Array[Vector2i] = [
		Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)
	]
	var pass_i: int = 0
	while pass_i < 3:
		var kill: Array[int] = []
		for y in sh:
			var row: int = y * sw
			for x in sw:
				if solid[row + x] == 0:
					continue
				var nbor: int = 0
				for d in dirs:
					var nx: int = x + d.x
					var ny: int = y + d.y
					if nx < 0 or ny < 0 or nx >= sw or ny >= sh:
						continue
					if solid[ny * sw + nx] != 0:
						nbor += 1
				if nbor <= 1:
					kill.append(row + x)
		for idx in kill:
			solid[idx] = 0
		pass_i += 1

static func _void_gap(solid: PackedByteArray, sw: int, sh: int, fx: int, fy: int, dx: int, dy: int) -> int:
	var gap := 0
	var x: int = fx + dx
	var y: int = fy + dy
	while x >= 0 and y >= 0 and x < sw and y < sh and gap < 3:
		if solid[y * sw + x] != 0:
			return gap
		gap += 1
		x += dx
		y += dy
	return 99
