extends RefCounted

## Shadow-mark matrix (hub_shadow_check.matrix, camp-prop-shadows flow): every player kind and enemy type, every
## idle/walk/attack frame on disk (all facings present), laid through the live player ActorLit. The mark's near
## edge sits on the pins for any light direction, so one pass covers sun, lantern and torch marks. Per foot (Soles: lowest opaque pixel of each foot): grounded (lift < RAISED
## cells) must attach within TOL cells of its mark pin on screen; raised must show a gap of at least max(MIN_GAP, LIFT_K x lift)
## and at most REACH_K x lift + TOL cells (raised = sole over K.RAISED_M; an all-glow body is skipped). Mark mask at cell scale: one main piece
## (no detached chunk >= mark_mask.CHUNK cells), no enclosed hole >= mark_mask.HOLE cells. Full-shade double: hub_mark_light.shade (camp-prop-shadows, player placed in shade).
## run(plant): "" offset (pin shifted 3 cells), "glue" (raised foot pinned at its own row), "chunk" (stray blob),
## "glow" (imp with its flame mask off: the hand fire must show as a detached chunk). Masks go through lit_emis.

const K := preload("res://scripts/graphics/actor_lit/lit_k.gd")
const T := preload("res://scripts/data/tunables.gd")
const Soles := preload("res://scripts/graphics/actor_lit/soles.gd")
const Geo := preload("res://scripts/graphics/actor_lit/lit_geo.gd")
const Facing := preload("res://scripts/world/facing.gd")
const CELL := K.GRID_M
const TOL := 1.25  # one texel cell plus sub-cell pin rounding (camera drop at 1/82.6 m cells)
## Most a grounded pin tucks under its boot, in cells (Geo: 2-3 sprite px + 2 cells) plus one cell of snap.
const TUCK := 6.0
const RAISED := K.RAISED_M / K.GRID_M
const MIN_GAP := 0.5
const LIFT_K := 0.5
const REACH_K := 3.0
const Mask := preload("res://scripts/debug/hub_shadow_check/mark_mask.gd")
const OUT := "res://_logs/mark-matrix/"
const TILE := Vector2i(40, 56)

static var rows: PackedStringArray = PackedStringArray()
static var cases: int = 0
## Enclosed holes at the cell scale (legit gaps between limbs mostly): reported, not failed.
static var info: PackedStringArray = PackedStringArray()

static func frames() -> Array:
	var out: Array = []
	for root in ["res://assets/sprites/player/", "res://assets/sprites/enemies/"]:
		for kind in DirAccess.get_directories_at(root):
			for f: String in DirAccess.get_files_at(root + kind):
				var stem: String = f.get_basename()
				if f.ends_with(".png") and stem.get_slice("_", 0) in ["idle", "walk", "atk"] and not stem.contains("_to_"):
					out.append([kind, stem, root + kind + "/" + f])
	return out

## "" when every case passes, else the first rows; plant names a planted fault the run must report.
static func run(plant: String = "") -> String:
	rows.clear()
	info.clear()
	cases = 0
	var p: Node3D = (Engine.get_main_loop() as SceneTree).get_first_node_in_group("player") as Node3D
	var lit: Node = null if p == null else p.get_node_or_null("ActorLit")
	if lit == null:
		return "no player ActorLit"
	var spr: Sprite3D = lit.get("spr")
	var cam: Camera3D = p.get_viewport().get_camera_3d()
	var keep: Array = [spr.texture, spr.pixel_size, spr.flip_h]
	var sheet := Image.create(TILE.x * 32, TILE.y * 48, false, Image.FORMAT_RGBA8)
	sheet.fill(Color(0.3, 0.3, 0.3))
	var n: int = 0
	var list: Array = frames()
	if plant != "":
		var pick: String = "imp" if plant == "glow" else ""
		list = list.filter(func(r): return r[0] == pick if pick != "" else str(r[1]).begins_with("walk_")).slice(0, 40)
	for fr: Array in list:
		var tex: Texture2D = load(fr[2])
		if tex == null:
			continue
		spr.texture = tex
		spr.pixel_size = T.PLAYER_H / float(maxi(1, tex.get_height()))
		var why: PackedStringArray = foot_faults(lit, spr, cam, tex, plant)
		var rule: String = "" if plant == "glow" else str(K.GLOW.get(fr[0], ""))
		var mask: PackedStringArray = PackedStringArray() if rule == "glow" else mask_faults(tex, spr.pixel_size, plant == "chunk", rule, str(K.GLOW.get(fr[0], "")))
		if plant == "chunk" or (not mask.is_empty() and mask[0].get_slice("=", 0) in ["chunk", "glow"]):
			why.append_array(mask)
		elif not mask.is_empty():
			info.append("%s/%s %s" % [fr[0], fr[1], " ".join(mask)])
		cases += 1
		if not why.is_empty():
			rows.append("%s/%s %s" % [fr[0], fr[1], " ".join(why)])
		if n < 32 * 48:
			_tile(sheet, n, tex, why.is_empty())
		n += 1
	spr.texture = keep[0]
	spr.pixel_size = keep[1]
	spr.flip_h = keep[2]
	if plant == "":
		DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
		sheet.save_png(ProjectSettings.globalize_path(OUT + "sheet.png"))
		var f := FileAccess.open(ProjectSettings.globalize_path(OUT + "rows.txt"), FileAccess.WRITE)
		if f != null:
			f.store_string("\n".join(rows) + "\n# holes (info)\n" + "\n".join(info) + "\n")
	return "" if rows.is_empty() else "%d bad of %d: %s" % [rows.size(), n, "; ".join(rows.slice(0, 6))]

