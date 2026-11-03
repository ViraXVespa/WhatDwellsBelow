extends Object

## Baked actor soles. Play looks up scripts/data/actor_soles.json. The pixel scan runs only in the bake.

const SOLE_BAKE_STAMP := "934132e15a2707c5"
const BAKE_PATH := "res://scripts/data/actor_soles.json"

static var _spans: Dictionary = {}
static var _sole_at: Dictionary = {}
static var _foot_at: Dictionary = {}
static var _table: Dictionary = {}
static var _table_ok: bool = false

static func warm() -> void:
	if _table_ok:
		return
	var txt: String = FileAccess.get_file_as_string(BAKE_PATH)
	if txt == "":
		_fatal("%s is missing or unreadable." % BAKE_PATH)
		return
	var data: Variant = JSON.parse_string(txt)
	if not (data is Dictionary):
		_fatal("%s is not a sole bake." % BAKE_PATH)
		return
	var parsed: Dictionary = data as Dictionary
	var stamp: String = str(parsed.get("stamp", ""))
	if stamp != SOLE_BAKE_STAMP:
		_fatal("%s stamp %s does not match SOLE_BAKE_STAMP %s (stale bake)." % [BAKE_PATH, stamp, SOLE_BAKE_STAMP])
		return
	var rows_v: Variant = parsed.get("rows", null)
	if not (rows_v is Dictionary):
		_fatal("%s has no rows." % BAKE_PATH)
		return
	_table = rows_v as Dictionary
	_table_ok = true

static func _soles(tex: Texture2D) -> Vector4:
	var id: int = tex.get_rid().get_id()
	if _sole_at.has(id):
		return _sole_at[id] as Vector4
	warm()
	var path: String = tex.resource_path.replace("\\", "/")
	if path == "" or not _table.has(path):
		_fatal("no row for %s." % [path if path != "" else "<empty resource_path>"])
		return Vector4.ZERO
	var row_v: Variant = _table[path]
	if not (row_v is Array) or (row_v as Array).size() < 11:
		_fatal("short row for %s." % path)
		return Vector4.ZERO
	var row: Array = row_v as Array
	var sole := Vector4(_fdec(str(row[1])), _fdec(str(row[2])), _fdec(str(row[3])), _fdec(str(row[4])))
	var min_x: int = int(row[5])
	if min_x >= 0:
		var sw: float = float(row[9])
		var sh: float = float(row[10])
		if sw > 0.0 and sh > 0.0:
			_spans[id] = Vector4(
				float(min_x) / sw, float(int(row[6])) / sh,
				float(int(row[7])) / sw, float(int(row[8])) / sh
			)
	return _keep(id, sole)

## Pixel scan used by tools/bake.py soles. Not called from play.
static func _scan(tex: Texture2D) -> Dictionary:
	var tw: int = maxi(1, tex.get_width())
	var th: int = maxi(1, tex.get_height())
	var img: Image = tex.get_image()
	if img == null or img.is_empty():
		return _none(tw, th)
	if img.get_format() != Image.FORMAT_RGBA8:
		var copy: Image = img.duplicate()
		copy.convert(Image.FORMAT_RGBA8)
		img = copy
	var w: int = img.get_width()
	var h: int = img.get_height()
	var bytes: PackedByteArray = img.get_data()
	if w < 1 or h < 1 or bytes.size() < w * h * 4:
		return _none(tw, th)
	var min_x: int = w
	var min_y: int = h
	var max_x: int = -1
	var max_y: int = -1
	for y in h:
		var row: int = y * w * 4
		for x in w:
			if bytes[row + x * 4 + 3] < 51:
				continue
			if x < min_x:
				min_x = x
			if y < min_y:
				min_y = y
			if x > max_x:
				max_x = x
			if y > max_y:
				max_y = y
	if max_x < 0:
		return _none(w, h)
	var mid: int = int(float(min_x + max_x) * 0.5)
	var ly: int = -1
	var ry: int = -1
	var ls: float = 0.0
	var ln: int = 0
	var rs: float = 0.0
	var rn: int = 0
	for y2 in range(min_y, max_y + 1):
		var row2: int = y2 * w * 4
		var lsum: float = 0.0
		var lnum: int = 0
		var rsum: float = 0.0
		var rnum: int = 0
		for x2 in range(min_x, max_x + 1):
			if bytes[row2 + x2 * 4 + 3] < 51:
				continue
			if x2 <= mid:
				lsum += float(x2) + 0.5
				lnum += 1
			else:
				rsum += float(x2) + 0.5
				rnum += 1
		if lnum > 0:
			ly = y2
			ls = lsum
			ln = lnum
		if rnum > 0:
			ry = y2
			rs = rsum
			rn = rnum
	var sole: Vector4 = _bottom_span(bytes, w, max_y, min_x, max_x)
	if ly >= 0 and ry >= 0:
		var lx: float = ls / float(ln)
		var rx: float = rs / float(rn)
		if absf(rx - lx) < 0.5:
			var mid_foot: float = (lx + rx) * 0.5
			lx = mid_foot
			rx = mid_foot
		sole = Vector4(lx, float(ly + 1), rx, float(ry + 1))
	return {
		"sole": sole,
		"min_x": min_x, "min_y": min_y, "max_x1": max_x + 1, "max_y1": max_y + 1,
		"w": w, "h": h,
	}

