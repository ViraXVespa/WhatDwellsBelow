extends RefCounted

## Hub awning / window checks (camp-prop-shadows flow), measured from the live camera (orthographic, so the pitch,
## not the zoom, sets the result):
## - gap: per building, the awning hem's screen height above the face sprite's top edge (metres of screen and px).
##   Positive is a visible gap between the wall art and the awning; "" when every hem is at or below its face top.
## - window: the receptionist stands behind the counter: her visible bottom (Spec.RECEPTION_CUT) on the window's
##   counter line (Spec.RECEPTION_WINDOW bottom) and her head top in the opening's top third, x inside.
## plant_gap lifts one hem 3 cm, plant_window floats her 0.28 m up; both must FAIL.

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
		return window_faults(0.0)
var window_report: String:
	get:
		return window_faults(0.0, true)
var plant_window: String:
	get:
		return "caught" if window_faults(0.28) != "" else "missed"

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

static func window_faults(lift: float, report: bool = false) -> String:
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
	var h: float = img.get_height()
	var used: Rect2i = img.get_used_rect()
	var ps: float = spr.pixel_size
	var c: Vector3 = face.global_transform.inverse() * spr.global_position  # face-local metres
	var bot: float = c.y + lift + (0.5 - Spec.RECEPTION_CUT) * h * ps
	var top: float = c.y + lift + (h * 0.5 - used.position.y) * ps
	var x0: float = c.x + (used.position.x - img.get_width() * 0.5) * ps
	var x1: float = c.x + (used.end.x - img.get_width() * 0.5) * ps
	var fps: float = face.pixel_size
	var r: Rect2 = face.region_rect if face.region_enabled else Rect2(Vector2.ZERO, face.texture.get_size())
	var win: Rect2 = Spec.RECEPTION_WINDOW
	var sill: float = (r.position.y + r.size.y * 0.5 - win.end.y) * fps
	var lintel: float = (r.position.y + r.size.y * 0.5 - win.position.y) * fps
	var wx0: float = (win.position.x - r.size.x * 0.5) * fps
	var wx1: float = (win.end.x - r.size.x * 0.5) * fps
	var third: float = lintel - (lintel - sill) / 3.0
	if report:
		return "bottom=%.3f sill=%.3f head=%.3f top_third=[%.3f,%.3f] x=[%.3f,%.3f] win_x=[%.3f,%.3f]" % [bot, sill, top, third, lintel, x0, x1, wx0, wx1]
	var out: PackedStringArray = PackedStringArray()
	if absf(bot - sill) > 0.02:
		out.append("bottom=%.3f off counter %.3f" % [bot, sill])
	if top < third or top > lintel - 0.05:
		out.append("head=%.3f not in top third [%.3f,%.3f]" % [top, third, lintel - 0.05])
	if x0 < wx0 - TOL or x1 > wx1 + TOL:
		out.append("x=[%.3f,%.3f] win=[%.3f,%.3f]" % [x0, x1, wx0, wx1])
	return " ".join(out)

## board: the reception window's top board (Spec.RECEPTION_BOARD_TOP, face-art px row) sits right under the wing
## awning's lowest screen edge from the play camera: |gap| <= BOARD_TOL px. plant_board moves the board 6 rows down.
const BOARD_TOL := 1.5
var board: String:
	get:
		return board_fault(0.0)
var plant_board: String:
	get:
		return "caught" if board_fault(6.0) != "" else "missed"

static func board_fault(shift: float) -> String:
	var cam: Camera3D = _cam()
	var bs: Array = []
	_bodies((Engine.get_main_loop() as SceneTree).root, bs)
	for b: Node3D in bs:
		var f: Sprite3D = _face(b)
		if cam == null or f == null or not f.texture.resource_path.contains("guild_reception"):
			continue
		var up: Vector3 = cam.global_transform.basis.y
		var aw: MeshInstance3D = b.get_node("Awning")
		var ab: AABB = aw.mesh.get_aabb()
		var low: float = INF
		for i in 8:
			low = minf(low, up.dot(aw.global_transform * ab.get_endpoint(i)))
		var r: Rect2 = f.region_rect if f.region_enabled else Rect2(Vector2.ZERO, f.texture.get_size())
		var row: float = Spec.RECEPTION_BOARD_TOP + shift
		var board_up: float = up.dot(f.global_transform * Vector3(0.0, (r.position.y + r.size.y * 0.5 - row) * f.pixel_size, 0.0))
		var px: float = (board_up - low) * float(cam.get_viewport().get_visible_rect().size.y) / maxf(cam.size, 0.001)
		var at: float = row + (board_up - low) / (up.dot(f.global_transform.basis.y) * f.pixel_size)
		return "" if absf(px) <= BOARD_TOL else "board gap=%.1fpx (awning bottom at art row %.1f, board %.1f)" % [px, at, row]
	return "no reception face"

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

## door: each guild's FrontFaceCollider spans the player's body height (ground to the capsule top) and its front lies
## ahead of the face sprite, so the player stops in front of the face art at the door instead of on the wall box
## behind it (hidden by the face). plant_door lifts the collider by half its height (the old top-centred bug).
var door: String:
	get:
		return door_faults(0.0)
var plant_door: String:
	get:
		return "caught" if door_faults(0.5).contains("door") else "missed"

static func door_faults(lift: float) -> String:
	var t := Engine.get_main_loop() as SceneTree
	var pl := t.get_first_node_in_group("player") as Node3D
	var top: float = 1.5
	for c in pl.find_children("*", "CollisionShape3D", true, false):
		var sh: Shape3D = (c as CollisionShape3D).shape
		if sh is BoxShape3D:
			top = (c as Node3D).position.y + (sh as BoxShape3D).size.y * 0.5
	var out: PackedStringArray = PackedStringArray()
	var n: int = 0
	for c in t.root.find_children("FrontFaceCollider", "CollisionShape3D", true, false):
		var col := c as CollisionShape3D
		var size: Vector3 = (col.shape as BoxShape3D).size
		var p: Vector3 = col.global_position + Vector3(0.0, size.y * lift, 0.0)
		var face_z: float = -INF
		var big: int = 0
		for s in col.get_parent().get_children():
			var sp := s as Sprite3D
			if sp != null and sp.texture != null and sp.texture.get_width() > big:  # the face art, not a lamp
				big = sp.texture.get_width()
				face_z = sp.global_position.z
		n += 1
		if p.y - size.y * 0.5 > 0.05 or p.y + size.y * 0.5 < top or p.z + size.z * 0.5 < face_z - 0.005:
			out.append("%s:door y=[%.2f,%.2f] front=%.2f face=%.2f" % [col.get_parent().name, p.y - size.y * 0.5, p.y + size.y * 0.5, p.z + size.z * 0.5, face_z])
	if n < 2:
		out.append("door_colliders=%d<2" % n)
	return " ".join(out)
