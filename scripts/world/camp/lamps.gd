extends Object

## Guild lamps: a flickering flame (torch_bill's FLAME shader) and a soft halo on each lantern painted in the face
## art. Nodes join "hub_lamp" so the hub bake (hub_props.lamp_glow) adds a warm pool under each one.

const TorchBill := preload("res://scripts/graphics/torch_bill.gd")
## Lantern texels per face art: layout_spec.gd HALL/WING "lamps". Sizes and draw order: Spec.LAMP, Spec.DRAW.
const Spec := preload("res://scripts/world/camp/layout_spec.gd")
const HALO := """
shader_type spatial;
render_mode unshaded, cull_disabled, blend_add, depth_draw_never;
void fragment() {
	float d = length(UV * 2.0 - 1.0);
	float f = 0.9 + 0.1 * sin(TIME * 9.0);
	ALBEDO = vec3(1.0, 0.62, 0.24);
	ALPHA = (1.0 - smoothstep(0.0, 1.0, d)) * 0.42 * f;
}
"""

## hang (art texel rect, optional): the lantern sits under the awning, so a cutout of it hangs from the awning hem
## (hem: body-local y, z; art x) with the flame and halo on its glass; the "hub_lamp" pool node stays at the painted lamp.
static func on_face(spr: Sprite3D, crop_top: float, pts: Array, hang := Rect2(), hem := Vector3.ZERO) -> void:
	if spr == null or spr.texture == null:
		return
	var tw: float = float(spr.texture.get_width())
	var th: float = float(spr.texture.get_height())
	var cut: float = th * crop_top
	var rh: float = th - cut
	var ps: float = spr.pixel_size
	var seed: float = 0.0
	for p: Vector2 in pts:
		var at := Vector3((p.x - tw * 0.5) * ps, (rh * 0.5 - (p.y - cut)) * ps, 0.02)
		var root := Node3D.new()
		root.position = at
		root.add_to_group("hub_lamp")
		spr.add_child(root)
		var lit: Node3D = root
		if hang.size != Vector2.ZERO:
			lit = _hung(spr, hang, p, hem)
		lit.add_child(_quad(TorchBill.FLAME, Spec.LAMP["flame"], seed))
		lit.add_child(_quad(HALO, Vector2.ONE * float(Spec.LAMP["halo"]), seed))
		seed += 1.7

## The lantern cutout (dark iron and the glass box of the art rect; wall pixels cleared) hung top-first from the hem,
## a little in front of it. Returns the node at its glass (p) for the flame and halo.
static func _hung(spr: Sprite3D, r: Rect2, p: Vector2, hem: Vector3) -> Node3D:
	var ps: float = spr.pixel_size
	var img: Image = spr.texture.get_image().get_region(Rect2i(r))
	img.convert(Image.FORMAT_RGBA8)
	var glass := Rect2(p.x - r.position.x - 6.0, p.y - r.position.y - 7.0, 12.0, 14.0)
	for y in img.get_height():
		for x in img.get_width():
			var c: Color = img.get_pixel(x, y)
			if c.get_luminance() >= 0.44 and not glass.has_point(Vector2(x, y)):
				img.set_pixel(x, y, Color(0, 0, 0, 0))
	var lamp := Node3D.new()
	var tw: float = float(spr.texture.get_width())
	lamp.position = Vector3((hem.z - tw * 0.5) * ps, hem.x - spr.position.y - (p.y - r.position.y) * ps, hem.y + 0.03 - spr.position.z)
	spr.add_child(lamp)
	var cut := Sprite3D.new()
	cut.texture = ImageTexture.create_from_image(img)
	cut.pixel_size = ps
	cut.shaded = false
	cut.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	cut.alpha_cut = SpriteBase3D.ALPHA_CUT_DISCARD
	cut.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	cut.position = Vector3((r.get_center().x - p.x) * ps, (p.y - r.get_center().y) * ps, -0.01)
	lamp.add_child(cut)
	return lamp

static func _quad(code: String, size: Vector2, seed: float) -> MeshInstance3D:
	var q := QuadMesh.new()
	q.size = size
	var sh := Shader.new()
	sh.code = code
	var mat := ShaderMaterial.new()
	mat.shader = sh
	mat.render_priority = Spec.DRAW["lamp"]
	if code == TorchBill.FLAME:
		mat.set_shader_parameter("flame_seed", seed)
	var mi := MeshInstance3D.new()
	mi.mesh = q
	mi.material_override = mat
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return mi