static func _none(w: int, h: int) -> Dictionary:
	return {
		"sole": Vector4(0.0, float(h), float(w), float(h)),
		"min_x": -1, "min_y": -1, "max_x1": -1, "max_y1": -1,
		"w": w, "h": h,
	}

static func _fhex(v: float) -> String:
	var buf: PackedByteArray = PackedByteArray()
	buf.resize(8)
	buf.encode_double(0, v)
	return buf.hex_encode()

static func _fdec(hex: String) -> float:
	var buf: PackedByteArray = hex.hex_decode()
	if buf.size() < 8:
		return 0.0
	return buf.decode_double(0)

static func _fatal(msg: String) -> void:
	var full: String = "FATAL actor soles: %s Rebake with python tools/bake.py soles (design/graphics-actor.md)." % msg
	push_error(full)
	OS.crash(full)

static func _keep(id: int, sole: Vector4) -> Vector4:
	_sole_at[id] = sole
	return sole

static func _bottom_span(bytes: PackedByteArray, w: int, y: int, x0: int, x1: int) -> Vector4:
	var row: int = y * w * 4
	var left: int = x1
	var right: int = x0
	for x in range(x0, x1 + 1):
		if bytes[row + x * 4 + 3] < 51:
			continue
		if x < left:
			left = x
		if x > right:
			right = x
	if right <= left:
		right = mini(w - 1, left + 1)
	return Vector4(float(left) + 0.5, float(y + 1), float(right) + 0.5, float(y + 1))

static func _span(tex: Texture2D) -> Vector4:
	var id: int = tex.get_rid().get_id()
	if not _spans.has(id):
		_soles(tex)
	if _spans.has(id):
		return _spans[id] as Vector4
	return Vector4(0.0, 0.0, 1.0, 1.0)

static var _solid_at: Dictionary = {}

## Shadow caster for a deep yard prop, built from its geometry instead of the drawn outline (holes, lids, rust):
## "profile" (anvil): every row filled between its outer texels, so the mark keeps the solid's taper (face, waist,
##   feet), dropped so the base's widest row is the contact. "raised" (dumpster): the body box (rows with at least RAISED_BODY of the fullest row's texels, filled to its outer
##   texels) on wheel posts: the wheel band below the body is opaque only on the drawn wheel columns plus the hidden
##   back-left wheel (front-left shifted by the drawn front-to-back offset), so light shows between four wheels.
##   Wheels are a few cm on a ~1.2 m box: posts WHEEL_K of the box height, the box shadow starts right past them.
const RAISED_BODY := 0.5
const WHEEL_K := 0.08
## Profile base: the last row with this share of the fullest row's texels is the contact.
const PROFILE_BASE := 0.9
## Footprint depth in texels: rows from a profile base's widest row down to its sole (the curved ground contact).
static func _foot(tex: Texture2D) -> int:
	var id: int = tex.get_rid().get_id()
	if _foot_at.has(id):
		return int(_foot_at[id])
	var img: Image = tex.get_image()
	if img == null:
		return 0
	if img.is_compressed():
		img.decompress()
	var u: Rect2i = img.get_used_rect()
	var n: int = maxi(0, u.end.y - _body_end(img, PROFILE_BASE))
	_foot_at[id] = n
	return n

