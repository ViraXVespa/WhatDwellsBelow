extends Object

## Fine solid blocks. Discs flood walkable texels from the mount. Cold fill is those samples only.
## Falloff is straight-line meters on a clear segment. Wall mass blocks the disc.
## The walk mask is gen solid under the texel center. Loops do not replace that mask.
## A 4-neighbor does not open a cell past the lip.
## Wall texels stay dark except the neighbor sample along the bake. SUB stays 4.

const K := preload("res://scripts/graphics/light_stamp/stamp_k.gd")
const Job := preload("res://scripts/graphics/light_stamp/stamp_job.gd")
const Grid := preload("res://scripts/graphics/light_stamp/stamp_grid.gd")
const COL_FLOOR := Color(0.50, 0.56, 0.74)

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

static func begin(
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
) -> RefCounted:
	return Job.new().setup({
		"tw": tw, "th": th, "lights": lights, "ambient": ambient, "solid": solid,
		"sw": sw, "sh": sh, "n": n, "x0": x0, "z0": z0, "loops": loops,
	})

## One call, whole stamp. The staged path (begin + step) gives the same pixels.
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
	var job: RefCounted = begin(tw, th, lights, ambient, solid, sw, sh, n, x0, z0, loops)
	job.step(-1)
	img.set_data(job.iw, job.ih, false, Image.FORMAT_RGBA8, Grid._rgba)
