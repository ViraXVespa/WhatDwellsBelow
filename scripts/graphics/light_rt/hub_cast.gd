extends Object

## Hub yard shadow boxes: building skirts cast onto the baked hub light image.

const RT_PATH := "res://scripts/graphics/light_rt.gd"

static func _hub_cast_buildings(img: Image, x0: int, z0: int, layout: Node) -> int:
	var rt: Variant = load(RT_PATH)
	if img == null:
		return 0
	var away := Vector2(0.406138, 0.913811)
	var boxes: Array = _hub_yard_boxes(layout, false)
	var sub: float = float(rt.HUB_SUB)
	var w: int = img.get_width()
	var h: int = img.get_height()
	var wrote: int = 0
	var i: int = 0
	while i < boxes.size():
		var b: Dictionary = boxes[i]
		wrote += _hub_stamp_skirt(img, x0, z0, sub, w, h, b, away)
		i += 1
	return wrote
static func _hub_stamp_skirt(
	img: Image, x0: int, z0: int, sub: float, w: int, h: int, b: Dictionary, away: Vector2
) -> int:
	var reach: float = float(b["h"]) * 0.85
	var cx: float = float(b["x"])
	var cz: float = float(b["z"])
	var hx: float = float(b["hx"])
	var hz: float = float(b["hz"])
	var an: float = away.length()
	var ax: float = away.x / maxf(an, 0.001)
	var az: float = away.y / maxf(an, 0.001)
	var pad: float = reach + 0.45
	var px0: int = clampi(int(floor((cx - hx - pad - float(x0)) * sub)), 0, w - 1)
	var px1: int = clampi(int(ceil((cx + hx + pad - float(x0)) * sub)), 0, w)
	var pz0: int = clampi(int(floor((cz - hz - pad - float(z0)) * sub)), 0, h - 1)
	var pz1: int = clampi(int(ceil((cz + hz + pad - float(z0)) * sub)), 0, h)
	# A pixel only changes when its 20-step ray (reaching back ax*reach, az*reach) comes within 0.04 of the box,
	# or it lies inside a tarp. Narrow the loops to that swept rectangle (plus 1 px); the rest wrote nothing.
	var sx_lo: float = minf(0.0, -ax * reach)
	var sx_hi: float = maxf(0.0, -ax * reach)
	var sz_lo: float = minf(0.0, -az * reach)
	var sz_hi: float = maxf(0.0, -az * reach)
	var m: float = 0.05
	px0 = maxi(px0, int(floor((cx - hx - m - sx_hi - float(x0)) * sub)) - 1)
	px1 = mini(px1, int(ceil((cx + hx + m - sx_lo - float(x0)) * sub)) + 1)
	pz0 = maxi(pz0, int(floor((cz - hz - m - sz_hi - float(z0)) * sub)) - 1)
	pz1 = mini(pz1, int(ceil((cz + hz + m - sz_lo - float(z0)) * sub)) + 1)
	var kind: String = str(b.get("kind", ""))
	var tarp: bool = kind == "tarp"
	var ridge_eave: bool = kind == "gable" or tarp
	var awning: bool = kind == "awning"
	var ridge: float = float(b["ridge"]) if b.has("ridge") else 0.0
	var eave: float = float(b["eave"]) if b.has("eave") else 0.0
	var hem: float = float(b["hem"]) if b.has("hem") else 0.0
	var flat: float = float(b.get("h", 1.0))
	var hz_div: float = maxf(hz, 0.001)
	var hz2_div: float = maxf(hz * 2.0, 0.001)
	var ts := PackedFloat64Array()
	var lim := PackedFloat64Array()
	var shade := PackedFloat64Array()
	for step in 20:
		var t: float = reach * float(step) / 19.0
		ts.append(t)
		lim.append(t / 0.85 + 0.03)
		var fade: float = clampf(t / maxf(reach, 0.001), 0.0, 1.0)
		var tip: float = clampf((fade - 0.62) / 0.38, 0.0, 1.0)
		shade.append(lerpf(0.46, 0.86, tip))
	var wrote: int = 0
	var y: int = pz0
	while y < pz1:
		var x: int = px0
		var wz: float = float(z0) + (float(y) + 0.5) / sub
		while x < px1:
			var wx: float = float(x0) + (float(x) + 0.5) / sub
			var inside: bool = absf(wx - cx) <= hx and absf(wz - cz) <= hz
			if inside and not tarp:
				x += 1
				continue
			var best: float = 1.0
			if inside and tarp:
				best = 0.8
			var step: int = 0
			while step < 20:
				var sx: float = wx - ax * ts[step]
				var sz: float = wz - az * ts[step]
				var dx: float = absf(sx - cx) - hx
				var dz: float = absf(sz - cz) - hz
				if dx <= 0.04 and dz <= 0.04:
					var roof: float = flat
					if ridge_eave:
						roof = lerpf(ridge, eave, clampf(absf(sz - cz) / hz_div, 0.0, 1.0))
					elif awning:
						roof = lerpf(eave, hem, clampf((sz - (cz - hz)) / hz2_div, 0.0, 1.0))
					if roof > lim[step]:
						best = minf(best, shade[step])
				step += 1
			if best > 0.96:
				x += 1
				continue
			var c: Color = img.get_pixel(x, y)
			img.set_pixel(x, y, Color(minf(c.r, best), minf(c.g, best), minf(c.b, best), 1.0))
			wrote += 1
			x += 1
		y += 1
	return wrote