static func _solid(tex: Texture2D, shape: String = "profile") -> Texture2D:
	var key: String = "%d:%s" % [tex.get_rid().get_id(), shape]
	if _solid_at.has(key):
		return _solid_at[key] as Texture2D
	var img: Image = tex.get_image()
	if img == null or img.is_empty():
		return tex
	img = img.duplicate()
	img.decompress()
	img.convert(Image.FORMAT_RGBA8)
	var w: int = img.get_width()
	var h: int = img.get_height()
	var lo: PackedInt32Array = PackedInt32Array()
	var hi: PackedInt32Array = PackedInt32Array()
	for y in h:
		var l: int = -1
		var r: int = -1
		for x in w:
			if img.get_pixel(x, y).a >= 0.2:
				if l < 0:
					l = x
				r = x
		lo.append(l)
		hi.append(r)
	var out: Image = Image.create(w, h, false, Image.FORMAT_RGBA8)
	if shape == "profile":
		# Rows under the base's widest row are the 3/4 footprint (depth, not height): drop the solid onto the sole
		# so the mark is full width at the contact (no daylight under the stump's front edge).
		var base: int = _body_end(img, PROFILE_BASE) - 1
		var sole_p: int = base
		for y in h:
			if lo[y] >= 0:
				sole_p = y
		for y in base + 1:
			if lo[y] >= 0:
				out.fill_rect(Rect2i(lo[y], y + sole_p - base, hi[y] - lo[y] + 1, 1), Color(0, 0, 0, 1))
	else:
		var body_end: int = _body_end(img)
		var posts: Array[Vector2i] = _wheels(img, body_end)
		var sole: int = body_end - 1
		var rim: int = 0
		var left: int = w
		for y in h:
			if lo[y] >= 0:
				sole = y
				if y < body_end and lo[y] < left:
					left = lo[y]
					rim = y
		# Card rows are height above the ground: the box is rim..body_end (the drawn front face; rows above it are
		# the 3/4 top face, depth not height), dropped onto posts WHEEL_K of its height tall. "stilts" keeps the
		# drawn wheel band (planted fault for hub_shadow_check.wheels).
		var k: int = maxi(2, roundi(WHEEL_K * float(body_end - rim)))
		var shift: int = maxi(0, sole - k - (body_end - 1))
		if shape == "stilts":
			rim = 0
			shift = 0
			k = sole - body_end + 1
		for y in range(rim, body_end):
			if lo[y] >= 0 and y + shift < h:
				out.fill_rect(Rect2i(lo[y], y + shift, hi[y] - lo[y] + 1, 1), Color(0, 0, 0, 1))
		for y in range(sole - k + 1, sole + 1):
			for p in posts:
				out.fill_rect(Rect2i(p.x, y, p.y - p.x + 1, 1), Color(0, 0, 0, 1))
	var t: ImageTexture = ImageTexture.create_from_image(out)
	_solid_at[key] = t
	return t

## Row after the body box: the last row with at least RAISED_BODY of the fullest row's opaque texels.
static func _body_end(img: Image, share: float = RAISED_BODY) -> int:
	var n: PackedInt32Array = PackedInt32Array()
	for y in img.get_height():
		var c: int = 0
		for x in img.get_width():
			if img.get_pixel(x, y).a >= 0.2:
				c += 1
		n.append(c)
	var most: int = 0
	for c in n:
		most = maxi(most, c)
	var end: int = img.get_height()
	for y in n.size():
		if n[y] > 0 and n[y] >= int(most * share):
			end = y + 1
	return end

## Wheel column runs [x0, x1] under the body (columns opaque on 2+ band rows), plus the hidden fourth: the first run
## shifted by the offset between the last two runs (the drawn front-to-back depth), when only three are drawn.
static func _wheels(img: Image, body_end: int) -> Array[Vector2i]:
	var runs: Array[Vector2i] = []
	var start: int = -1
	for x in img.get_width() + 1:
		var hits: int = 0
		if x < img.get_width():
			for y in range(body_end, img.get_height()):
				if img.get_pixel(x, y).a >= 0.2:
					hits += 1
		var on: bool = hits >= 2  # a one-row sliver is the body's bottom edge, not a wheel
		if on and start < 0:
			start = x
		elif not on and start >= 0:
			runs.append(Vector2i(start, x - 1))
			start = -1
	if runs.size() == 3:
		var d: int = runs[2].x - runs[1].x
		runs.append(Vector2i(runs[0].x + d, runs[0].y + d))
	return runs
