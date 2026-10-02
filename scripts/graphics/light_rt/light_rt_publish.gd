extends Object

## Dungeon light ring maintain and publish. State stays on light_rt.gd.

const Stamp := preload("res://scripts/graphics/light_stamp/light_stamp.gd")
const Plan := preload("res://scripts/graphics/torch_plan/torch_plan.gd")
const HitchLog := preload("res://scripts/debug/hitch_log.gd")
const Lights := preload("res://scripts/graphics/light_rt/light_rt_lights.gd")
const RT_PATH := "res://scripts/graphics/light_rt/light_rt.gd"

static func maintain(host: Node) -> void:
	var rt: Variant = load(RT_PATH)
	if host == null or host.get("data") == null:
		return
	var rect: Rect2i = _ring_rect(host)
	if rect.size.x < 1 or rect.size.y < 1:
		return
	var mode := ""
	if App.present:
		mode = str(App.present.get("_mode"))
	var entering: bool = mode == "enter_hold" or mode == "enter_fade" or rt._rect.size.x < 1
	var key: String = Lights._knob_key()
	var live: String = Lights._live_key(host)
	var need_plan: bool = rt._plan_dirty or not rt._planned or (rt._plan_partial and not entering)
	var need_torch: bool = live != rt._live
	var need_stamp: bool = key != rt._knob or rect != rt._rect
	if not need_plan and not need_stamp and not need_torch:
		return
	var LoadTiming: GDScript = load("res://scripts/debug/load_timing.gd") as GDScript
	if need_plan:
		rt._sites = Plan.build(host, rt._props, rect if entering else Rect2i())
		rt._plan_partial = entering
		HitchLog.mark("light_plan")
		if LoadTiming:
			LoadTiming.dnote("light_kind", "plan")
		rt._planned = true
		rt._plan_dirty = false
		return
	if need_stamp:
		HitchLog.mark("light_stamp")
		if LoadTiming:
			LoadTiming.dnote("light_kind", "stamp")
		rt._rect = rect
		rt._knob = key
		_publish_dungeon(host, rect)
		return
	HitchLog.mark("light_refill")
	if LoadTiming:
		LoadTiming.dnote("light_kind", "refill")
	rt._live = live
	_refill(host)
static func _publish_dungeon(host: Node, rect: Rect2i) -> void:
	var x0: int = rect.position.x
	var z0: int = rect.position.y
	var tw: int = rect.size.x
	var th: int = rect.size.y
	var solid: PackedByteArray = PackedByteArray()
	var sw: int = 0
	var sh: int = 0
	var n: int = 1
	if host.data.has("solid") and host.data["solid"] is PackedByteArray:
		solid = host.data["solid"]
		sw = int(host.data.get("solid_w", 0))
		sh = int(host.data.get("solid_h", 0))
		n = maxi(1, int(host.data.get("solid_n", 1)))
	var lights: Array = Lights._dungeon_lights(host, x0, z0, tw, th)
	var loops: Array = []
	if host.data.has("outline_loops") and host.data["outline_loops"] is Array:
		loops = host.data["outline_loops"]
	_publish(x0, z0, tw, th, lights, Stamp.COL_FLOOR, solid, sw, sh, n, loops)

static func _publish(
	x0: int,
	z0: int,
	tw: int,
	th: int,
	lights: Array,
	ambient: Color,
	solid: PackedByteArray,
	sw: int,
	sh: int,
	n: int,
	loops: Array = []
) -> void:
	var rt: Variant = load(RT_PATH)
	var iw: int = tw * maxi(1, n)
	var ih: int = th * maxi(1, n)
	var img: Image = rt._img
	if img == null or img.get_width() != iw or img.get_height() != ih:
		img = Image.create(iw, ih, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 1))
	Stamp.paint(img, tw, th, lights, ambient, solid, sw, sh, n, x0, z0, loops)
	rt.origin = Vector2(float(x0), float(z0))
	rt.span = Vector2(float(tw), float(th))
	rt._img = img
	rt._solid = solid
	rt._sw = sw
	rt._sh = sh
	rt._sn = n
	_keep_casts(x0, z0, tw, th, lights)
	# hub lift skipped: warm fill flattened the yard RT
	if rt._gpu == null:
		rt._gpu = ImageTexture.create_from_image(img)
	else:
		rt._gpu.set_image(img)
	HitchLog.mark("light_gpu")
	rt.tex = rt._gpu
	rt._push()
	HitchLog.mark("light_push")

static func _ring_rect(host: Node) -> Rect2i:
	var rt: Variant = load(RT_PATH)
	var stream: GDScript = load("res://scripts/world/dungeon_geo/dungeon_geo_stream.gd") as GDScript
	var pc: Vector2i = Lights._focus(host)
	var origin_cell: Vector2i = stream.chunk_origin(pc)
	var mode := ""
	if App.present:
		mode = str(App.present.get("_mode"))
	var entering: bool = mode == "enter_hold" or mode == "enter_fade" or rt._rect.size.x < 1
	var ring: int = int(stream.RING_IN) if entering else int(stream.RING_OUT)
	var chunk: int = int(stream.CHUNK)
	var map_w: int = int(host.data.w)
	var map_h: int = int(host.data.h)
	var x0: int = origin_cell.x - ring * chunk
	var z0: int = origin_cell.y - ring * chunk
	var x1: int = origin_cell.x + (ring + 1) * chunk
	var z1: int = origin_cell.y + (ring + 1) * chunk
	x0 = clampi(x0, 0, maxi(0, map_w - 1))
	z0 = clampi(z0, 0, maxi(0, map_h - 1))
	x1 = clampi(x1, x0 + 1, map_w)
	z1 = clampi(z1, z0 + 1, map_h)
	var hold: int = chunk
	if rt._rect.size.x >= chunk and rt._rect.size.y >= chunk:
		var hx0: int = rt._rect.position.x
		var hz0: int = rt._rect.position.y
		var hx1: int = hx0 + rt._rect.size.x
		var hz1: int = hz0 + rt._rect.size.y
		if entering:
			return rt._rect
		if pc.x >= hx0 + hold and pc.x < hx1 - hold and pc.y >= hz0 + hold and pc.y < hz1 - hold:
			return rt._rect
	return Rect2i(x0, z0, x1 - x0, z1 - z0)
static func _refill(host: Node) -> void:
	var rt: Variant = load(RT_PATH)
	if rt._bill == null:
		rt._bill = load("res://scripts/graphics/torch_bill.gd") as GDScript
	var stream: GDScript = load("res://scripts/world/dungeon_geo/dungeon_geo_stream.gd") as GDScript
	rt._bill.refill(host, rt._sites, int(stream.CHUNK))

static func _keep_casts(x0: int, z0: int, tw: int, th: int, lights: Array) -> void:
	var rt: Variant = load(RT_PATH)
	rt._casts.clear()
	var x1: float = float(x0 + tw)
	var z1: float = float(z0 + th)
	for src in lights:
		var item: Dictionary = src
		var mx: float = float(item["mx"])
		var mz: float = float(item["mz"])
		if mx < float(x0) or mz < float(z0) or mx >= x1 or mz >= z1:
			continue
		if not Stamp.near_open(rt._solid, rt._sw, rt._sh, rt._sn, mx, mz):
			continue
		var reach: float = float(item["reach"])
		if reach < 0.25:
			continue
		if str(item.get("kind", "")) == "sun":
			continue
		rt._casts.append({
			"xz": Vector2(mx, mz),
			"reach": reach,
			"kind": str(item.get("kind", "")),
		})
