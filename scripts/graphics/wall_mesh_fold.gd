extends Object

## Fold stair teeth and duplicate opposite spans before the chunk is skinned.

static func _pt_key(p: Vector2) -> Vector2i:
	return Vector2i(roundi(p.x * 5.0), roundi(p.y * 5.0))
static func _unit2(v: Vector2) -> Vector2:
	if v.length_squared() < 0.0001:
		return Vector2.ZERO
	return v.normalized()
static func _axis_run(d: Vector2) -> bool:
	return absf(d.x) <= 0.2 or absf(d.y) <= 0.2
static func _link_ok(a: Vector2, b: Vector2) -> bool:
	var al: float = a.length()
	var bl: float = b.length()
	if al < 0.001 or bl < 0.001:
		return false
	var cross: float = absf(a.x * b.y - a.y * b.x) / (al * bl)
	if cross <= 0.2:
		return true
	if al <= 6.0 and bl <= 6.0 and _axis_run(a) and _axis_run(b):
		return true
	return false
static func _lat(rel: Vector2, chord: Vector2) -> float:
	var cl: float = chord.length()
	if cl < 0.001:
		return rel.length()
	return absf(rel.x * chord.y - rel.y * chord.x) / cl
static func _can_fold(runs: Array[Dictionary], chain: Array[int], a: int, b: int) -> bool:
	if b <= a:
		return false
	var origin: Vector2 = runs[chain[a]]["origin"]
	var last: Dictionary = runs[chain[b]]
	var endp: Vector2 = (last["origin"] as Vector2) + (last["delta"] as Vector2)
	var chord: Vector2 = endp - origin
	var cl: float = chord.length()
	if cl < 0.5:
		return false
	var dev: float = 0.0
	for k in range(a, b + 1):
		var run: Dictionary = runs[chain[k]]
		var o: Vector2 = run["origin"]
		var far: Vector2 = o + (run["delta"] as Vector2)
		dev = maxf(dev, _lat(o - origin, chord))
		dev = maxf(dev, _lat(far - origin, chord))
	if dev > 1.25:
		return false
	var dir: Vector2 = chord / cl
	var teeth: bool = true
	var colinear: bool = true
	for k2 in range(a, b + 1):
		var step: Vector2 = runs[chain[k2]]["delta"]
		var sl: float = step.length()
		if sl > 6.0 or not _axis_run(step):
			teeth = false
		if sl > 0.001 and absf(step.x * dir.y - step.y * dir.x) / sl > 0.2:
			colinear = false
	if colinear:
		return true
	if not teeth:
		return false
	return absf(chord.x) > 0.75 and absf(chord.y) > 0.75
static func _chord(runs: Array[Dictionary], chain: Array[int], a: int, b: int) -> Dictionary:
	var first: Dictionary = runs[chain[a]]
	var last: Dictionary = runs[chain[b]]
	var origin: Vector2 = first["origin"]
	var endp: Vector2 = (last["origin"] as Vector2) + (last["delta"] as Vector2)
	var delta: Vector2 = endp - origin
	var nrm: Vector2 = Vector2(-delta.y, delta.x)
	if nrm.length_squared() > 0.0001:
		nrm = nrm.normalized()
	var acc: Vector2 = Vector2.ZERO
	for k in range(a, b + 1):
		acc += runs[chain[k]]["normal"] as Vector2
	if nrm.dot(acc) < 0.0:
		nrm = -nrm
	var made: Dictionary = {
		"origin": origin,
		"delta": delta,
		"normal": nrm,
		"thick": float(first.get("thick", 1.0)),
	}
	if first.has("cap_a"):
		made["cap_a"] = first["cap_a"] == true
	if last.has("cap_b"):
		made["cap_b"] = last["cap_b"] == true
	return made
static func _emit_chain(runs: Array[Dictionary], chain: Array[int], out: Array[Dictionary]) -> void:
	var count: int = chain.size()
	if count < 1:
		return
	var i: int = 0
	while i < count:
		var best: int = i
		var j: int = i + 1
		while j < count and _can_fold(runs, chain, i, j):
			best = j
			j += 1
		if best == i:
			out.append(runs[chain[i]])
		else:
			out.append(_chord(runs, chain, i, best))
		i = best + 1
