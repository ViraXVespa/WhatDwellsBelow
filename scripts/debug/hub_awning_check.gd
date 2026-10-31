extends RefCounted

## Hub awning / window checks (camp-prop-shadows flow), measured from the live camera (orthographic, so the pitch,
## not the zoom, sets the result):
## - gap: per building, the awning hem's screen height above the face sprite's top edge (metres of screen and px).
##   Positive is a visible gap between the wall art and the awning; "" when every hem is at or below its face top.
## - window: the receptionist's visible bust (opaque rows above the bust cut) inside the reception window opening
##   (Spec.RECEPTION_WINDOW, face-art px), "" when inside.
## plant_gap lifts one hem 3 cm, plant_window grows the bust 20 %; both must FAIL.

const Spec := preload("res://scripts/world/camp/layout_spec.gd")
const TOL := 0.004

var gap: String:
	get:
		return gap_faults(0.0)
var plant_gap: String:
	get:
		return "caught" if gap_faults(0.03).contains("gap") else "missed"
var gap_report: String:
	get:
		return " ".join(_rows(0.0).map(func(r): return "%s=%+.3fm/%+.1fpx" % r))
var window: String:
	get:
		return window_faults(1.0)
var plant_window: String:
	get:
		return "caught" if window_faults(1.2) != "" else "missed"

static func _cam() -> Camera3D:
	return (Engine.get_main_loop() as SceneTree).root.get_viewport().get_camera_3d()

static func _bodies(n: Node, out: Array) -> void:
	if n.get_node_or_null("Awning") is MeshInstance3D:
		out.append(n)
	for c in n.get_children():
		_bodies(c, out)

static func _face(body: Node) -> Sprite3D:
	for c in body.get_children():
		if c is Sprite3D and (c as Sprite3D).material_override is ShaderMaterial \
				and (c as Sprite3D).material_override.get_shader_parameter("ahead") != null:
			return c
	return null

## [name, gap metres, gap px] per awning body. Gap = screen-up of the hem front edge minus the face top edge.
static func _rows(lift: float) -> Array:
	var cam: Camera3D = _cam()
	var out: Array = []
	var bs: Array = []
	_bodies((Engine.get_main_loop() as SceneTree).root, bs)
	if cam == null:
		return out
	var up: Vector3 = cam.global_transform.basis.y
	var px_per_m: float = float(cam.get_viewport().get_visible_rect().size.y) / maxf(cam.size, 0.001)
	for b: Node3D in bs:
		var face: Sprite3D = _face(b)
		if face == null:
			continue
		var aw: MeshInstance3D = b.get_node("Awning")
		var ab: AABB = aw.mesh.get_aabb()
		var hem: Vector3 = aw.global_transform * Vector3(ab.get_center().x, ab.position.y, ab.end.z)
		var fb: AABB = face.get_aabb()
		var top: Vector3 = face.global_transform * Vector3(fb.get_center().x, fb.end.y, 0.0)
		var g: float = up.dot(hem - top) + (lift if out.is_empty() else 0.0)
		out.append([str(b.name), g, g * px_per_m])
	return out

static func gap_faults(lift: float) -> String:
	var out: PackedStringArray = PackedStringArray()
	var rows: Array = _rows(lift)
	if rows.size() < 2:
		out.append("awnings=%d<2" % rows.size())
	for r in rows:
		if float(r[1]) > TOL:
			out.append("%s:gap=%.3fm" % [r[0], r[1]])
	return " ".join(out)

static func window_faults(grow: float) -> String:
	var root: Node = (Engine.get_main_loop() as SceneTree).root
	var spr: Sprite3D = null
	for n in root.get_tree().get_nodes_in_group("interact"):
		if str(n.get("kind")) == "receptionist":
			spr = n.get("spr") as Sprite3D
	var face: Sprite3D = null
	var bs: Array = []
	_bodies(root, bs)
	for b in bs:
		var f: Sprite3D = _face(b)
		if f != null and f.texture.resource_path.contains("guild_reception"):
			face = f
	if spr == null or face == null:
		return "missing rec=%s face=%s" % [spr != null, face != null]
	var img: Image = spr.texture.get_image()
	if img.is_compressed():
		img.decompress()
	var bust: Rect2i = img.get_region(Rect2i(0, 0, img.get_width(), img.get_height() / 2)).get_used_rect()
	var ps: float = spr.pixel_size * grow
	var c: Vector3 = face.global_transform.inverse() * spr.global_position  # face-local metres
	var w0: float = img.get_width() * 0.5
	var h0: float = img.get_height() * 0.5
	var lo := Vector2(c.x + (bust.position.x - w0) * ps, c.y + (h0 - bust.end.y) * ps)
	var hi := Vector2(c.x + (bust.end.x - w0) * ps, c.y + (h0 - bust.position.y) * ps)
	var fps: float = face.pixel_size
	var r: Rect2 = face.region_rect if face.region_enabled else Rect2(Vector2.ZERO, face.texture.get_size())
	var win: Rect2 = Spec.RECEPTION_WINDOW
	var wlo := Vector2((win.position.x - r.size.x * 0.5) * fps, (r.position.y + r.size.y * 0.5 - win.end.y) * fps)
	var whi := Vector2((win.end.x - r.size.x * 0.5) * fps, (r.position.y + r.size.y * 0.5 - win.position.y) * fps)
	var out: PackedStringArray = PackedStringArray()
	if lo.x < wlo.x - TOL or hi.x > whi.x + TOL:
		out.append("x=[%.3f,%.3f] win=[%.3f,%.3f]" % [lo.x, hi.x, wlo.x, whi.x])
	if lo.y < wlo.y - TOL or hi.y > whi.y + TOL:
		out.append("y=[%.3f,%.3f] win=[%.3f,%.3f]" % [lo.y, hi.y, wlo.y, whi.y])
	return " ".join(out)

## Cloth light: every awning and the stall tarp is lit like the faces (wrap shader face_light 1, bound to the hub
## light map). plant_cloth turns one off and must FAIL.
const LightRt := preload("res://scripts/graphics/light_rt.gd")
var cloth: String:
	get:
		return cloth_faults(cloths(), -1)
var plant_cloth: String:
	get:
		return "caught" if cloth_faults(cloths(), 0).contains("unlit") else "missed"

static func cloths() -> Array:
	var out: Array = []
	_walk_cloth((Engine.get_main_loop() as SceneTree).root, out)
	return out

static func _walk_cloth(n: Node, out: Array) -> void:
	if n is MeshInstance3D and (n.name == "Awning" or n.name == "StallPitch"):
		out.append(n)
	for c in n.get_children():
		_walk_cloth(c, out)

static func cloth_faults(cs: Array, off_i: int) -> String:
	var out: PackedStringArray = PackedStringArray()
	if cs.size() < 3:
		out.append("cloths=%d<3" % cs.size())
	for i in cs.size():
		var m: ShaderMaterial = (cs[i] as MeshInstance3D).material_override as ShaderMaterial
		var who: String = "%s/%s" % [cs[i].get_parent().name, cs[i].name]
		var on: bool = m != null and float(m.get_shader_parameter("face_light")) > 0.5 and i != off_i
		var t: Texture2D = m.get_shader_parameter("light_tex") if m != null else null
		if not on or t != LightRt.tex or t == null or t.get_width() < 2:
			out.append("%s:unlit" % who)
	return " ".join(out)
