extends RefCounted

## Flyer mark matrix (hub_shadow_check.fly_matrix, camp-mark-matrix flow): every roster "fly" enemy x 8 facings x
## altitudes, laid through a live ActorLit stand-in (air_force). Each case: the mark is drawn, detached on screen
## (gap > MIN_GAP cells, growing with altitude), under the body (centre shifted along the light by 0.4-1.4 x lift,
## lateral within half the mark plus a cell), size and darkness fall with altitude; an erratic run (random facing,
## altitude, flip each frame) must keep the mark on this frame's spot (no hang). plant: "glued" (air off) and
## "hang" (one frame not laid) must fail. bench(n): usec per frame for n bats, air off vs on.

const K := preload("res://scripts/graphics/actor_lit/lit_k.gd")
const T := preload("res://scripts/data/tunables.gd")
const Soles := preload("res://scripts/graphics/actor_lit/soles.gd")
const Geo := preload("res://scripts/graphics/actor_lit/lit_geo.gd")
const ActorLit := preload("res://scripts/graphics/actor_lit.gd")
const BillSpr := preload("res://scripts/world/billboard_spr.gd")
const Roster := preload("res://scripts/combat/roster.gd")
const CELL := 1.0 / 32.0
const MIN_GAP := 0.5
const ALTS := [0.25, 0.5, 0.9]
const FACES := ["down", "down_left", "left", "up_left", "up", "up_right", "right", "down_right"]
const SIZE := 1.15

static var rows: PackedStringArray = PackedStringArray()

static func flyers() -> Array[String]:
	var out: Array[String] = []
	for k: String in DirAccess.get_directories_at("res://assets/sprites/enemies/"):
		if str(Roster._all().get(k, {}).get("move", "")) == "fly":
			out.append(k)
	return out

static func stand_in(at: Vector3, kind: String, face: String) -> Node3D:
	var tree := Engine.get_main_loop() as SceneTree
	var body := Node3D.new()
	body.name = "FlyStandIn"
	tree.current_scene.add_child(body)
	body.global_position = at
	var spr: Sprite3D = BillSpr.bare(1)
	body.add_child(spr)
	ActorLit.bind(body, spr)
	_face(body, kind, face, 0.5)
	var lit: Node = body.get_node("ActorLit")
	lit.set("air_force", true)
	return body

static func _face(body: Node3D, kind: String, face: String, alt: float) -> void:
	var spr: Sprite3D = body.get_child(0) as Sprite3D
	var tex: Texture2D = load("res://assets/sprites/enemies/%s/idle_%s.png" % [kind, face])
	spr.texture = tex
	spr.pixel_size = SIZE / float(maxi(1, tex.get_height()))
	spr.position.y = SIZE * 0.48 + alt

## One laid frame: [ok, gap_cells, along_m, lateral_m, scale, alpha, lift, why].
static func probe(body: Node3D, cam: Camera3D, lay: bool = true) -> Dictionary:
	var lit: Node = body.get_node("ActorLit")
	if lay:
		lit._process(1.0 / 60.0)
	var m: MeshInstance3D = lit.marks[0]
	var out := {"why": ""}
	if not m.visible or m.mesh == null:
		out.why = "hidden"
		return out
	var spr: Sprite3D = lit.spr
	var tex: Texture2D = spr.texture
	var s: Vector4 = Soles._soles(tex)
	var sole: Vector3 = Geo._sole_world(lit, (s.x + s.z) * 0.5, maxf(s.y, s.w), tex.get_width(), tex.get_height())
	var p: Vector3 = body.global_position
	var c0: Vector3 = Vector3(p.x, T.FLOOR_Y, p.z)
	var cell: float = cam.unproject_position(c0).distance_to(cam.unproject_position(c0 + Vector3(CELL, 0.0, 0.0)))
	var box: AABB = m.global_transform * m.mesh.get_aabb()
	var top: float = INF
	for i in 8:
		top = minf(top, cam.unproject_position(box.get_endpoint(i) * Vector3(1, 0, 1)).y)
	var dir: Vector2 = lit._biased(lit._away_at[0])
	var c: Vector3 = box.get_center()
	var off: Vector2 = Vector2(c.x - p.x, c.z - p.z)
	out.gap = (top - cam.unproject_position(sole).y) / maxf(cell, 0.01)
	out.along = off.dot(dir)
	out.lateral = absf(off.dot(Vector2(-dir.y, dir.x)))
	out.half = maxf(box.size.x, box.size.z) * 0.5
	out.scale = m.global_transform.basis.x.length()
	out.alpha = (m.material_override as ShaderMaterial).get_shader_parameter("shade").a
	out.lift = float(lit.get("lift"))
	var want: Vector3 = Vector3(p.x, T.FLOOR_Y, p.z) + Vector3(dir.x, 0.0, dir.y) * Geo._reach(out.lift, lit._stretch_at[0], lit._src_at[0])
	out.stale = m.global_transform.origin.distance_to(want) / CELL
	return out