static func _fold_teeth(runs: Array[Dictionary]) -> Array[Dictionary]:
	var n: int = runs.size()
	var nexts: PackedInt32Array = PackedInt32Array()
	nexts.resize(n)
	nexts.fill(-1)
	var starts: Dictionary = {}
	for i in n:
		var key: Vector2i = _pt_key(runs[i]["origin"] as Vector2)
		if not starts.has(key):
			starts[key] = []
		var bucket: Array = starts[key]
		bucket.append(i)
	for i in n:
		var run: Dictionary = runs[i]
		var endp: Vector2 = (run["origin"] as Vector2) + (run["delta"] as Vector2)
		var key2: Vector2i = _pt_key(endp)
		if not starts.has(key2):
			continue
		var nrm: Vector2 = _unit2(run["normal"] as Vector2)
		var cands: Array = starts[key2]
		var pick: int = -1
		for cand in cands:
			var j: int = int(cand)
			if j == i:
				continue
			var other: Dictionary = runs[j]
			if nrm.dot(_unit2(other["normal"] as Vector2)) < 0.5:
				continue
			if not _link_ok(run["delta"] as Vector2, other["delta"] as Vector2):
				continue
			if pick >= 0:
				pick = -2
				break
			pick = j
		if pick >= 0:
			nexts[i] = pick
	var indeg: PackedInt32Array = PackedInt32Array()
	indeg.resize(n)
	indeg.fill(0)
	for i in n:
		var nx: int = nexts[i]
		if nx >= 0:
			indeg[nx] = indeg[nx] + 1
	for i in n:
		var nx2: int = nexts[i]
		if nx2 >= 0 and indeg[nx2] != 1:
			nexts[i] = -1
	var pointed: PackedByteArray = PackedByteArray()
	pointed.resize(n)
	for i in n:
		var nx3: int = nexts[i]
		if nx3 >= 0:
			pointed[nx3] = 1
	var used: PackedByteArray = PackedByteArray()
	used.resize(n)
	var out: Array[Dictionary] = []
	for wave in 2:
		for i in n:
			if used[i] != 0:
				continue
			if wave == 0 and pointed[i] != 0:
				continue
			var chain: Array[int] = []
			var cur: int = i
			var guard: int = 0
			while cur >= 0 and used[cur] == 0 and guard <= n:
				used[cur] = 1
				chain.append(cur)
				cur = nexts[cur]
				guard += 1
			_emit_chain(runs, chain, out)
	return out
static func _merge_opposite(runs: Array[Dictionary]) -> Array[Dictionary]:
	var n: int = runs.size()
	var drop: PackedByteArray = PackedByteArray()
	drop.resize(n)
	for i in n:
		if drop[i] != 0:
			continue
		var a: Dictionary = runs[i]
		var ao: Vector2 = a["origin"]
		var ad: Vector2 = a["delta"]
		var al: float = ad.length()
		if al < 0.2:
			continue
		var at: Vector2 = ad / al
		var an: Vector2 = _unit2(a["normal"] as Vector2)
		for j in range(i + 1, n):
			if drop[j] != 0:
				continue
			var b: Dictionary = runs[j]
			var bn: Vector2 = _unit2(b["normal"] as Vector2)
			if an.dot(bn) > -0.85:
				continue
			var bo: Vector2 = b["origin"]
			var bd: Vector2 = b["delta"]
			var bl: float = bd.length()
			if bl < 0.2:
				continue
			var b0: float = (bo - ao).dot(at)
			var b1: float = (bo + bd - ao).dot(at)
			var lo: float = b0 if b0 < b1 else b1
			var hi: float = b1 if b1 > b0 else b0
			var overlap: float = minf(al, hi) - maxf(0.0, lo)
			var shorter: float = al if al < bl else bl
			if overlap < shorter * 0.6:
				continue
			var rel: Vector2 = (bo + bd * 0.5) - ao
			var lateral: Vector2 = rel - at * rel.dot(at)
			if lateral.length() > 1.35:
				continue
			if bl > al:
				drop[i] = 1
				break
			drop[j] = 1
	var kept: Array[Dictionary] = []
	for i in n:
		if drop[i] == 0:
			kept.append(runs[i])
	return kept
static func prepare(raw: Array) -> Array[Dictionary]:
	var runs: Array[Dictionary] = []
	for item in raw:
		if item is Dictionary and (item as Dictionary).has("delta"):
			runs.append(item as Dictionary)
	if runs.is_empty():
		return runs
	return _merge_opposite(_fold_teeth(runs))
