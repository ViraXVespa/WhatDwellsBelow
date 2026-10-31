extends RefCounted

## Hub prop shadow check (`shots.py flow --flow camp-prop-shadows` runs it in a real renderer):
## every yard prop with the player's hard mark (camp_build.gd MARKED) must lay its sun mark on the ground, on the
## sun-away side of its feet (K.SUN_AWAY), and the mark seen through the play camera must not sit on the prop's own
## visible face (its opaque sprite rect on screen). Flow: assert script:debug/hub_shadow_check.bad equals "".

const K := preload("res://scripts/graphics/actor_lit/lit_k.gd")
const T := preload("res://scripts/data/tunables.gd")
const Soles := preload("res://scripts/graphics/actor_lit/soles.gd")
const Build := preload("res://scripts/world/camp_build.gd")
## Mark centre at least this far (m) along SUN_AWAY from the feet; at most this share of mark samples on the face.
const MIN_AWAY := 0.12
const MAX_ON_FACE := 0.2

## "" when every marked prop passes, else "kind:rule numbers" per failing prop; report adds every prop's away and on_face share.
var bad: String:
	get:
		return faults((Engine.get_main_loop() as SceneTree).get_nodes_in_group("interact"))
## Every prop's numbers (kind away on_face) for the flow log.
var report: String:
	get:
		_rows.clear()
		faults((Engine.get_main_loop() as SceneTree).get_nodes_in_group("interact"))
		return " ".join(_rows)

## Planted fault: the dumpster sprite grown 3x so its face covers its own mark; must report on_face.
var plant: String:
	get:
		for n in (Engine.get_main_loop() as SceneTree).get_nodes_in_group("interact"):
			if str(n.get("kind")) == "dumpster":
				var spr: Sprite3D = n.get("spr") as Sprite3D
				var was: Vector3 = spr.scale
				spr.scale = was * 3.0
				var got: String = faults([n])
				spr.scale = was
				return "caught" if got.contains("dumpster:on_face") else "missed " + got
		return "missing"

## Shadow-mark matrix (hub_shadow_check/mark_matrix.gd): "" when every frame's feet and mask pass. plant_matrix
## runs the three planted faults (offset pin, glued raised foot, stray chunk); each must be reported.
var matrix: String:
	get:
		return load("res://scripts/debug/hub_shadow_check/mark_matrix.gd").run()
var plant_matrix: String:
	get:
		var M: GDScript = load("res://scripts/debug/hub_shadow_check/mark_matrix.gd")
		var miss: PackedStringArray = PackedStringArray()
		for p: String in ["offset", "glue", "chunk"]:
			if M.run(p) == "":
				miss.append(p)
		return "caught" if miss.is_empty() else "missed " + ",".join(miss)

static var _rows: PackedStringArray = PackedStringArray()

static func faults(props: Array) -> String:
	var out: PackedStringArray = PackedStringArray()
	var seen: PackedStringArray = PackedStringArray()
	for n in props:
		var kind: String = str(n.get("kind"))
		if not Build.MARKED.has(kind) or seen.has(kind):
			continue
		seen.append(kind)
		var spr: Sprite3D = n.get("spr") as Sprite3D
		var lit: Node = (n as Node).get_node_or_null("ActorLit")
		var cam: Camera3D = (n as Node).get_viewport().get_camera_3d()
		var why: String = "no_mark"
		if spr != null and lit != null and cam != null:
			why = prop_fault(n as Node3D, spr, (lit.get("marks") as Array)[0] as MeshInstance3D, cam)
		if why != "":
			_rows.append("%s FAIL %s" % [kind, why])
		if why != "":
			out.append(kind + ":" + why)
	for k: String in Build.MARKED:
		if not seen.has(k):
			out.append(k + ":missing")
	return ",".join(out)

