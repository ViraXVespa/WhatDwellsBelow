extends Object

## Live Sprite3D filter. System cycles 0–2; debug Settings can use 3–4.

const FILT_NEAREST := 0
const FILT_NEAR_MIP := 1
const FILT_NEAR_ANISO := 2
const FILT_LINEAR := 3
const FILT_LIN_MIP := 4
const FILT_SYS_MAX := 2
const FILT_MAX := 4

const LABELS: PackedStringArray = [
	"Nearest",
	"Nearest + mips",
	"Nearest + mips + aniso",
	"Linear",
	"Linear + mips",
]


static func clamp_id(id: int, allow_linear := false) -> int:
	return clampi(id, 0, FILT_MAX if allow_linear else FILT_SYS_MAX)


static func label(id: int) -> String:
	id = clampi(id, 0, FILT_MAX)
	return LABELS[id]


static func godot_filter(id: int) -> BaseMaterial3D.TextureFilter:
	match clampi(id, 0, FILT_MAX):
		FILT_NEAREST:
			return BaseMaterial3D.TEXTURE_FILTER_NEAREST
		FILT_NEAR_MIP:
			return BaseMaterial3D.TEXTURE_FILTER_NEAREST_WITH_MIPMAPS
		FILT_NEAR_ANISO:
			return BaseMaterial3D.TEXTURE_FILTER_NEAREST_WITH_MIPMAPS_ANISOTROPIC
		FILT_LINEAR:
			return BaseMaterial3D.TEXTURE_FILTER_LINEAR
		FILT_LIN_MIP:
			return BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
		_:
			return BaseMaterial3D.TEXTURE_FILTER_NEAREST_WITH_MIPMAPS_ANISOTROPIC


static func cycle_sys(cur: int, dir := 1) -> int:
	return posmod(clamp_id(cur, false) + dir, FILT_SYS_MAX + 1)


static func cycle_all(cur: int, dir := 1) -> int:
	return posmod(clamp_id(cur, true) + dir, FILT_MAX + 1)


static func apply_sprite(s: Sprite3D) -> void:
	if s == null:
		return
	s.texture_filter = godot_filter(int(App.get("sprite_filter")))
	if s.texture:
		s.texture = ensure_mips(s.texture)


static func decorate(s: Sprite3D) -> Sprite3D:
	apply_sprite(s)
	return s


static func apply_tree(n: Node = null) -> void:
	ProjectSettings.set_setting(
		"rendering/textures/default_filters/use_nearest_mipmap_filter",
		bool(App.get("sprite_mip_sharp"))
	)
	if n == null:
		var tree := App.get_tree()
		if tree:
			n = tree.root
	if n == null:
		return
	_walk(n)


static func _walk(n: Node) -> void:
	if n is Sprite3D:
		apply_sprite(n as Sprite3D)
	for c in n.get_children():
		_walk(c)


static func ensure_mips(tex: Texture2D) -> Texture2D:
	if tex == null:
		return tex
	if tex.has_mipmaps():
		return tex
	var img: Image = tex.get_image()
	if img == null:
		return tex
	if not img.has_mipmaps():
		img.generate_mipmaps()
	return ImageTexture.create_from_image(img)
