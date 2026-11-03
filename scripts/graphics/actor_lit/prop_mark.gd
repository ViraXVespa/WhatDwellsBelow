extends Object

## One prop mark path for the hub yard props (camp_build.mark_props) and the dungeon props (gather_node trees/ore,
## breakable barrels/pots): the sprite at the ground pixel size (chunky.gd), no engine shadow, and the player's
## ActorLit mark (per-cell on the ground grid, per-column contact, torch/crystal and sun slots). solid: ActorLit.solid.

static func apply(n: Node3D, spr: Sprite3D, solid: String = "") -> void:
	if n == null or spr == null or n.has_node("ActorLit"):
		return
	if spr.texture != null:
		spr.texture = load("res://scripts/graphics/chunky.gd").tex(spr.texture, spr.pixel_size)
	spr.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	load("res://scripts/graphics/actor_lit.gd").bind(n, spr)
	n.get_node("ActorLit").set("solid", solid)
