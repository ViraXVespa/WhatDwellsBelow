extends RefCounted

## Shadow-mark matrix (hub_shadow_check.matrix, camp-prop-shadows flow): every player kind and enemy type, every
## idle/walk/attack frame on disk (all facings present), laid through the live player ActorLit. The mark's near
## edge sits on the pins for any light direction, so one pass covers sun, lantern and torch marks. Per foot (Soles: lowest opaque pixel of each foot): grounded (lift < RAISED
## cells) must attach within TOL cells of its mark pin on screen; raised must show a gap > MIN_GAP cells that
## matches the lift's screen height within max(TOL, LIFT_K x lift). Mark mask at cell scale: one main piece
## (no detached chunk >= CHUNK cells), no enclosed hole >= HOLE cells. Full-shade double: hub_mark_light.shade (camp-prop-shadows, player placed in shade).
## run(plant): "" offset (pin shifted 3 cells), "glue" (raised foot pinned at its own row), "chunk" (stray blob).

const K := preload("res://scripts/graphics/actor_lit/lit_k.gd")
const T := preload("res://scripts/data/tunables.gd")
const Soles := preload("res://scripts/graphics/actor_lit/soles.gd")
const Geo := preload("res://scripts/graphics/actor_lit/lit_geo.gd")
const Facing := preload("res://scripts/world/facing.gd")
const CELL := 1.0 / 32.0
const TOL := 1.0
const RAISED := K.RAISED_CELLS
const MIN_GAP := 0.5
const LIFT_K := 0.5
const CHUNK := 3
const HOLE := 2
## A cell draws when its box-averaged coverage clears lit_k's discard (0.02); mask pieces use the same cut.
const DRAWN := 0.02
## Sprite sets whose art floats a piece free of the body (imp hand flames): chunk reported as info.
const ART_CHUNK := ["imp"]
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
		list = list.filter(func(r): return str(r[1]).begins_with("walk_")).slice(0, 40)
	for fr: Array in list:
		var tex: Texture2D = load(fr[2])
		if tex == null:
			continue
		spr.texture = tex
		spr.pixel_size = T.PLAYER_H / float(maxi(1, tex.get_height()))
		var why: PackedStringArray = foot_faults(lit, spr, cam, tex, plant)
		var mask: PackedStringArray = mask_faults(tex, spr.pixel_size, plant == "chunk")
		var known: bool = str(fr[0]) in ART_CHUNK and plant == ""
		if plant == "chunk" or (not known and not mask.is_empty() and mask[0].begins_with("chunk")):
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

static func foot_faults(lit: Node, spr: Sprite3D, cam: Camera3D, tex: Texture2D, plant: String) -> PackedStringArray:
	var out: PackedStringArray = PackedStringArray()
	var s: Vector4 = Soles._soles(tex)
	var tw: float = tex.get_width()
	var th: float = tex.get_height()
	var px: float = spr.pixel_size
	var sole_y: float = maxf(s.y, s.w)
	var c0: Vector3 = Vector3(spr.global_position.x, T.FLOOR_Y, spr.global_position.z)
	var cell: float = cam.unproject_position(c0).distance_to(cam.unproject_position(c0 + Vector3(CELL, 0.0, 0.0)))
	for f in 2:
		var tx: float = s.x if f == 0 else s.z
		var ty: float = s.y if f == 0 else s.w
		var lift: float = (sole_y - ty) * px / CELL
		var pin_y: float = ty if plant == "glue" else sole_y
		var pin: Vector2 = Geo._sole_xz(lit, tx, pin_y, tw, th, lift < RAISED and plant != "glue")
		if plant == "offset":
			pin += Vector2(0.0, 3.0 * CELL)
		var foot: Vector2 = cam.unproject_position(_foot_world(spr, tx, ty, tw, th))
		var gap: float = foot.distance_to(cam.unproject_position(Vector3(pin.x, T.FLOOR_Y, pin.y))) / maxf(cell, 0.01)
		var tuck: float = (px * (2.0 + float(lit.get("foot"))) + CELL) / CELL
		var lifted: float = cam.unproject_position(_foot_world(spr, tx, ty, tw, th)).distance_to(cam.unproject_position(_foot_world(spr, tx, sole_y, tw, th))) / maxf(cell, 0.01)
		var name: String = "L" if f == 0 else "R"
		if lift < RAISED:
			if gap > TOL + tuck:
				out.append("%s_detached gap=%.1f" % [name, gap])
		elif gap < MIN_GAP or absf(gap - lifted) > maxf(TOL, LIFT_K * lifted):
			out.append("%s_raised gap=%.1f want=%.1f" % [name, gap, lifted])
	return out

