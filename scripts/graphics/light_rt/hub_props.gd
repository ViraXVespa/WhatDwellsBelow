extends Object

## Hub bake only: the lamp pools. Yard props (anvil, dumpster, banner, board, controls) use the player's live ActorLit mark
## (camp_build.mark_props) and stay out of the bake. Called from hub_shadow._hub_mesh_shadows.

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
