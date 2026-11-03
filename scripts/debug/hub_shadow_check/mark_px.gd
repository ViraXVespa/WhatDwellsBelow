extends Object

## Rendered sun mark in full building shade (no double shadow): the flow puts the player in a building shadow (9, 9),
## then the frame is drawn with the sun mark shown and hidden (force_draw). Pixels the mark darkens by more than DIFF
## must be under MAX_PX. run("", true) in open sun must show the mark (MIN_SUN_PX). plant "ignore" drops the cancel (the mark drawn over
## the building shade, as Vira saw) and must FAIL.

const Hulls := preload("res://scripts/graphics/light_rt/hub_hulls.gd")
const LightRt := preload("res://scripts/graphics/light_rt.gd")
const DIFF := 0.04
const MAX_PX := 6
const MIN_SUN_PX := 40

static var last := ""

static func run(plant: String = "", want_sun := false) -> String:
	var tree: SceneTree = Engine.get_main_loop() as SceneTree
	var player: Node3D = tree.get_first_node_in_group("player") as Node3D
	var lit: Node = player.get_node_or_null("ActorLit") if player != null else null
	if lit == null:
		return "no_player_lit"
	var q := Vector2(player.global_position.x, player.global_position.z)
	var c: Color = LightRt.sample_xz(q)
	var sun: float = Hulls.sun_at(q, maxf(c.r, maxf(c.g, c.b)))
	if sun != (1.0 if want_sun else 0.0):
		return "spot %s not in %s" % [q, "sun" if want_sun else "full shade"]
	var n: int = _px(lit, player, plant)
	last = "at=%s bake=%.2f px=%d" % [q, maxf(c.r, maxf(c.g, c.b)), n]
	print("MARK_PX ", plant, " sun=", want_sun, " ", last)
	if want_sun:
		return "" if n >= MIN_SUN_PX else "sun_mark=%dpx" % n
	return "" if n <= MAX_PX else "double=%dpx" % n

static func _px(lit: Node, player: Node3D, plant: String) -> int:
	lit._process(0.016)
	var m0: MeshInstance3D = lit.marks[0]
	var mat: ShaderMaterial = m0.material_override as ShaderMaterial
	if plant == "ignore" and mat != null:
		mat.set_shader_parameter("sun_cancel", 0.0)
	var vis: bool = m0.visible
	RenderingServer.force_draw(false)
	var shown: Image = player.get_viewport().get_texture().get_image()
	m0.visible = false  # the sun mark only; lantern marks are real in the shade
	RenderingServer.force_draw(false)
	var hidden: Image = player.get_viewport().get_texture().get_image()
	m0.visible = vis
	if mat != null:
		mat.set_shader_parameter("sun_cancel", 1.0)
	var n := 0
	for y in range(0, shown.get_height(), 2):
		for x in range(0, shown.get_width(), 2):
			if hidden.get_pixel(x, y).get_luminance() - shown.get_pixel(x, y).get_luminance() > DIFF:
				n += 1
	return n
