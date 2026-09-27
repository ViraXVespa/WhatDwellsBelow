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
const _EPS := 4.5
const _LOCK := 64.0
const _DOMIN := 0.62


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
	data["outline_spans"] = _spans(solid, sw, sh, grid, w, h, n)


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
		for _jag_step_y in seg_y:
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

static func _spans(solid: PackedByteArray, sw: int, sh: int, grid: PackedByteArray, gw: int, gh: int, n: int) -> Array:
	var pack: Dictionary = _collect_edges(solid, sw, sh, grid, gw, gh, n)
	var ex: PackedInt32Array = pack["ex"]
	var spans: Array = []
	if ex.is_empty():
		return spans
	var vw: int = int(pack["vw"])
	var head: PackedInt32Array = pack["head"]
	var ey: PackedInt32Array = pack["ey"]
	var ed: PackedInt32Array = pack["ed"]
	var link: PackedInt32Array = pack["link"]
	var used: PackedByteArray = PackedByteArray()
	used.resize(ex.size())
	used.fill(0)
	var ecount: int = ex.size()
	for s in ecount:
		if used[s] != 0:
			continue
		var xs: PackedInt32Array = PackedInt32Array()
		var ys: PackedInt32Array = PackedInt32Array()
		xs.append(ex[s])
		ys.append(ey[s])
		var e: int = s
		var guard: int = ecount + 2
		while guard > 0:
			guard -= 1
			if used[e] != 0:
				break
			used[e] = 1
			var d: int = ed[e]
			var bx: int = ex[e] + _step_x(d)
			var by: int = ey[e] + _step_y(d)
			xs.append(bx)
			ys.append(by)
			if bx == xs[0] and by == ys[0]:
				break
			e = _pick_edge(head, vw, ed, link, used, bx, by, d)
			if e < 0:
				break
		var closed: bool = xs.size() >= 2 and xs[0] == xs[xs.size() - 1] and ys[0] == ys[ys.size() - 1]
		var local: Array = _fold_spans(_fit_xy(xs, ys), closed)
		for item in local:
			spans.append(item)
	_face_spans(spans, solid, sw, sh)
	return spans


static func _step_x(d: int) -> int:
	if d == 0:
		return 1
	if d == 2:
		return -1
	return 0


static func _face_spans(spans: Array, solid: PackedByteArray, sw: int, sh: int) -> void:
	for item in spans:
		if not (item is Dictionary):
			continue
		var run: Dictionary = item
		if not run.has("delta"):
			continue
		var o: Vector2 = run["origin"] as Vector2
		var d: Vector2 = run["delta"] as Vector2
		var nrm: Vector2 = run["normal"] as Vector2
		if nrm.length_squared() < 0.0001:
			nrm = Vector2(-d.y, d.x)
		if nrm.length_squared() < 0.0001:
			continue
		nrm = nrm.normalized()
		var mx: int = int(floor((o.x + d.x * 0.5) + nrm.x * 0.6))
		var my: int = int(floor((o.y + d.y * 0.5) + nrm.y * 0.6))
		var hit: bool = mx >= 0 and my >= 0 and mx < sw and my < sh and solid[my * sw + mx] != 0
		if not hit:
			nrm = -nrm
		run["normal"] = nrm


static func _step_y(d: int) -> int:
	if d == 1:
		return 1
	if d == 3:
		return -1
	return 0


static func _skip_block(grid: PackedByteArray, gw: int, gh: int, x: int, y: int) -> bool:
	var here: int = grid[y * gw + x]
	var dirs: Array[Vector2i] = [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]
	for d in dirs:
		var nx: int = x + d.x
		var ny: int = y + d.y
		var v: int = 0
		if nx >= 0 and ny >= 0 and nx < gw and ny < gh:
			v = grid[ny * gw + nx]
		if v != here:
			return false
	return true


