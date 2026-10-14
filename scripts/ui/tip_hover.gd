extends Object

## The focus/hover tooltip helper (pause Skills tab, recap skill bars; new posters, shop and consumable icons).
## The host declares tip_host, tip_lab (ScrollBox.make_tip builds them), tip_id, tip_kind, tip_from and a
## `_blur_tip()` that calls TipHover.blur. Focus or hover shows the tip, blur or mouse-out hides it a frame later
## unless focus moved to another control carrying keep_meta. Each caller keeps its own paint (text and place).
## The gear board keeps its own tip (gear_board/tip.gd: pad selection, flyouts, restore) for now.

## Wire one control: focus/hover -> show, blur/mouse-out -> deferred host._blur_tip(). hl(ctrl, on) restyles the
## control on focus and blur (optional).
static func attach(ctrl: Control, host: Node, id: String, kind: String, paint: Callable, hl: Callable = Callable()) -> void:
	var on: Callable = func():
		if hl.is_valid():
			hl.call(ctrl, true)
		show(host, id, kind, ctrl, paint)
	var off: Callable = func():
		if hl.is_valid() and not ctrl.has_focus():
			hl.call(ctrl, false)
		host.call_deferred("_blur_tip")
	ctrl.focus_entered.connect(on)
	ctrl.mouse_entered.connect(on)
	ctrl.focus_exited.connect(off)
	ctrl.mouse_exited.connect(off)

static func show(host: Node, id: String, kind: String, from: Control, paint: Callable) -> void:
	host.tip_id = id
	host.tip_kind = kind
	host.tip_from = from
	paint.call(host)

## Deferred blur: keep the tip while focus sits on another control with keep_meta.
static func blur(host: Node, keep_meta: String) -> void:
	var f: Control = host.get_viewport().gui_get_focus_owner()
	if f != null and keep_meta != "" and f.has_meta(keep_meta):
		return
	hide(host)

static func clear(host: Node) -> void:
	host.tip_id = ""
	host.tip_kind = ""
	host.tip_from = null

static func hide(host: Node) -> void:
	clear(host)
	if host.tip_host:
		host.tip_host.visible = false

## True when there is something to paint; hides the panel otherwise.
static func live(host: Node) -> bool:
	if host.tip_id == "" or host.tip_from == null or not is_instance_valid(host.tip_from) or host.tip_lab == null:
		if host.tip_host:
			host.tip_host.visible = false
		return false
	return true

## Place tip_host (w x h) under `from`, flipped above when it would pass max_y, kept inside [min_x, max_x].
static func place_below(host: Node, from: Control, w: float, h: float, gap: float = 8.0, min_x: float = 20.0,
		max_x: float = 1900.0, max_y: float = 1060.0) -> void:
	var r: Rect2 = from.get_global_rect()
	var pos := Vector2(r.position.x, r.position.y + r.size.y + gap)
	if pos.y + h > max_y:
		pos.y = r.position.y - h - gap
	if pos.x + w > max_x:
		pos.x = max_x - w
	if pos.x < min_x:
		pos.x = min_x
	host.tip_host.size = Vector2(w, h)
	host.tip_host.position = pos
	host.tip_host.visible = true