static func _hub_yard_boxes(layout: Node, _bake: bool) -> Array:
	var boxes: Array = []
	if layout != null and layout.has_method("hall_pos"):
		var hp: Vector3 = layout.hall_pos()
		var hb: Vector3 = layout.hall_box
		boxes.append(_hub_gable(hp, hb))
		var wp: Vector3 = layout.wing_pos()
		var wb: Vector3 = layout.wing_box
		boxes.append(_hub_gable(wp, wb))
		boxes.append(_hub_awning(hp, hb, layout.awning_depth("Hall")))
		boxes.append(_hub_awning(wp, wb, layout.awning_depth("Wing")))
		var sp: Vector3 = layout.stall_pos()
		var sb: Vector3 = layout.stall_box
		boxes.append(_hub_tarp(sp, sb))
		_hub_prop_blobs(layout, boxes)
		boxes.append(_hub_post(sp, sb, -1.0, -1.0))
		boxes.append(_hub_post(sp, sb, 1.0, -1.0))
		boxes.append(_hub_post(sp, sb, -1.0, 1.0))
		boxes.append(_hub_post(sp, sb, 1.0, 1.0))
	else:
		boxes.append(_hub_gable(Vector3(8.2, 0.0, 6.0), Vector3(5.6, 3.4, 4.2)))
		boxes.append(_hub_tarp(Vector3(25.0, 0.0, 8.0), Vector3(4.6, 2.4, 3.4)))
	return boxes
static func _hub_prop_blobs(layout: Node, boxes: Array) -> void:
	if layout == null:
		return
	var names: Array = ["anvil", "dumpster", "board", "notice", "crystal", "dummy", "vendor"]
	var i: int = 0
	while i < names.size():
		var meth: String = str(names[i]) + "_pos"
		if layout.has_method(meth):
			var p: Vector3 = layout.call(meth)
			boxes.append({
				"kind": "post",
				"x": p.x,
				"z": p.z,
				"hx": 0.34,
				"hz": 0.26,
				"eave": 0.65,
				"ridge": 0.65,
				"h": 0.85
			})
		i += 1
static func _hub_gable(pos: Vector3, box: Vector3) -> Dictionary:
	var eave: float = maxf(box.y, 1.2) * 0.78
	return {
		"kind": "gable",
		"x": pos.x,
		"z": pos.z,
		"hx": box.x * 0.5,
		"hz": box.z * 0.5,
		"eave": eave,
		"ridge": eave + 0.5,
		"h": eave + 0.5
	}
static func _hub_awning(pos: Vector3, box: Vector3, depth: float) -> Dictionary:
	var eave: float = maxf(box.y, 1.2) * 0.78
	var span: float = maxf(depth, 0.4)
	return {
		"kind": "awning",
		"x": pos.x,
		"z": pos.z + box.z * 0.5 + span * 0.5,
		"hx": box.x * 0.5,
		"hz": span * 0.5,
		"eave": eave,
		"hem": eave * 0.66,
		"h": eave * 0.7
	}
static func _hub_tarp(pos: Vector3, box: Vector3) -> Dictionary:
	var eave: float = box.y * 0.42
	var ridge: float = eave + 0.92
	return {
		"kind": "tarp",
		"x": pos.x,
		"z": pos.z,
		"hx": box.x * 0.5,
		"hz": box.z * 0.5,
		"eave": eave,
		"ridge": ridge,
		"h": ridge
	}
static func _hub_post(pos: Vector3, box: Vector3, sx: float, sz: float) -> Dictionary:
	return {
		"kind": "post",
		"x": pos.x + sx * box.x * 0.42,
		"z": pos.z + sz * box.z * 0.42,
		"hx": 0.1,
		"hz": 0.1,
		"eave": 1.05,
		"ridge": 1.05,
		"h": 1.05
	}
static func _hub_roof_h(wx: float, wz: float, b: Dictionary) -> float:
	var dx: float = absf(wx - float(b["x"])) - float(b["hx"])
	var dz: float = absf(wz - float(b["z"])) - float(b["hz"])
	if dx > 0.04 or dz > 0.04:
		return 0.0
	var kind: String = str(b.get("kind", "box"))
	if kind == "gable" or kind == "tarp":
		var along: float = absf(wz - float(b["z"])) / maxf(float(b["hz"]), 0.001)
		return lerpf(float(b["ridge"]), float(b["eave"]), clampf(along, 0.0, 1.0))
	if kind == "awning":
		var wall_z: float = float(b["z"]) - float(b["hz"])
		var along_s: float = (wz - wall_z) / maxf(float(b["hz"]) * 2.0, 0.001)
		return lerpf(float(b["eave"]), float(b["hem"]), clampf(along_s, 0.0, 1.0))
	return float(b.get("h", 1.0))
static func _hub_inside(wx: float, wz: float, b: Dictionary) -> bool:
	return absf(wx - float(b["x"])) <= float(b["hx"]) and absf(wz - float(b["z"])) <= float(b["hz"])