static func _collect_edges(solid: PackedByteArray, sw: int, sh: int, grid: PackedByteArray, gw: int, gh: int, n: int) -> Dictionary:
	var step: int = n
	if step < 1:
		step = 1
	var vw: int = sw + 1
	var vh: int = sh + 1
	var head: PackedInt32Array = PackedInt32Array()
	head.resize(vw * vh)
	head.fill(-1)
	var ex: PackedInt32Array = PackedInt32Array()
	var ey: PackedInt32Array = PackedInt32Array()
	var ed: PackedInt32Array = PackedInt32Array()
	var link: PackedInt32Array = PackedInt32Array()
	for cy in gh:
		for cx in gw:
			if _skip_block(grid, gw, gh, cx, cy):
				continue
			var x0: int = cx * step
			var y0: int = cy * step
			var x1: int = x0 + step
			var y1: int = y0 + step
			if x1 > sw:
				x1 = sw
			if y1 > sh:
				y1 = sh
			for y in range(y0, y1):
				var row: int = y * sw
				for x in range(x0, x1):
					if solid[row + x] == 0:
						continue
					if x + 1 >= sw or solid[row + x + 1] == 0:
						var e0: int = ex.size()
						ex.append(x + 1)
						ey.append(y)
						ed.append(1)
						link.append(head[(y * vw) + (x + 1)])
						head[(y * vw) + (x + 1)] = e0
					if x <= 0 or solid[row + x - 1] == 0:
						var e1: int = ex.size()
						ex.append(x)
						ey.append(y + 1)
						ed.append(3)
						link.append(head[((y + 1) * vw) + x])
						head[((y + 1) * vw) + x] = e1
					if y + 1 >= sh or solid[(y + 1) * sw + x] == 0:
						var e2: int = ex.size()
						ex.append(x + 1)
						ey.append(y + 1)
						ed.append(2)
						link.append(head[((y + 1) * vw) + (x + 1)])
						head[((y + 1) * vw) + (x + 1)] = e2
					if y <= 0 or solid[(y - 1) * sw + x] == 0:
						var e3: int = ex.size()
						ex.append(x)
						ey.append(y)
						ed.append(0)
						link.append(head[(y * vw) + x])
						head[(y * vw) + x] = e3
	return {"vw": vw, "head": head, "ex": ex, "ey": ey, "ed": ed, "link": link}


static func _pick_edge(head: PackedInt32Array, vw: int, ed: PackedInt32Array, link: PackedInt32Array, used: PackedByteArray, bx: int, by: int, in_d: int) -> int:
	var key: int = by * vw + bx
	if key < 0 or key >= head.size():
		return -1
	var e: int = head[key]
	var best: int = -1
	var best_sc: int = 99
	var guard: int = 8
	while e >= 0 and guard > 0:
		guard -= 1
		if used[e] == 0:
			var sc: int = (ed[e] - in_d) & 3
			if sc < best_sc:
				best_sc = sc
				best = e
		e = link[e]
	return best


static func _fit_xy(xs: PackedInt32Array, ys: PackedInt32Array) -> Array:
	var rd: PackedInt32Array = PackedInt32Array()
	var rl: PackedInt32Array = PackedInt32Array()
	var rx: PackedInt32Array = PackedInt32Array()
	var ry: PackedInt32Array = PackedInt32Array()
	var npts: int = xs.size()
	if npts < 2:
		return []
	var closed: bool = xs[0] == xs[npts - 1] and ys[0] == ys[npts - 1]
	var i: int = 0
	var last: int = npts - 1
	while i < last:
		var dx: int = _sgn(xs[i + 1] - xs[i])
		var dy: int = _sgn(ys[i + 1] - ys[i])
		var dir: int = _dir4(dx, dy)
		var j: int = i + 1
		while j < last:
			var dx2: int = _sgn(xs[j + 1] - xs[j])
			var dy2: int = _sgn(ys[j + 1] - ys[j])
			if _dir4(dx2, dy2) != dir:
				break
			j += 1
		rd.append(dir)
		rl.append(j - i)
		rx.append(xs[i])
		ry.append(ys[i])
		i = j
	if rd.is_empty():
		return []
	if closed and rd.size() >= 2 and rd[0] == rd[rd.size() - 1]:
		rl[0] = rl[0] + rl[rl.size() - 1]
		rx[0] = rx[rx.size() - 1]
		ry[0] = ry[ry.size() - 1]
		rd.resize(rd.size() - 1)
		rl.resize(rl.size() - 1)
		rx.resize(rx.size() - 1)
		ry.resize(ry.size() - 1)
	return _fit_runs(rd, rl, rx, ry)


