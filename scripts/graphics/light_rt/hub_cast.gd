extends Object

## Hub bake sun (AWAY, REACH, shade ramp; hub_shadow.gd projects every mesh with it) and the stall tarp lid.

const RT_PATH := "res://scripts/graphics/light_rt.gd"
## Shadows fall along AWAY (+X +Z, same as the actor blobs); REACH metres of ground per metre of height.
## Shade runs SHADE_NEAR at the caster to SHADE_TIP at its far end (last 1 - TIP_FROM of the length).
## hub_shadow.gd uses the same numbers for the mesh shadows.
const AWAY := Vector2(0.406138, 0.913811)
const REACH := 0.85
const SHADE_NEAR := 0.46
const SHADE_TIP := 0.86
const TIP_FROM := 0.62

static func shade_at(fade: float) -> float:
	return lerpf(SHADE_NEAR, SHADE_TIP, clampf((fade - TIP_FROM) / (1.0 - TIP_FROM), 0.0, 1.0))

## The bake draws every shadow from the meshes (hub_shadow.gd); only the stall tarp lid (Layout.stall_lid) is a box.
static func _hub_cast_buildings(img: Image, x0: int, z0: int, layout: Node) -> int:
	if img == null or layout == null or not layout.has_method("stall_lid"):
		return 0
	var b: Dictionary = layout.stall_lid()
	printerr("bake_dbg: box tarp %.3f %.3f %.3f %.3f %.3f" % [b["x"], b["z"], b["hx"], b["hz"], b["h"]])
	return _hub_stamp_lid(img, x0, z0, float(load(RT_PATH).HUB_SUB), img.get_width(), img.get_height(), b)
## The tarp lid samples the atlas, so its footprint takes the near shade; its shadow comes from the meshes.
static func _hub_stamp_lid(img: Image, x0: int, z0: int, sub: float, w: int, h: int, b: Dictionary) -> int:
	var px0: int = clampi(int(floor((float(b["x"]) - float(b["hx"]) - float(x0)) * sub)), 0, w - 1)
	var px1: int = clampi(int(ceil((float(b["x"]) + float(b["hx"]) - float(x0)) * sub)), 0, w)
	var pz0: int = clampi(int(floor((float(b["z"]) - float(b["hz"]) - float(z0)) * sub)), 0, h - 1)
	var pz1: int = clampi(int(ceil((float(b["z"]) + float(b["hz"]) - float(z0)) * sub)), 0, h)
	var wrote: int = 0
	for y in range(pz0, pz1):
		for x in range(px0, px1):
			if not _hub_inside(float(x0) + (float(x) + 0.5) / sub, float(z0) + (float(y) + 0.5) / sub, b):
				continue
			var c: Color = img.get_pixel(x, y)
			img.set_pixel(x, y, Color(minf(c.r, SHADE_NEAR), minf(c.g, SHADE_NEAR), minf(c.b, SHADE_NEAR), 1.0))
			wrote += 1
	return wrote
static func _hub_inside(wx: float, wz: float, b: Dictionary) -> bool:
	return absf(wx - float(b["x"])) <= float(b["hx"]) and absf(wz - float(b["z"])) <= float(b["hz"])