## "" when the mark is fine, else the first rule it breaks (and its numbers).
static func prop_fault(prop: Node3D, spr: Sprite3D, mark: MeshInstance3D, cam: Camera3D) -> String:
	if mark == null or not mark.visible or mark.mesh == null:
		return "hidden"
	var box: AABB = mark.global_transform * mark.mesh.get_aabb()
	if box.size.y > 0.05 or absf(box.position.y - T.FLOOR_Y) > 0.05:
		return "off_ground y=%.2f" % box.position.y
	var feet := Vector2(prop.global_position.x, prop.global_position.z)
	var mid: Vector3 = box.get_center()
	var away: float = (Vector2(mid.x, mid.z) - feet).dot(K.SUN_AWAY)
	if away < MIN_AWAY:
		return "not_sun_side away=%.2f" % away
	var face: Rect2 = face_rect(spr, cam)
	var on: int = 0
	var all: int = 0
	var verts: PackedVector3Array = mark.mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]
	var xf: Transform3D = mark.global_transform
	for i in 11:
		for j in 11:
			var u: float = float(i) / 10.0
			var v: float = float(j) / 10.0
			var p: Vector3 = (xf * verts[0]).lerp(xf * verts[1], u).lerp((xf * verts[3]).lerp(xf * verts[2], u), v)
			all += 1
			if face.has_point(cam.unproject_position(p)):
				on += 1
	var share: float = float(on) / float(maxi(all, 1))
	_rows.append("%s away=%.2f on_face=%.2f" % [str(prop.get("kind")), away, share])
	if share > MAX_ON_FACE:
		return "on_face share=%.2f away=%.2f" % [share, away]
	return ""

## The sprite's opaque span (Soles) on screen.
static func face_rect(spr: Sprite3D, cam: Camera3D) -> Rect2:
	var span: Vector4 = Soles._span(spr.texture)
	var lb: AABB = spr.get_aabb()
	var x0: float = lerpf(lb.position.x, lb.end.x, span.x)
	var x1: float = lerpf(lb.position.x, lb.end.x, span.z)
	var y0: float = lerpf(lb.end.y, lb.position.y, span.w)
	var y1: float = lerpf(lb.end.y, lb.position.y, span.y)
	var xf: Transform3D = spr.global_transform
	var r := Rect2(cam.unproject_position(xf * Vector3(x0, y0, 0.0)), Vector2.ZERO)
	for c in [Vector3(x1, y0, 0.0), Vector3(x1, y1, 0.0), Vector3(x0, y1, 0.0)]:
		r = r.expand(cam.unproject_position(xf * c))
	return r

## wheels: the dumpster's live mark caster (ActorLit "raised") is a box on short wheel posts: the band between the
## box shadow and the ground holds >= 4 opaque runs split by clear columns, and that band is 1 row to MAX_BAND of
## the box height (wheels a few cm on a ~1.2 m box). plant_wheels scores the "stilts" caster (drawn wheel band
## kept under the full sprite), which must FAIL.
const MAX_BAND := 0.1
var wheels: String:
	get:
		return wheel_faults(false)
var plant_wheels: String:
	get:
		return "caught" if wheel_faults(true) != "" else "missed"

static func wheel_faults(plant: bool) -> String:
	for n in (Engine.get_main_loop() as SceneTree).get_nodes_in_group("interact"):
		if str(n.get("kind")) != "dumpster" or not n.has_node("ActorLit"):
			continue
		var tex: Texture2D = (n.get("spr") as Sprite3D).texture
		var img: Image = Soles._solid(tex, "stilts" if plant else str(n.get_node("ActorLit").get("solid"))).get_image()
		var used: Rect2i = img.get_used_rect()
		var sole: int = used.end.y - 1
		var body: int = Soles._body_end(img) - 1
		var band: int = sole - body
		var tall: int = body - used.position.y + 1
		var runs: int = 0
		var was: bool = false
		for x in img.get_width():
			var on: bool = img.get_pixel(x, mini(body + 1 + band / 2, sole)).a > 0.5
			if on and not was:
				runs += 1
			was = on
		var out: PackedStringArray = PackedStringArray()
		if runs < 4:
			out.append("wheel_runs=%d<4" % runs)
		if band < 1 or band > MAX_BAND * tall:
			out.append("band=%d rows of box %d (max %.0f)" % [band, tall, MAX_BAND * tall])
		return "" if out.is_empty() else "dumpster:" + " ".join(out)
	return "dumpster:missing"
