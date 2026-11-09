extends Object

## Rendered-pixel foot check (what the eye sees): the player's live frame drawn twice with RenderingServer.force_draw,
## marks hidden then shown; the diff is the mark. Per boot column (each sole texel column of both feet), walk down the
## screen from the boot's lowest opaque texel; daylight rows before the first mark pixel are the gap. Any grounded boot
## column with gap > MAX_PX fails. plant "flat" treats the higher standing foot as raised (the one-foot-off Vira saw).

const ActorLit := preload("res://scripts/graphics/actor_lit.gd")
const Soles := preload("res://scripts/graphics/actor_lit/soles.gd")
const K := preload("res://scripts/graphics/actor_lit/lit_k.gd")
const MAX_PX := 1
const DIFF := 0.04
const SPAN := 4  # texel columns each side of a foot's lowest pixel

static var last := ""

static func run(plant: String = "") -> String:
	var tree: SceneTree = Engine.get_main_loop() as SceneTree
	var player: Node = tree.get_first_node_in_group("player")
	var lit: Node = _lit_of(player)
	if lit == null or lit.spr == null:
		return "no_player_lit"
	ActorLit.plant_flat = plant == "flat"
	var cam: Camera3D = lit.spr.get_viewport().get_camera_3d()
	lit._process(0.0)
	var shown: Image = _draw(lit, true)
	var hidden: Image = _draw(lit, false)
	ActorLit.plant_flat = false
	lit._process(0.0)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://_logs/feet-px"))
	shown.save_png("res://_logs/feet-px/shown_%s.png" % plant)
	hidden.save_png("res://_logs/feet-px/hidden_%s.png" % plant)
	var tex: Texture2D = lit.spr.texture
	var img: Image = tex.get_image()
	if img.is_compressed():
		img.decompress()
	var s: Vector4 = Soles._soles(tex)
	var out: PackedStringArray = PackedStringArray()
	var gaps: PackedStringArray = PackedStringArray()
	for f in 2:
		var fx: int = int(s.x if f == 0 else s.z)
		var worst: int = 0
		for tx in range(fx - SPAN, fx + SPAN + 1):
			var ty: int = _low(img, tx)
			if ty < 0:
				continue
			var p: Vector2 = cam.unproject_position(_world(lit.spr, tx + 0.5, ty + 1.0, img.get_width(), img.get_height()))
			worst = maxi(worst, _gap(shown, hidden, p))
		var name: String = "L" if f == 0 else "R"
		gaps.append("%s=%dpx" % [name, worst])
		if worst > MAX_PX:
			out.append("%s_gap=%dpx" % [name, worst])
	last = " ".join(gaps)
	print("FEET_PX ", plant, " ", last)
	return " ".join(out)

static func _lit_of(n: Node) -> Node:
	if n == null:
		return null
	for c: Node in n.find_children("*", "", true, false):
		if c.get_script() == ActorLit:
			return c
	return null

static func _draw(lit: Node, marks_on: bool) -> Image:
	if not marks_on:
		for m in lit.marks:
			var mesh_node: MeshInstance3D = m as MeshInstance3D
			if mesh_node == null:
				continue
			mesh_node.visible = false
	RenderingServer.force_draw(false)
	return lit.spr.get_viewport().get_texture().get_image()

## Lowest opaque texel row of a column, -1 if none.
static func _low(img: Image, tx: int) -> int:
	if tx < 0 or tx >= img.get_width():
		return -1
	for ty in range(img.get_height() - 1, -1, -1):
		if img.get_pixel(tx, ty).a >= 0.5:
			return ty
	return -1

static func _world(spr: Sprite3D, tx: float, ty: float, tw: float, th: float) -> Vector3:
	var ox: float = spr.offset.x - (tw * 0.5 if spr.centered else 0.0)
	var oy: float = spr.offset.y - (th * 0.5 if spr.centered else 0.0)
	var axis: Vector3 = spr.get_viewport().get_camera_3d().global_transform.basis.x
	var g: float = (tw - tx) if spr.flip_h else tx
	return spr.global_position + axis * (ox + g) * spr.pixel_size + Vector3(0.0, (oy + th - ty) * spr.pixel_size, 0.0)

## Daylight rows straight below p (the boot's bottom edge) before the first mark pixel; 0 if the mark is right there.
static func _gap(shown: Image, hidden: Image, p: Vector2) -> int:
	var x: int = clampi(int(p.x), 0, shown.get_width() - 1)
	var y0: int = int(p.y)
	for d in 64:
		var y: int = y0 + d
		if y < 0 or y >= shown.get_height():
			break
		var a: Color = shown.get_pixel(x, y)
		var b: Color = hidden.get_pixel(x, y)
		if b.get_luminance() - a.get_luminance() > DIFF:
			return d
	return 64
