extends RefCounted

## Dungeon walls block torch/crystal light in the live light map (light_stamp/fov.gd line of sight; no bake, no sun).
## leak: floor past a wall from every nearby cast stays at ambient while open floor at the same range is lit.
## walls_planted: restamp without line of sight (the leaking path) and measure; must say "caught". to_wall: stand by
## the cast with the most floor behind a wall.

const LightRt := preload("res://scripts/graphics/light_rt.gd")
const Publish := preload("res://scripts/graphics/light_rt/publish.gd")
const Fov := preload("res://scripts/graphics/light_stamp/fov.gd")
const NEAR := 10.0
const STEP := 0.25
const LEAK_K := 0.25
static var last := ""
static var near_all := false

static func _player() -> Vector2:
	var p: Node3D = Engine.get_main_loop().get_first_node_in_group("player") as Node3D
	return Vector2.ZERO if p == null else Vector2(p.global_position.x, p.global_position.z)

static func _casts() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var me: Vector2 = _player()
	for c in LightRt._casts:
		if _inside(c["xz"]) and (near_all or (c["xz"] as Vector2).distance_to(me) <= NEAR):
			out.append(c)
	return out

static func _inside(p: Vector2) -> bool:
	var o: Vector2 = LightRt.origin + Vector2.ONE
	return Rect2(o, LightRt.span - Vector2.ONE * 2.0).has_point(p)

static func _sees(a: Vector2, b: Vector2) -> bool:
	var d: float = a.distance_to(b)
	var n: int = int(ceil(d / 0.125))
	for i in range(2, n - 1):
		if not LightRt.floor_open(a.lerp(b, float(i) / float(n))):
			return false
	return true

## Hidden with margin: no ray from a to b or to b nudged 0.35 m in any direction stays on open floor.
static func _hid(a: Vector2, b: Vector2) -> bool:
	for d in [Vector2.ZERO, Vector2(0.35, 0), Vector2(-0.35, 0), Vector2(0, 0.35), Vector2(0, -0.35)]:
		if _sees(a, b + d):
			return false
	return true

static func _lum(p: Vector2) -> float:
	var c: Color = LightRt.sample_xz(p)
	return maxf(c.r, maxf(c.g, c.b))

static func _leak() -> String:
	near_all = true
	var cs: Array[Dictionary] = _casts()
	near_all = false
	if cs.is_empty():
		return "no torch/crystal cast in the light map (casts %d)" % LightRt._casts.size()
	var amb := 9.0
	var vis := 0.0
	var nv := 0
	var hid := 0.0
	var nh := 0
	var worst := 0.0
	for c in cs:
		var o: Vector2 = c["xz"]
		var r: float = float(c["reach"])
		var y := -r
		while y <= r:
			var x := -r
			while x <= r:
				var p: Vector2 = o + Vector2(x, y)
				var d: float = p.distance_to(o)
				if d >= 1.5 and d <= r and _inside(p) and _inside(o) and LightRt.floor_open(p):
					var l: float = _lum(p)
					if _sees(o, p):
						vis += l
						nv += 1
					elif _hid(o, p):
						var dark := true
						for c2 in cs:
							var o2: Vector2 = c2["xz"]
							if p.distance_to(o2) <= float(c2["reach"]) + 0.5 and not _hid(o2, p):
								dark = false
								break
						if dark:
							hid += l
							nh += 1
							worst = maxf(worst, l)
				x += STEP
			y += STEP
	var far: Array[float] = []
	var q: Vector2 = LightRt.origin + Vector2.ONE * 1.5
	while q.y < LightRt.origin.y + LightRt.span.y - 1.5:
		q.x = LightRt.origin.x + 1.5
		while q.x < LightRt.origin.x + LightRt.span.x - 1.5:
			var out := LightRt.floor_open(q)
			for c in cs:
				if out and q.distance_to(c["xz"]) <= float(c["reach"]) + 1.0:
					out = false
			if out:
				far.append(_lum(q))
			q.x += 1.0
		q.y += 1.0
	if far.size() < 8:
		return "too little unlit floor for ambient (%d)" % far.size()
	far.sort()
	amb = far[far.size() / 2]
	if nv < 8 or nh < 8:
		return "too few samples (lit %d, behind walls %d, casts %d)" % [nv, nh, cs.size()]
	vis /= nv
	hid /= nh
	last = "lit %.3f behind-wall %.3f ambient %.3f worst %.3f (n %d/%d)" % [vis, hid, amb, worst, nv, nh]
	if hid - amb > LEAK_K * (vis - amb):
		return "light leaks through walls: " + last
	return ""

static func _walls_planted() -> String:
	_restamp()
	var ok: String = _leak()
	_save("new")
	Fov.plant_leak = true
	var r: String = _restamp()
	var why: String = _leak()
	_save("leak")
	Fov.plant_leak = false
	_restamp()
	if r != "ok" or ok != "":
		return r + " " + ok
	return "caught" if why.begins_with("light leaks") else "missed: " + why + last

static func _save(tag: String) -> void:
	var dir: String = OS.get_environment("WDB_WALL_MAPS")
	if dir != "" and LightRt._img != null:
		LightRt._img.save_png(dir.path_join("lightmap-%s.png" % tag))
		FileAccess.open(dir.path_join("lightmap.txt"), FileAccess.WRITE).store_string("%s %s" % [str(LightRt.origin), str(LightRt.span)])

var leak: String:
	get: return _leak()
var walls_planted: String:
	get: return _walls_planted()

## Moves the player beside the cast with the most floor hidden behind walls (scans every cast in the ring).
var to_wall: String:
	get:
		return _to_wall(1e9)

static func _to_wall(lim: float) -> String:
	near_all = true
	var best: Vector2 = Vector2.INF
	var most := 0
	var me: Vector2 = _player()
	for c in LightRt._casts:
		var o: Vector2 = c["xz"]
		if o.distance_to(me) > lim or not _inside(o):
			continue
		var n := 0
		for k in 900:
			var p: Vector2 = o + Vector2(float(k % 30) - 15.0, float(k / 30) - 15.0) * 0.3
			if p.distance_to(o) <= float(c["reach"]) and _inside(p) and _inside(o) and LightRt.floor_open(p) and not _sees(o, p):
				n += 1
		if n > most:
			most = n
			best = o
	near_all = false
	if most < 8:
		return "no cast with floor behind a wall (me %s, casts %d, rect %s %s, most %d)" % [str(me), LightRt._casts.size(), str(LightRt.origin), str(LightRt.span), most]
	var pl: Node3D = Engine.get_main_loop().get_first_node_in_group("player") as Node3D
	for k in 64:
		var q: Vector2 = best + Vector2(float(k % 8) - 3.5, float(k / 8) - 3.5) * 0.5
		if q.distance_to(best) > 1.0 and LightRt.floor_open(q) and _sees(best, q):
			pl.global_position = Vector3(q.x, pl.global_position.y, q.y)
			return "ok"
	return "no open floor by the cast"

## Restamp the current ring now (synchronous, as on floor entry) so the plant is measured at once.
static func _restamp() -> String:
	var n: Node = Engine.get_main_loop().get_first_node_in_group("player")
	while n != null and n.get("geo_jobs") == null:
		n = n.get_parent()
	if n == null:
		return "no dungeon host"
	LightRt._job = null
	var job: RefCounted = Publish._begin_dungeon(n, LightRt._rect)
	job.step(-1)
	Publish._commit(job)
	return "ok"
