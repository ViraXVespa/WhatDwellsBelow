extends Object

## Hub bake only: soft-skirt boxes for the yard props (anvil, dumpster, welcome banner, fence). Spots come from
## Layout.spot_pos, so the boxes follow the Layout. Feeds hub_cast._hub_stamp_skirt (kind "post": flat top h).

const FENCE_H := 1.05
const FENCE_STEP := 2.0

static func append(layout: Node, boxes: Array) -> void:
	if layout == null or not layout.has_method("spot_pos"):
		return
	_box(boxes, layout.spot_pos("Anvil"), 0.34, 0.22, 0.75)
	_box(boxes, layout.spot_pos("Dumpster"), 0.45, 0.3, 0.9)
	var b: Vector3 = layout.spot_pos("Banner")
	_box(boxes, b + Vector3(-1.45, 0.0, 0.0), 0.14, 0.14, 2.6)
	_box(boxes, b + Vector3(1.45, 0.0, 0.0), 0.14, 0.14, 2.6)
	_box(boxes, b, 1.3, 0.05, 2.3)
	_fence(layout, boxes)

## Four runs on the slab edge (camp_view.fence): one post every ~2 m plus the top rail.
static func _fence(layout: Node, boxes: Array) -> void:
	var ox: float = float(layout.ground_ox)
	var oz: float = float(layout.ground_oz)
	var gw: float = float(layout.ground_w)
	var gd: float = float(layout.ground_d)
	var runs: Array = [
		[Vector2(ox, oz + 0.08), Vector2(ox + gw, oz + 0.08)],
		[Vector2(ox, oz + gd - 0.08), Vector2(ox + gw, oz + gd - 0.08)],
		[Vector2(ox + 0.08, oz), Vector2(ox + 0.08, oz + gd)],
		[Vector2(ox + gw - 0.08, oz), Vector2(ox + gw - 0.08, oz + gd)],
	]
	for r in runs:
		var a: Vector2 = r[0]
		var e: Vector2 = r[1]
		var mid: Vector2 = (a + e) * 0.5
		var along_x: bool = absf(e.x - a.x) > absf(e.y - a.y)
		var span: float = a.distance_to(e)
		var rail := Vector2(span * 0.5, 0.05) if along_x else Vector2(0.05, span * 0.5)
		_box(boxes, Vector3(mid.x, 0.0, mid.y), rail.x, rail.y, FENCE_H * 0.85)
		var n: int = maxi(2, int(round(span / FENCE_STEP)) + 1)
		for i in n:
			var p: Vector2 = a.lerp(e, float(i) / float(n - 1))
			_box(boxes, Vector3(p.x, 0.0, p.y), 0.09, 0.09, FENCE_H)

static func _box(boxes: Array, p: Vector3, hx: float, hz: float, h: float) -> void:
	boxes.append({"kind": "post", "x": p.x, "z": p.z, "hx": hx, "hz": hz, "eave": h, "ridge": h, "h": h})

## Warm pool on the yard under each "hub_lamp" (guild lanterns): lifts toward GLOW within GLOW_R metres.
const GLOW := Color(1.0, 0.8, 0.5)
const GLOW_R := 1.8
static func lamp_glow(img: Image, org: Vector2, sub: float, root: Node) -> int:
	var wrote: int = 0
	for lamp in root.get_tree().get_nodes_in_group("hub_lamp"):
		var p: Vector3 = (lamp as Node3D).global_position
		var cx: float = p.x
		var cz: float = p.z + 0.6
		for y in range(maxi(0, int((cz - GLOW_R - org.y) * sub)), mini(img.get_height(), int((cz + GLOW_R - org.y) * sub))):
			for x in range(maxi(0, int((cx - GLOW_R - org.x) * sub)), mini(img.get_width(), int((cx + GLOW_R - org.x) * sub))):
				var d: float = Vector2(org.x + (x + 0.5) / sub - cx, org.y + (y + 0.5) / sub - cz).length() / GLOW_R
				if d >= 1.0:
					continue
				var k: float = (1.0 - d) * (1.0 - d) * 0.45
				img.set_pixel(x, y, img.get_pixel(x, y).lerp(GLOW, k))
				wrote += 1
	return wrote
