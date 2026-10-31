extends Object

## Hub bake only: a guild roof as a shadow receiver (hub_shadow.gd). The roof samples the atlas at its own XZ, so a
## taller neighbour's shadow is written inside the roof's footprint wherever the sun ray clears the roof surface there.
## The roof shape comes from the body's covering meshes (Gable, built from layout_spec.gd box, seat and rise).

const HubCast := preload("res://scripts/graphics/light_rt/hub_cast.gd")

## Receiver from a footprint and the merged world bounds of the body's covering meshes (two slopes, ridge along X).
static func make(body: Node, foot: Rect2, cover: AABB) -> Dictionary:
	return {
		"body": body, "rect": foot, "eave": cover.position.y, "ridge": cover.end.y,
		"rz": cover.get_center().z, "hz": maxf(cover.size.z * 0.5, 0.001),
	}

## Roof surface height over world z: ridge at rz, eave at rz +- hz.
static func height(r: Dictionary, wz: float) -> float:
	var t: float = clampf(absf(wz - float(r["rz"])) / float(r["hz"]), 0.0, 1.0)
	return lerpf(float(r["ridge"]), float(r["eave"]), t)

## Ground offset of a point h up along the sun (hub_shadow._hub_ground).
static func shift(h: float) -> Vector2:
	return HubCast.AWAY * (maxf(h, 0.0) * HubCast.REACH)

## The receiver whose footprint holds (wx, wz), or an empty Dictionary.
static func at(recv: Array, wx: float, wz: float) -> Dictionary:
	for r: Dictionary in recv:
		var f: Rect2 = r["rect"]
		if wx >= f.position.x and wx <= f.end.x and wz >= f.position.y and wz <= f.end.y:
			return r
	return {}

## Highest ridge among the receivers (how far back a triangle's pixel box must reach), 0 when none.
static func reach(recv: Array) -> float:
	var top: float = 0.0
	for r: Dictionary in recv:
		top = maxf(top, float(r["ridge"]))
	return top

## Each roof's own sun: its footprint texels (the roof samples them) scaled per slope by Lambert against flat ground,
## so the slope facing away from the sun reads darker than the yard. Returns texels written.
static func slopes(img: Image, org: Vector2, sub: float, recv: Array) -> int:
	var sun := Vector3(-HubCast.AWAY.x, 1.0 / HubCast.REACH, -HubCast.AWAY.y).normalized()
	var wrote: int = 0
	for r: Dictionary in recv:
		var f: Rect2 = r["rect"]
		var rise: float = float(r["ridge"]) - float(r["eave"])
		var hz: float = float(r["hz"])
		for y in range(maxi(0, int((f.position.y - org.y) * sub)), mini(img.get_height(), int(ceil((f.end.y - org.y) * sub)))):
			var wz: float = org.y + (float(y) + 0.5) / sub
			var n := Vector3(0.0, hz, rise * signf(wz - float(r["rz"]))).normalized()
			var k: float = clampf(n.dot(sun) / sun.y, 0.0, 1.0)
			for x in range(maxi(0, int((f.position.x - org.x) * sub)), mini(img.get_width(), int(ceil((f.end.x - org.x) * sub)))):
				var c: Color = img.get_pixel(x, y)
				img.set_pixel(x, y, Color(c.r * k, c.g * k, c.b * k, 1.0))
				wrote += 1
	return wrote
