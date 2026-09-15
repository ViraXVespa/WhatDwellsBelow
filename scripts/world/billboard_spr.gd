extends Object

## Shared Y-billboard Sprite3D flags (design/reuse-map.md BOT-08).

const SpriteFilt := preload("res://scripts/world/sprite_filter.gd")


static func bare(prio: int = 0) -> Sprite3D:
	var s := Sprite3D.new()
	s.centered = true
	s.shaded = false
	s.billboard = BaseMaterial3D.BILLBOARD_FIXED_Y
	s.alpha_cut = SpriteBase3D.ALPHA_CUT_OPAQUE_PREPASS
	s.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	s.render_priority = prio
	return s


static func make(path: String, world_h: float, y: float, prio: int = 0, decorate: bool = true) -> Sprite3D:
	var s: Sprite3D = bare(prio)
	s.position.y = y
	if path != "" and ResourceLoader.exists(path):
		s.texture = load(path)
		s.pixel_size = world_h / float(maxi(1, s.texture.get_height()))
	if decorate:
		s = SpriteFilt.decorate(s)
	return s