static func _sgn(v: int) -> int:
	if v > 0:
		return 1
	if v < 0:
		return -1
	return 0


static func _dir4(dx: int, dy: int) -> int:
	if dx > 0:
		return 0
	if dy > 0:
		return 1
	if dx < 0:
		return 2
	return 3


static func _fit_runs(rd: PackedInt32Array, rl: PackedInt32Array, rx: PackedInt32Array, ry: PackedInt32Array) -> Array:
	var spans: Array = []
	var count: int = rd.size()
	var i: int = 0
	while i < count:
		var counts: PackedInt32Array = PackedInt32Array([0, 0, 0, 0])
		counts[rd[i]] = counts[rd[i]] + 1
		var longest: int = rl[i]
		var sx: float = float(rx[i])
		var sy: float = float(ry[i])
		var locked: bool = false
		var lx: float = 1.0
		var ly: float = 0.0
		var j: int = i
		while j + 1 < count:
			var nd: int = rd[j + 1]
			if not _quadrant_ok(counts, nd):
				break
			var ex: float = float(_end_x(rx, rd, rl, j + 1))
			var ey: float = float(_end_y(ry, rd, rl, j + 1))
			if not locked:
				if not _prefix_flat(rx, ry, rd, rl, i, j + 1):
					break
			elif _line_dist(float(rx[j + 1]), float(ry[j + 1]), sx, sy, lx, ly) > _EPS or _line_dist(ex, ey, sx, sy, lx, ly) > _EPS:
				break
			j += 1
			counts[nd] = counts[nd] + 1
			if rl[j] > longest:
				longest = rl[j]
			var chord: float = Vector2(ex - sx, ey - sy).length()
			if not locked and chord >= _LOCK and _both_axes(counts):
				if _prefix_flat(rx, ry, rd, rl, i, j):
					locked = true
					if chord < 0.001:
						chord = 1.0
					lx = (ex - sx) / chord
					ly = (ey - sy) / chord
				else:
					counts[nd] = counts[nd] - 1
					j -= 1
					break
		var ex2: float = float(_end_x(rx, rd, rl, j))
		var ey2: float = float(_end_y(ry, rd, rl, j))
		var chord2: float = Vector2(ex2 - sx, ey2 - sy).length()
		var stair: bool = j > i and _dirs_twice(counts) and float(longest) <= maxf(6.0, _DOMIN * chord2)
		if stair:
			_push_rec(spans, sx, sy, ex2, ey2)
			i = j + 1
		else:
			_push_rec(spans, sx, sy, float(_end_x(rx, rd, rl, i)), float(_end_y(ry, rd, rl, i)))
			i += 1
	return spans


static func _end_x(rx: PackedInt32Array, rd: PackedInt32Array, rl: PackedInt32Array, j: int) -> int:
	return rx[j] + _step_x(rd[j]) * rl[j]


static func _end_y(ry: PackedInt32Array, rd: PackedInt32Array, rl: PackedInt32Array, j: int) -> int:
	return ry[j] + _step_y(rd[j]) * rl[j]


static func _quadrant_ok(counts: PackedInt32Array, nd: int) -> bool:
	if nd == 0 and counts[2] > 0:
		return false
	if nd == 2 and counts[0] > 0:
		return false
	if nd == 1 and counts[3] > 0:
		return false
	if nd == 3 and counts[1] > 0:
		return false
	return true


