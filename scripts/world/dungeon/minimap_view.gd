extends Object

## Minimap / full-map view math and sync (split from minimap.gd). Region, zoom-to-fit and opacity.

const T := preload("res://scripts/data/tunables.gd")
const Marks := preload("res://scripts/world/dungeon/map_marks.gd")

static func _map() -> GDScript:
	return load("res://scripts/world/dungeon/minimap.gd") as GDScript

## Cells of map per cell of view. 1 shows the whole floor. No upper cap; callers clamp.
static func reveal_zoom(host: Node) -> float:
	if host == null or host.get("data") == null:
		return 1.0
	var lo: Vector2i = host.map_seen_min
	var hi: Vector2i = host.map_seen_max
	if lo.x < 0:
		return 1.0
	var w: float = maxf(float(host.data.w), 1.0)
	var h: float = maxf(float(host.data.h), 1.0)
	var rw: float = float(hi.x - lo.x + 1)
	var rh: float = float(hi.y - lo.y + 1)
	return minf(w / maxf(rw, 1.0), h / maxf(rh, 1.0))

## Cell-space center of the revealed bounds, or (-1, -1) when nothing is revealed.
static func seen_center(host: Node) -> Vector2:
	var lo: Vector2i = host.map_seen_min
	var hi: Vector2i = host.map_seen_max
	if lo.x < 0:
		return Vector2(-1.0, -1.0)
	var cx: float = (float(lo.x) + float(hi.x) + 1.0) * 0.5
	var cy: float = (float(lo.y) + float(hi.y) + 1.0) * 0.5
	return Vector2(cx, cy)

static func full_alpha() -> float:
	if bool(App.full_map_opacity):
		return clampf(float(App.mini_opacity), 0.0, 1.0)
	return 1.0

static func mini_region(host: Node) -> Rect2:
	var configured: float = clampf(float(App.mini_zoom), T.MINI_ZOOM_MIN, T.MINI_ZOOM_MAX)
	var zoom: float = configured
	var center: Vector2 = _player_uv(host)
	if bool(App.mini_zoom_fit):
		var fit: float = reveal_zoom(host)
		if fit >= configured and host.get("data") != null:
			zoom = minf(fit, T.MINI_ZOOM_MAX)
			var seen: Vector2 = seen_center(host)
			if seen.x >= 0.0:
				var w: float = maxf(float(host.data.w), 1.0)
				var h: float = maxf(float(host.data.h), 1.0)
				center = Vector2(seen.x / w, seen.y / h)
	zoom = maxf(zoom, 1.0)
	var span: float = 1.0 / zoom
	var origin: Vector2 = Vector2(center.x - span * 0.5, center.y - span * 0.5)
	origin.x = clampf(origin.x, 0.0, 1.0 - span)
	origin.y = clampf(origin.y, 0.0, 1.0 - span)
	return Rect2(origin, Vector2(span, span))

static func sync_views(host: Node) -> void:
	var full: bool = str(host.get("map_state")) == "full"
	var layer: CanvasLayer = host.get("map_layer") as CanvasLayer
	if layer:
		layer.visible = full
	var hud: CanvasLayer = host.get("hud") as CanvasLayer
	var map_view: TextureRect = null
	if hud != null:
		map_view = hud.get("mini_map") as TextureRect
	if map_view != null:
		var View: GDScript = load("res://scripts/ui/hud/hud_view.gd") as GDScript
		View.layout(hud)
		var region: Rect2 = mini_region(host)
		_map().attach(host, map_view, region)
		Marks.bind(host, map_view, region)
		var shell: Control = hud.get("mini_wrap") as Control
		if shell:
			shell.visible = str(host.get("map_state")) == "mini"
	var alpha: float = full_alpha()
	var rect: TextureRect = host.get("map_rect") as TextureRect
	if rect:
		rect.modulate.a = alpha
	var edge: ColorRect = host.get("map_border") as ColorRect
	if edge:
		edge.modulate.a = alpha

static func _player_uv(host: Node) -> Vector2:
	var w: float = 1.0
	var h: float = 1.0
	if host.get("data") != null:
		w = maxf(float(host.data.w), 1.0)
		h = maxf(float(host.data.h), 1.0)
	var cell: Vector2i = host.get_meta("map_pc", Vector2i(-999, -999))
	if cell.x < 0 and host.player:
		cell = Vector2i(int(host.player.global_position.x), int(host.player.global_position.z))
	if cell.x < 0:
		return Vector2(0.5, 0.5)
	return Vector2((float(cell.x) + 0.5) / w, (float(cell.y) + 0.5) / h)
