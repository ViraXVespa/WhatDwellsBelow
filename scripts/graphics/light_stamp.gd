extends Object

## Fine solid blocks. Discs flood walkable texels from the mount. Cold fill is those samples only.
## Falloff is straight-line meters on a clear segment. Wall mass blocks the disc.
## The walk mask is gen solid under the texel center. Loops do not replace that mask.
## A 4-neighbor does not open a cell past the lip.
## Wall texels stay dark except the neighbor sample along the bake. SUB stays 4.

const HitchLog := preload("res://scripts/debug/hitch_log.gd")
const K := preload("res://scripts/graphics/light_stamp/stamp_k.gd")
const Fov := preload("res://scripts/graphics/light_stamp/fov.gd")
const Grid := preload("res://scripts/graphics/light_stamp/stamp_grid.gd")
const COL_FLOOR := Color(0.50, 0.56, 0.74)
static var _rr_buf: PackedFloat32Array = PackedFloat32Array()
static var _gg_buf: PackedFloat32Array = PackedFloat32Array()
static var _bb_buf: PackedFloat32Array = PackedFloat32Array()

static func solid_open(
	solid: PackedByteArray,
	sw: int,
	sh: int,
	n: int,
	world_x: float,
	world_z: float
) -> bool:
	if n < 1 or solid.is_empty() or sw < 1 or sh < 1:
		return false
	var fx: int = int(floor(world_x * float(n)))
	var fy: int = int(floor(world_z * float(n)))
	if fx < 0 or fy < 0 or fx >= sw or fy >= sh:
		return false
	return solid[fy * sw + fx] != 0

static func near_open(
	solid: PackedByteArray,
	sw: int,
	sh: int,
	n: int,
	world_x: float,
	world_z: float
) -> bool:
	if n < 1 or solid.is_empty():
		return true
	var step: float = 1.0 / float(K.SUB)
	for oy in range(-2, 3):
		for ox in range(-2, 3):
			var sx: float = world_x + float(ox) * step
			var sz: float = world_z + float(oy) * step
			if solid_open(solid, sw, sh, n, sx, sz):
				return true
	return false

static func paint(
	img: Image,
	tw: int,
	th: int,
	lights: Array,
	ambient: Color = Color(0, 0, 0, 1),
	solid: PackedByteArray = PackedByteArray(),
	sw: int = 0,
	sh: int = 0,
	n: int = 0,
	x0: int = 0,
	z0: int = 0,
	loops: Array = []
) -> void:
	var iw: int = tw * K.SUB
	var ih: int = th * K.SUB
	var pxn: int = iw * ih
	var walk: PackedByteArray = Grid._walk_mask(solid, sw, sh, n, x0, z0, iw, ih, loops)
	HitchLog.mark("light_walk")
	if _rr_buf.size() != pxn:
		_rr_buf.resize(pxn)
		_gg_buf.resize(pxn)
		_bb_buf.resize(pxn)
	var rr: PackedFloat32Array = _rr_buf
	var gg: PackedFloat32Array = _gg_buf
	var bb: PackedFloat32Array = _bb_buf
	var zi: int = 0
	while zi < Grid._floor_n:
		var fi: int = Grid._floor_ix[zi]
		rr[fi] = 0.0
		gg[fi] = 0.0
		bb[fi] = 0.0
		zi += 1
	for src in lights:
		var item: Dictionary = src
		Fov._disc(rr, gg, bb, walk, iw, ih, item, x0, z0, loops, n)
	HitchLog.mark("light_disc")
	Grid._lift_floor(rr, gg, bb, walk, iw, ih, ambient, n)
	HitchLog.mark("light_lift")
	Grid._walls(rr, gg, bb, walk, iw, ih, n)
	HitchLog.mark("light_walls")
	Grid._blit(img, rr, gg, bb, walk, iw, ih)
	HitchLog.mark("light_blit")
