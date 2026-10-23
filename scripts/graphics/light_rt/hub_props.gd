extends Object

## Hub bake only: yard prop shadows from their billboard art (anvil, dumpster, welcome banner) and the lamp pools. Spots come from
## Layout.spot_pos. Called from hub_shadow._hub_mesh_shadows.

## Yard props drawn as Y-billboards facing -Z (interact_fx / banner.gd): [spot, texture, world height, centre y].
const SPRITES: Array = [
	["Anvil", "res://assets/sprites/props/anvil.png", 0.85, 0.48],
	["Dumpster", "res://assets/sprites/props/dumpster.png", 0.85, 0.48],
	["Banner", "res://assets/sprites/props/welcome_banner.png", 4.4, 2.2],
]

## Prop shadows from the real art: every opaque texel of each prop billboard lands on the ground along
## HubCast.AWAY (same reach and shade as the mesh shadows), so the shadow matches the drawn outline and touches its foot.
static func project_sprites(img: Image, org: Vector2, sub: float, layout: Node, cast: GDScript) -> int:
	if layout == null or not layout.has_method("spot_pos"):
		return 0
	var wrote: int = 0
	for e in SPRITES:
		if not ResourceLoader.exists(e[1]):
			continue
		var src: Image = (load(e[1]) as Texture2D).get_image()
		if src.is_compressed():
			src.decompress()
		var at: Vector3 = layout.spot_pos(e[0])
		var tw: int = src.get_width()
		var th: int = src.get_height()
		var ps: float = float(e[2]) / float(th)
		var top: float = float(e[3]) + float(e[2]) * 0.5
		for v in th:
			var wy: float = float(e[3]) + (float(th) * 0.5 - float(v) - 0.5) * ps
			if wy <= 0.0:
				continue
			var shade: float = cast.shade_at(wy / top)
			var r: float = wy * cast.REACH
			for u in tw:
				if src.get_pixel(u, v).a < 0.5:
					continue
				var gx: float = at.x + (float(u) + 0.5 - float(tw) * 0.5) * ps + cast.AWAY.x * r
				var gz: float = at.z + cast.AWAY.y * r
				var x: int = int((gx - org.x) * sub)
				var y: int = int((gz - org.y) * sub)
				if x < 0 or y < 0 or x >= img.get_width() or y >= img.get_height():
					continue
				var c: Color = img.get_pixel(x, y)
				if c.r > shade:
					img.set_pixel(x, y, Color(minf(c.r, shade), minf(c.g, shade), minf(c.b, shade), 1.0))
					wrote += 1
	return wrote

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