static func _foot_world(spr: Sprite3D, tx: float, ty: float, tw: float, th: float) -> Vector3:
	var ox: float = spr.offset.x - (tw * 0.5 if spr.centered else 0.0)
	var oy: float = spr.offset.y - (th * 0.5 if spr.centered else 0.0)
	var cam: Camera3D = spr.get_viewport().get_camera_3d()
	var axis: Vector3 = cam.global_transform.basis.x
	return spr.global_position + axis * (ox + tx) * spr.pixel_size + Vector3(0.0, (oy + th - ty) * spr.pixel_size, 0.0)

## Mark mask (sprite alpha) at the ground cell scale: detached pieces and enclosed holes.
static func mask_faults(tex: Texture2D, px: float, plant: bool) -> PackedStringArray:
	var img: Image = tex.get_image().duplicate()
	if img.is_compressed():
		img.decompress()
	var f: float = maxf(1.0, CELL / px)
	var w: int = maxi(1, roundi(img.get_width() / f))
	var h: int = maxi(1, roundi(img.get_height() / f))
	img.convert(Image.FORMAT_RGBA8)
	img.resize(w, h, Image.INTERPOLATE_BILINEAR)
	var on: PackedByteArray = PackedByteArray()
	on.resize(w * h)
	for i in w * h:
		on[i] = 1 if img.get_pixel(i % w, i / w).a > DRAWN else 0
	if plant:
		on[0] = 1; on[1] = 1; on[w] = 1; on[w + 1] = 1
	var out: PackedStringArray = PackedStringArray()
	var pieces: Array = _parts(on, w, h, 1)
	pieces.sort_custom(func(a, b): return a[0] > b[0])
	for i in range(1, pieces.size()):
		if pieces[i][0] >= CHUNK:
			out.append("chunk=%d" % pieces[i][0])
			break
	for hole: Array in _parts(on, w, h, 0):
		if not hole[1] and hole[0] >= HOLE:
			out.append("hole=%d" % hole[0])
			break
	return out

## [size, touches_border] per 4-connected component of value v.
static func _parts(on: PackedByteArray, w: int, h: int, v: int) -> Array:
	var seen: PackedByteArray = PackedByteArray()
	seen.resize(w * h)
	var out: Array = []
	for start in w * h:
		if on[start] != v or seen[start]:
			continue
		var stack: Array[int] = [start]
		seen[start] = 1
		var size := 0
		var edge := false
		while not stack.is_empty():
			var i: int = stack.pop_back()
			size += 1
			var x: int = i % w
			var y: int = i / w
			edge = edge or x == 0 or y == 0 or x == w - 1 or y == h - 1
			for j in [i - 1 if x > 0 else -1, i + 1 if x < w - 1 else -1, i - w, i + w]:
				if j >= 0 and j < w * h and on[j] == v and not seen[j]:
					seen[j] = 1
					stack.append(j)
		out.append([size, edge])
	return out

static func _tile(sheet: Image, n: int, tex: Texture2D, ok: bool) -> void:
	var img: Image = tex.get_image().duplicate()
	if img.is_compressed():
		img.decompress()
	img.convert(Image.FORMAT_RGBA8)
	img.resize(TILE.x, TILE.y - 4, Image.INTERPOLATE_NEAREST)
	var at := Vector2i((n % 32) * TILE.x, (n / 32) * TILE.y)
	sheet.blend_rect(img, Rect2i(Vector2i.ZERO, img.get_size()), at)
	sheet.fill_rect(Rect2i(at + Vector2i(0, TILE.y - 4), Vector2i(TILE.x, 4)), Color.GREEN if ok else Color.RED)
