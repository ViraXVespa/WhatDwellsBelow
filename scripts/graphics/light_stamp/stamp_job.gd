extends RefCounted

## Staged stamp: walk rows, floor clear, one disc per light, lift, walls and blit in small units.
## step(budget_us) runs units until the budget is spent (negative: all). The pixels do not depend on how many frames it takes.
## The float buffers stay static (their wall texels carry over between stamps, as before).

const HitchLog := preload("res://scripts/debug/hitch_log.gd")
const K := preload("res://scripts/graphics/light_stamp/stamp_k.gd")
const Fov := preload("res://scripts/graphics/light_stamp/fov.gd")
const Grid := preload("res://scripts/graphics/light_stamp/stamp_grid.gd")
const ROWS := 16
const RANGE := 4096
const DONE := 7

static var _rr: PackedFloat32Array = PackedFloat32Array()
static var _gg: PackedFloat32Array = PackedFloat32Array()
static var _bb: PackedFloat32Array = PackedFloat32Array()

var tw: int
var th: int
var x0: int
var z0: int
var n: int
var lights: Array
var ambient: Color
var solid: PackedByteArray
var sw: int
var sh: int
var loops: Array
var iw: int
var ih: int
var phase: int = 0
var cur: int = 0
var rows: int = 0

func setup(p: Dictionary) -> RefCounted:
	tw = int(p["tw"])
	th = int(p["th"])
	x0 = int(p["x0"])
	z0 = int(p["z0"])
	n = int(p["n"])
	lights = p["lights"]
	ambient = p["ambient"]
	solid = p["solid"]
	sw = int(p["sw"])
	sh = int(p["sh"])
	loops = p["loops"]
	iw = tw * K.SUB
	ih = th * K.SUB
	return self

func step(budget_us: int) -> bool:
	var t0: int = Time.get_ticks_usec()
	while phase < DONE:
		_unit()
		if budget_us >= 0 and Time.get_ticks_usec() - t0 >= budget_us:
			break
	return phase >= DONE

func image() -> Image:
	return Image.create_from_data(iw, ih, false, Image.FORMAT_RGBA8, Grid._rgba)

func _go(next: int, mark: String) -> void:
	HitchLog.mark(mark)
	phase = next
	cur = 0

func _unit() -> void:
	var fn: int = Grid._floor_n
	match phase:
		0:
			rows = ih if Grid._walk_begin(solid, sw, sh, n, iw, ih) else 0
			phase = 1
		1:
			if cur < rows:
				var to: int = mini(cur + ROWS, rows)
				Grid._walk_rows(solid, sw, sh, n, x0, z0, iw, cur, to)
				cur = to
			if cur >= rows:
				var pxn: int = iw * ih
				if _rr.size() != pxn:
					_rr.resize(pxn)
					_gg.resize(pxn)
					_bb.resize(pxn)
				_go(2, "light_walk")
		2:
			var to2: int = mini(cur + RANGE, fn)
			while cur < to2:
				var fi: int = Grid._floor_ix[cur]
				_rr[fi] = 0.0
				_gg[fi] = 0.0
				_bb[fi] = 0.0
				cur += 1
			if cur >= fn:
				_go(3, "light_clear")
		3:
			if cur < lights.size():
				Fov._disc(_rr, _gg, _bb, Grid._walk_buf, iw, ih, lights[cur], x0, z0, loops, n)
				cur += 1
			if cur >= lights.size():
				_go(4, "light_disc")
		4:
			var to4: int = mini(cur + RANGE, fn)
			Grid._lift_floor(_rr, _gg, _bb, Grid._walk_buf, iw, ih, ambient, n, cur, to4)
			cur = to4
			if cur >= fn:
				_go(5, "light_lift")
		5:
			var to5: int = mini(cur + RANGE, fn)
			Grid._walls(_rr, _gg, _bb, Grid._walk_buf, iw, ih, n, cur, to5)
			cur = to5
			if cur >= fn:
				_go(6, "light_walls")
		6:
			if cur == 0 and not Grid._blit_begin(_rr, _gg, _bb, iw, ih):
				_go(DONE, "light_blit")
				return
			var to6: int = mini(cur + RANGE, fn)
			Grid._blit_range(_rr, _gg, _bb, Grid._walk_buf, iw, ih, cur, to6)
			cur = to6
			if cur >= fn:
				_go(DONE, "light_blit")
