extends Object

## Guild lamps: a flickering flame (torch_bill's FLAME shader) and a soft halo on each lantern painted in the face
## art. Nodes join "hub_lamp" so the hub bake (hub_props.lamp_glow) adds a warm pool under each one.

const TorchBill := preload("res://scripts/graphics/torch_bill.gd")
## Lantern flame centres in guild.png texels (320x180 sheet).
const GUILD_LAMPS: Array[Vector2] = [Vector2(99.0, 95.0), Vector2(219.0, 95.0)]
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

static func on_face(spr: Sprite3D, crop_top: float, pts: Array[Vector2]) -> void:
	if spr == null or spr.texture == null:
		return
	var tw: float = float(spr.texture.get_width())
	var th: float = float(spr.texture.get_height())
	var cut: float = th * crop_top
	var rh: float = th - cut
	var ps: float = spr.pixel_size
	var seed: float = 0.0
	for p in pts:
		var at := Vector3((p.x - tw * 0.5) * ps, (rh * 0.5 - (p.y - cut)) * ps, 0.02)
		var root := Node3D.new()
		root.position = at
		root.add_to_group("hub_lamp")
		spr.add_child(root)
		root.add_child(_quad(TorchBill.FLAME, Vector2(0.16, 0.28), seed))
		root.add_child(_quad(HALO, Vector2(1.2, 1.2), seed))
		seed += 1.7

static func _quad(code: String, size: Vector2, seed: float) -> MeshInstance3D:
	var q := QuadMesh.new()
	q.size = size
	var sh := Shader.new()
	sh.code = code
	var mat := ShaderMaterial.new()
	mat.shader = sh
	mat.render_priority = 2
	if code == TorchBill.FLAME:
		mat.set_shader_parameter("flame_seed", seed)
	var mi := MeshInstance3D.new()
	mi.mesh = q
	mi.material_override = mat
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return mi
