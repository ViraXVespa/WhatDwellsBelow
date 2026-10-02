extends Object

## Camp build shared leaf helpers: box/face emit, stall parts.

const Roof := preload("res://scripts/world/camp_build/roof.gd")

static func box(host: Node3D, pos: Vector3, box_size: Vector3, col: Color) -> StaticBody3D:
	return Roof.box(host, pos, box_size, col)

static func face(
	body: Node3D, box_size: Vector3, tex: String, x_off: float, face_w: float, crop_top: float = 0.0
) -> void:
	if not ResourceLoader.exists(tex):
		return
	var spr := Sprite3D.new()
	spr.texture = load(tex)
	spr.centered = true
	spr.shaded = false
	spr.alpha_cut = SpriteBase3D.ALPHA_CUT_OPAQUE_PREPASS
	spr.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	var tw := float(maxi(1, spr.texture.get_width()))
	var th := float(maxi(1, spr.texture.get_height()))
	var cap: float = clampf(crop_top, 0.0, 0.6)
	var rh: float = maxf(th * (1.0 - cap), 1.0)
	if cap > 0.01:
		spr.region_enabled = true
		spr.region_rect = Rect2(0.0, th * cap, tw, rh)
	var fw: float = maxf(face_w, 0.2)
	spr.pixel_size = fw / tw
	var sh: float = spr.pixel_size * rh
	spr.position = Vector3(x_off, -box_size.y * 0.5 + sh * 0.5 - 0.06, box_size.z * 0.5 + 0.01)
	body.add_child(spr)
static func face_height(tex: String, face_w: float) -> float:
	if not ResourceLoader.exists(tex):
		return 3.2
	var img: Texture2D = load(tex)
	var tw: float = float(maxi(1, img.get_width()))
	var th: float = float(maxi(1, img.get_height()))
	return maxf(face_w * th / tw, 1.2)

static func seat(body: StaticBody3D, box_size: Vector3, tex: String) -> Vector3:
	var h: float = face_height(tex, box_size.x) * 0.78
	body.position.y = h * 0.5
	return Vector3(box_size.x, h, box_size.z)
static func _slide(body: StaticBody3D, box_size: Vector3) -> void:
	var old: Node = body.get_node_or_null("WallHit")
	if old != null:
		old.queue_free()
	var shape := CollisionShape3D.new()
	shape.name = "Slide"
	var block := BoxShape3D.new()
	block.size = Vector3(maxf(box_size.x - 0.12, 0.4), box_size.y, maxf(box_size.z - 0.12, 0.4))
	shape.shape = block
	body.add_child(shape)

static func _counter(body: StaticBody3D, box_size: Vector3) -> void:
	var shape := CollisionShape3D.new()
	shape.name = "StallCounter"
	var block := BoxShape3D.new()
	block.size = Vector3(box_size.x * 0.72, 1.05, box_size.z * 0.46)
	shape.shape = block
	shape.position = Vector3(0.0, 0.52, 0.0)
	body.add_child(shape)

static func _stall_walls(body: StaticBody3D, box_size: Vector3) -> void:
	var foot: float = -box_size.y * 0.5
	var wall_h: float = box_size.y * 0.72
	var mid_y: float = foot + wall_h * 0.5
	var specs: Array = [
		Vector3(0.0, mid_y, -box_size.z * 0.46),
		Vector3(box_size.x * 0.46, mid_y, 0.0),
		Vector3(-box_size.x * 0.46, mid_y, 0.0),
	]
	var sizes: Array = [
		Vector3(box_size.x * 0.9, wall_h, 0.28),
		Vector3(0.28, wall_h, box_size.z * 0.8),
		Vector3(0.28, wall_h, box_size.z * 0.8),
	]
	var i: int = 0
	while i < specs.size():
		var shape := CollisionShape3D.new()
		shape.name = "StallWall"
		var block := BoxShape3D.new()
		block.size = sizes[i]
		shape.shape = block
		shape.position = specs[i]
		body.add_child(shape)
		i += 1
static func _blob(parent: Node3D, at: Vector3) -> void:
	var mesh := MeshInstance3D.new()
	mesh.name = "Blob"
	var plane := PlaneMesh.new()
	plane.size = Vector2(0.9, 0.55)
	mesh.mesh = plane
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.albedo_color = Color(0.12, 0.08, 0.06, 0.45)
	mat.no_depth_test = false
	mat.render_priority = -2
	mesh.material_override = mat
	mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mesh.position = at + Vector3(-0.28, 0.04, 0.42)
	mesh.rotation_degrees = Vector3(-90.0, 0.0, 18.0)
	parent.add_child(mesh)
