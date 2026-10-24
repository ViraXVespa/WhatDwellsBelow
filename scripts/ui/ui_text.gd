extends Object

const T := preload("res://scripts/data/tunables.gd")
const CliArgs := preload("res://scripts/app/cli_args.gd")

static var _dpr: float = 0.0
## While a fixed-art frame is open (frame skin const TEXT_CAP), new text scales at most this much; 0 = no cap.
static var cap: float = 0.0
## Default theme font size at scale 1 (plain labels, check boxes); internal, not a setting.
const BASE_PX := 16

static func clamp_floor(v: float) -> float:
	return clampf(v, T.UI_TEXT_FLOOR_MIN, T.UI_TEXT_FLOOR_MAX)

static func applied(capped: bool = true) -> float:
	var v: float = App.ui_text_applied() if App.has_method("ui_text_applied") else T.UI_TEXT_SCALE_MIN
	return minf(v, maxf(cap, T.UI_TEXT_SCALE_MIN)) if capped and cap > 0.0 else v

## Body text (up to UI_TEXT_REF) scales by applied(); larger sizes add their extra px unscaled, so headings stay
## above body text without blowing past fixed panels on a phone. Scale 1 (desktop 1080p) returns size.
static func font_px(size: int, capped: bool = true) -> int:
	var s: float = applied(capped)
	var f: float = float(size) * s if float(size) <= T.UI_TEXT_REF else T.UI_TEXT_REF * s + float(size) - T.UI_TEXT_REF
	return maxi(1, int(round(f)))

static func min_size(w: float, h: float) -> Vector2:
	var sc: float = applied()
	return Vector2(w * sc, h * sc)

## Device pixels per CSS px. The web canvas is device pixels, so a phone at devicePixelRatio 3 shows window px at a
## third of their size; the floor is in CSS px. Desktop 1. --wdb-dpr=N (or ?wdb-dpr=N) overrides it for shots.
static func dpr() -> float:
	if _dpr <= 0.0:
		_dpr = CliArgs.float_arg("--wdb-dpr", 0.0)
		if _dpr <= 0.0:
			_dpr = maxf(DisplayServer.screen_get_scale(), 1.0) if OS.has_feature("web") else 1.0
	return _dpr

static func compute(floor_px: float) -> float:
	var win: Vector2i = DisplayServer.window_get_size()
	var vp: Vector2 = _vp_size()
	var sx: float = float(win.x) / maxf(vp.x, 1.0)
	var sy: float = float(win.y) / maxf(vp.y, 1.0)
	var spd: float = minf(sx, sy)
	var design_px: float = T.UI_TEXT_REF * spd
	if design_px <= 0.001:
		return T.UI_TEXT_SCALE_MIN
	return clampf(floor_px * dpr() / design_px, T.UI_TEXT_SCALE_MIN, T.UI_TEXT_SCALE_MAX)

const GROUP := "ui_text_px"

## Set `c`'s font size to font_px(base) and keep it in step when the scale changes (resize, rotation): panels built
## once at boot (pause menu, archives, tips) follow the phone's size too. A later custom size is left alone.
static func track(c: Control, base: int) -> void:
	c.set_meta("ui_base_px", base)
	_set_px(c, font_px(base))
	c.add_to_group(GROUP)

static func _set_px(c: Control, px: int) -> void:
	c.set_meta("ui_px", px)
	c.add_theme_font_size_override("font_size", px)

## New scale: tracked controls follow; controls with no font size override (check boxes, plain labels) read the
## default theme size, so that scales too.
static func refresh() -> void:
	App.ui_text_floor = clamp_floor(float(App.ui_text_floor))
	var was: float = App.ui_text_scale
	App.ui_text_scale = compute(App.ui_text_floor)
	var tree := Engine.get_main_loop() as SceneTree
	if tree and not is_equal_approx(was, App.ui_text_scale):
		for n: Node in tree.get_nodes_in_group(GROUP):
			var c := n as Control
			if c.get_theme_font_size("font_size") == int(c.get_meta("ui_px", -1)):
				_set_px(c, font_px(int(c.get_meta("ui_base_px", 16))))
	var px: int = maxi(1, int(round(float(BASE_PX) * App.ui_text_scale)))
	var th: Theme = ThemeDB.get_default_theme()
	if th != null and th.default_font_size != px:
		th.default_font_size = px
		ThemeDB.fallback_font_size = px

static func _vp_size() -> Vector2:
	var loop := Engine.get_main_loop()
	if loop == null:
		return T.base_size()
	var tree := loop as SceneTree
	if tree == null or tree.root == null:
		return T.base_size()
	return tree.root.get_visible_rect().size

## Shrink a one-line label's font until its text fits `width` (never below `min_px`). Size follows the font override.
static func fit_width(lab: Label, width: float, min_px: int = 14) -> void:
	var font: Font = lab.get_theme_font("font")
	var px: int = lab.get_theme_font_size("font_size")
	while px > min_px and font.get_string_size(lab.text, HORIZONTAL_ALIGNMENT_LEFT, -1, px).x > width:
		px -= 1
	lab.add_theme_font_size_override("font_size", px)