## "" when every case passes, else "n bad of m: rows".
static func run(plant: String = "") -> String:
	rows.clear()
	var tree := Engine.get_main_loop() as SceneTree
	var cam: Camera3D = tree.root.get_viewport().get_camera_3d()
	var pl: Node3D = tree.get_first_node_in_group("player") as Node3D
	var body: Node3D = stand_in(pl.global_position + Vector3(1.2, 0.0, 0.0), "bat", "down")
	body.get_node("ActorLit").set("air_force", plant != "glued")
	var n: int = 0
	var log: PackedStringArray = PackedStringArray()
	for kind in flyers():
		for face: String in FACES:
			var last: Dictionary = {}
			for alt: float in ALTS:
				_face(body, kind, face, alt)
				var r: Dictionary = probe(body, cam)
				n += 1
				var why: String = r.why
				if why == "":
					if r.gap < MIN_GAP:
						why = "attached gap=%.1f" % r.gap
					if r.lift <= 0.0 or r.lateral > r.half + CELL:
						why += " off_body lat=%.2f" % r.lateral
					if not last.is_empty() and (r.gap <= last.gap or r.scale > last.scale or r.alpha > last.alpha or r.along <= last.along):
						why += " no_falloff gap=%.1f/%.1f s=%.2f/%.2f a=%.2f/%.2f" % [last.gap, r.gap, last.scale, r.scale, last.alpha, r.alpha]
					if not last.is_empty():
						var d: float = (r.along - last.along) / maxf(r.lift - last.lift, 1e-3)
						if d < 0.4 or d > 1.4:
							why += " along/lift=%.2f" % d
				log.append("%s/%s@%.2f gap=%.1f along=%.2f lat=%.2f s=%.2f a=%.2f lift=%.2f %s" % [kind, face, alt, r.get("gap", -1.0), r.get("along", 0.0), r.get("lateral", 0.0), r.get("scale", 0.0), r.get("alpha", 0.0), r.get("lift", 0.0), why])
				if why != "":
					rows.append("%s/%s@%.2f %s" % [kind, face, alt, why.strip_edges()])
				last = r
	# Erratic flight: a random facing, flip and altitude every frame; the mark must sit on this frame's spot.
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	var ks: Array[String] = flyers()
	for i in 60:
		_face(body, ks[i % ks.size()], FACES[rng.randi() % 8], rng.randf_range(0.1, 1.0))
		(body.get_child(0) as Sprite3D).flip_h = rng.randf() < 0.5
		body.global_position += Vector3(rng.randf_range(-0.2, 0.2), 0.0, rng.randf_range(-0.2, 0.2))
		var r: Dictionary = probe(body, cam, not (plant == "hang" and i == 30))
		n += 1
		if r.why != "" or r.stale > 1.0:
			rows.append("erratic#%d %s stale=%.1f" % [i, r.why, r.get("stale", -1.0)])
	body.queue_free()
	if plant == "":
		DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://_logs/mark-matrix/"))
		var f := FileAccess.open(ProjectSettings.globalize_path("res://_logs/mark-matrix/fly.txt"), FileAccess.WRITE)
		if f != null:
			f.store_string("\n".join(log + rows) + "\n")
	return "" if rows.is_empty() else "%d bad of %d: %s" % [rows.size(), n, "; ".join(rows.slice(0, 6))]

## usec per frame for n bats (bob + a facing change every 8 frames), air off (old glued mark) vs on.
static func bench(n: int = 20, frames: int = 240) -> String:
	var tree := Engine.get_main_loop() as SceneTree
	var pl: Node3D = tree.get_first_node_in_group("player") as Node3D
	var bats: Array[Node3D] = []
	for i in n:
		bats.append(stand_in(pl.global_position + Vector3(float(i % 5) * 0.8 - 1.6, 0.0, float(i / 5) * 0.8 - 1.2), "bat", "down"))
	var out: PackedStringArray = PackedStringArray()
	for air: bool in [true, false, true]:
		for b in bats:
			b.get_node("ActorLit").set("air_force", air)
		var t0: int = Time.get_ticks_usec()
		for f in frames:
			for i in n:
				var face: String = FACES[(f / 8 + i) % 8]
				_face(bats[i], "bat", face, 0.45 + sin(float(f + i) * 0.2) * 0.08)
				bats[i].get_node("ActorLit")._process(1.0 / 60.0)
		out.append("%s=%.0fus" % ["new" if air else "old", float(Time.get_ticks_usec() - t0) / frames])
	out.remove_at(0)  # warm-up pass (texture loads, Soles caches)
	for b in bats:
		b.queue_free()
	return "%d bats per frame: %s" % [n, " ".join(out)]

## Contact sheet stage: each flyer at each altitude in a row by the player, left for the flow's frame.
static func stage() -> String:
	var tree := Engine.get_main_loop() as SceneTree
	var pl: Node3D = tree.get_first_node_in_group("player") as Node3D
	var ks: Array[String] = flyers()
	for k in ks.size():
		for a in ALTS.size():
			stand_in(pl.global_position + Vector3([-2.2, -1.0, 1.2][a], 0.0, float(k) * 1.3 - 1.6), ks[k], FACES[(k * 3 + a) % 8])
			_face(tree.current_scene.get_child(tree.current_scene.get_child_count() - 1), ks[k], FACES[(k * 3 + a) % 8], ALTS[a])
	return ""
