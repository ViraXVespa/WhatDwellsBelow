extends Object

## Touch HUD layout for a landscape phone: one pure function from viewport size + safe-area insets to button rows,
## so hit-testing and the touch-layout check read the same geometry. Sizes are canvas units at a 1080-tall canvas
## (about 15 units per mm on a phone held sideways): Attack ~13 mm, the other thumb buttons ~9.5 mm, item slots ~7 mm.
##
## Right thumb: Attack (or the bow aim stick in Bow mode) sits in the bottom-right corner; Special, Dash and Interact
## fan around it on the thumb's arc (left, up-left, up); Target lock, Food and Potion sit in a row above the arc
## (a column up the right edge on a narrow canvas, so the playfield centre stays clear).
## Map and Pause are two small chips at the top centre, off the thumb and away from the HUD card and the minimap.
## The left move stick floats: it appears under the finger anywhere in the move zone; its idle ring marks the zone.

const ATTACK_R := 100.0
const THUMB_R := 72.0
const SLOT_R := 52.0
const CHIP_R := 44.0
const GAP := 16.0
const EDGE := 36.0
const MOVE_R := 120.0
const SLOP := 10.0

## Scale for the viewport (short side vs a 1080 canvas), clamped so tablets do not get dinner plates.
static func scale_for(vp: Vector2) -> float:
	return clampf(minf(vp.x, vp.y) / 1080.0, 0.75, 1.25)

## insets: x left, y top, z right, w bottom (canvas units). bow: Attack becomes the aim stick.
static func compute(vp: Vector2, insets: Vector4, bow: bool) -> Array:
	var s := scale_for(vp)
	var ar := ATTACK_R * s
	var tr := THUMB_R * s
	var sr := SLOT_R * s
	var cr := CHIP_R * s
	var gap := GAP * s
	var edge := EDGE * s
	var a := Vector2(vp.x - insets.z - edge - ar, vp.y - insets.w - edge - ar)
	var d := ar + tr + gap
	var rows: Array = [
		{"action": "attack", "kind": "stick" if bow else "btn", "pos": a, "r": ar},
		{"action": "special", "kind": "btn", "pos": a + Vector2(-d, 0.0), "r": tr},
		{"action": "dash", "kind": "btn", "pos": a + Vector2(-d, -d).normalized() * d * 1.15, "r": tr},
		{"action": "interact", "kind": "btn", "pos": a + Vector2(0.0, -d), "r": tr},
	]
	var row_y := a.y - d - tr - gap - sr
	var step := sr * 2.0 + gap
	# A narrow canvas (4:3) would push the row into the playfield centre: stack it up the right edge instead.
	var col := a.x - step * 2.0 - sr < vp.x * 0.66
	var off := Vector2(0.0, -step) if col else Vector2(-step, 0.0)
	var p0 := Vector2(a.x, row_y)
	rows.append({"action": "potion", "kind": "slot", "pos": p0, "r": sr})
	rows.append({"action": "food", "kind": "slot", "pos": p0 + off, "r": sr})
	rows.append({"action": "target_lock", "kind": "slot", "pos": p0 + off * 2.0, "r": sr})
	var top := insets.y + edge * 0.6 + cr
	rows.append({"action": "map_view", "kind": "chip", "pos": Vector2(vp.x * 0.5 - cr - gap * 0.5, top), "r": cr})
	rows.append({"action": "pause", "kind": "chip", "pos": Vector2(vp.x * 0.5 + cr + gap * 0.5, top), "r": cr})
	return rows

static func move_radius(vp: Vector2) -> float:
	return MOVE_R * scale_for(vp)

## Where the idle move ring sits (bottom-left, inside the safe area).
static func move_home(vp: Vector2, insets: Vector4) -> Vector2:
	var r := move_radius(vp)
	var edge := EDGE * scale_for(vp)
	return Vector2(insets.x + edge + r * 1.2, vp.y - insets.w - edge - r * 1.2)

## The left move zone: below the HUD card, left of the thumb cluster.
static func in_move_zone(vp: Vector2, pos: Vector2) -> bool:
	return pos.x <= vp.x * 0.45 and pos.y >= vp.y * 0.25

## The row a touch at pos lands on (the nearest centre within radius + slop), or {}.
static func hit(rows: Array, pos: Vector2, s: float) -> Dictionary:
	var best: Dictionary = {}
	var best_d := INF
	for row: Dictionary in rows:
		var dist: float = pos.distance_to(row["pos"])
		if dist <= float(row["r"]) + SLOP * s and dist < best_d:
			best = row
			best_d = dist
	return best
