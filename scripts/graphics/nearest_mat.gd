extends Object

## Shared nearest-filter StandardMaterial3D with texture or fallback color.


static func make(tex_path: String, fallback: Color, unshaded: bool = true) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED if unshaded else BaseMaterial3D.SHADING_MODE_PER_PIXEL
	mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	if ResourceLoader.exists(tex_path):
		mat.albedo_texture = load(tex_path)
		mat.albedo_color = Color.WHITE
	else:
		mat.albedo_color = fallback
	return mat