static func _dirs_twice(counts: PackedInt32Array) -> bool:
	var used_n: int = 0
	for c in counts:
		if c > 0:
			used_n += 1
			if c < 2:
				return false
	return used_n >= 2


static func _both_axes(counts: PackedInt32Array) -> bool:
	var horiz: bool = counts[0] > 0 or counts[2] > 0
	var vert: bool = counts[1] > 0 or counts[3] > 0
	return horiz and vert


static func _prefix_flat(rx: PackedInt32Array, ry: PackedInt32Array, rd: PackedInt32Array, rl: PackedInt32Array, i: int, j: int) -> bool:
	var sx: float = float(rx[i])
	var sy: float = float(ry[i])
	var ex: float = float(_end_x(rx, rd, rl, j))
	var ey: float = float(_end_y(ry, rd, rl, j))
	var k: int = i + 1
	while k <= j:
		if _chord_dist(float(rx[k]), float(ry[k]), sx, sy, ex, ey) > _EPS:
			return false
		k += 1
	return true


static func _chord_dist(px: float, py: float, sx: float, sy: float, ex: float, ey: float) -> float:
	var vx: float = ex - sx
	var vy: float = ey - sy
	var span_l: float = sqrt(vx * vx + vy * vy)
	if span_l < 0.001:
		return 0.0
	return absf(vx * (py - sy) - vy * (px - sx)) / span_l


static func _line_dist(px: float, py: float, sx: float, sy: float, lx: float, ly: float) -> float:
	return absf(lx * (py - sy) - ly * (px - sx))


static func _push_rec(spans: Array, sx: float, sy: float, ex: float, ey: float) -> void:
	var delta := Vector2(ex - sx, ey - sy)
	if delta.length_squared() < 0.25:
		return
	var nrm: Vector2 = Vector2(-delta.y, delta.x)
	if nrm.length_squared() > 0.0001:
		nrm = nrm.normalized()
	spans.append({
		"origin": Vector2(sx, sy),
		"delta": delta,
		"normal": nrm,
		"thick": 1.0,
	})


static func _fold_spans(spans: Array, closed: bool) -> Array:
	if spans.size() < 2:
		return spans
	var merged: Array = [spans[0]]
	for idx in range(1, spans.size()):
		var prev: Dictionary = merged[merged.size() - 1]
		var nxt: Dictionary = spans[idx]
		if _can_fold(prev, nxt):
			merged[merged.size() - 1] = _combine_span(prev, nxt)
		else:
			merged.append(nxt)
	if closed and merged.size() >= 2 and _can_fold(merged[merged.size() - 1], merged[0]):
		var combined: Dictionary = _combine_span(merged[merged.size() - 1], merged[0])
		var rest: Array = [combined]
		for k in range(1, merged.size() - 1):
			rest.append(merged[k])
		return rest
	return merged


static func _can_fold(a: Dictionary, b: Dictionary) -> bool:
	var ao: Vector2 = a["origin"]
	var ad: Vector2 = a["delta"]
	var bo: Vector2 = b["origin"]
	var bd: Vector2 = b["delta"]
	var end: Vector2 = ao + ad
	if end.distance_squared_to(bo) > 0.01:
		return false
	var al: float = ad.length()
	var bl: float = bd.length()
	if al < 0.1 or bl < 0.1:
		return false
	return ad.dot(bd) / (al * bl) > 0.985


static func _combine_span(a: Dictionary, b: Dictionary) -> Dictionary:
	var ao: Vector2 = a["origin"]
	var bo: Vector2 = b["origin"]
	var bd: Vector2 = b["delta"]
	var end: Vector2 = bo + bd
	var delta: Vector2 = end - ao
	var nrm: Vector2 = Vector2(-delta.y, delta.x)
	if nrm.length_squared() > 0.0001:
		nrm = nrm.normalized()
	return {
		"origin": ao,
		"delta": delta,
		"normal": nrm,
		"thick": 1.0,
	}


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