## Per foot, measured on the LIVE mark mesh (lit._process just ran): the foot's sole texel mapped through the
## quad's triangles (as the GPU interpolates UV) to the ground, projected, vs the foot's own screen pixel (flip_h
## honoured). Grounded: within TOL cells. Raised: gap matching its lift. Plants move the drawn mesh itself.
static func foot_faults(lit: Node, spr: Sprite3D, cam: Camera3D, tex: Texture2D, plant: String) -> PackedStringArray:
	var out: PackedStringArray = PackedStringArray()
	lit._process(0.0)
	var m: MeshInstance3D = lit.marks[0]
	if not m.visible or m.mesh == null:
		return PackedStringArray(["no_mark"])
	var arr: Array = m.mesh.surface_get_arrays(0)
	var vs: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]
	var uv: PackedVector2Array = arr[Mesh.ARRAY_TEX_UV]
	var xf: Transform3D = m.global_transform
	if plant == "offset":
		xf.origin += Vector3(0.0, 0.0, 3.0 * CELL)
	var s: Vector4 = Soles._soles(tex)
	var tw: float = tex.get_width()
	var th: float = tex.get_height()
	var px: float = spr.pixel_size
	var sole_y: float = maxf(s.y, s.w)
	var c0: Vector3 = Vector3(spr.global_position.x, T.FLOOR_Y, spr.global_position.z)
	var cell: float = cam.unproject_position(c0).distance_to(cam.unproject_position(c0 + Vector3(CELL, 0.0, 0.0)))
	for f in 2:
		var tx: float = (s.x if f == 0 else s.z) + 0.5
		var ty: float = (s.y if f == 0 else s.w) + 0.5
		var lift: float = (sole_y - ty + 0.5) * px / CELL
		var hit: Vector3 = xf * _uv_world(vs, uv, Vector2(tx / tw, minf(ty, sole_y + 0.5) / th))
		var foot: Vector2 = cam.unproject_position(_foot_world(spr, tx, ty, tw, th))
		var mark: Vector2 = cam.unproject_position(hit)
		if plant == "glue" and lift >= RAISED:
			mark = foot  # a raised foot glued to its mark
		var gap: float = foot.distance_to(mark) / maxf(cell, 0.01)
		var lifted: float = foot.distance_to(cam.unproject_position(_foot_world(spr, tx, sole_y + 0.5, tw, th))) / maxf(cell, 0.01)
		var name: String = "L" if f == 0 else "R"
		last_gaps[f] = gap
		var dx: float = (mark.x - foot.x) / maxf(cell, 0.01)
		var dy: float = (mark.y - foot.y) / maxf(cell, 0.01)
		if lift < RAISED:
			# Grounded: the pin may tuck up-screen under the boot (Geo tuck, hidden by the boot) but never sit below
			# it or beside it; what the eye sees is checked on rendered pixels (feet_px.gd).
			if dy > TOL or dy < -TUCK or absf(dx) > 2.0 * TOL:
				out.append("%s_detached gap=%.1f dx=%.1f dy=%.1f" % [name, gap, dx, dy])
		# Raised: a gap at least half the lift and at most lift plus its sun reach (REACH_K lifts; the shadow of a
		# lifted point lands along the light as well as below it).
		elif gap < maxf(MIN_GAP, LIFT_K * lifted) or gap > REACH_K * lifted + TOL:
			out.append("%s_raised gap=%.1f want=%.1f" % [name, gap, lifted])
	return out

static var last_gaps: Array[float] = [0.0, 0.0]

## Ground point of a texture UV on the mark quad (verts 0..3, triangles 0-1-2 and 0-2-3, affine per triangle).
static func _uv_world(vs: PackedVector3Array, uv: PackedVector2Array, at: Vector2) -> Vector3:
	for tri: Array in [[0, 1, 2], [0, 2, 3]]:
		var a: Vector2 = uv[tri[0]]
		var b: Vector2 = uv[tri[1]]
		var c: Vector2 = uv[tri[2]]
		var w: Vector3 = _bary(at, a, b, c)
		if w.x >= -1e-4 and w.y >= -1e-4 and w.z >= -1e-4:
			return vs[tri[0]] * w.x + vs[tri[1]] * w.y + vs[tri[2]] * w.z
	return vs[0]

static func _bary(p: Vector2, a: Vector2, b: Vector2, c: Vector2) -> Vector3:
	var v0: Vector2 = b - a
	var v1: Vector2 = c - a
	var v2: Vector2 = p - a
	var d: float = v0.x * v1.y - v1.x * v0.y
	if absf(d) < 1e-9:
		return Vector3(-1, -1, -1)
	var v: float = (v2.x * v1.y - v1.x * v2.y) / d
	var w: float = (v0.x * v2.y - v2.x * v0.y) / d
	return Vector3(1.0 - v - w, v, w)

static func _foot_world(spr: Sprite3D, tx: float, ty: float, tw: float, th: float) -> Vector3:
	var ox: float = spr.offset.x - (tw * 0.5 if spr.centered else 0.0)
	var oy: float = spr.offset.y - (th * 0.5 if spr.centered else 0.0)
	var cam: Camera3D = spr.get_viewport().get_camera_3d()
	var axis: Vector3 = cam.global_transform.basis.x
	var g: float = (tw - tx) if spr.flip_h else tx
	return spr.global_position + axis * (ox + g) * spr.pixel_size + Vector3(0.0, (oy + th - ty) * spr.pixel_size, 0.0)

static func mask_faults(tex: Texture2D, px: float, plant: bool, rule: String = "", kind_rule: String = "") -> PackedStringArray:
	return Mask.faults(tex, px, plant, rule, kind_rule)

static func _tile(sheet: Image, n: int, tex: Texture2D, ok: bool) -> void:
	Mask.tile(sheet, n, tex, ok, TILE)
