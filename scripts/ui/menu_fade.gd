extends Object

## Menu transitions (Settings > UI > Menu transitions; saved as menu_fx). A menu CanvasLayer fades in over IN_SEC
## when it opens and out over OUT_SEC when it closes, through one CanvasModulate child, so the layer's own dims and
## child modulates (map opacity, tips) stay theirs. A closing layer stays drawn while it fades but is
## PROCESS_MODE_DISABLED: no _input, no clicks, no ui_accept reach it once it is closed, and gameplay has the pad
## from the close frame on. Opening again mid-fade picks up from the current alpha. Off: open and close are instant.
## Overlay Controls (confirm slip, title news) only fade in: pop_in.

const IN_SEC := 0.15
const OUT_SEC := 0.12
const NODE := "menu_fade"
const TWEEN := "menu_fade_tween"
const GHOST := "menu_fade_pm"

## The menu_fx pref lives on App (saved with the other prefs); this proxies it for menu code.
static var enabled: bool:
	get:
		return bool(App.menu_fx)
	set(v):
		App.menu_fx = v

static func fade_in(layer: CanvasLayer) -> void:
	var from: float = 0.0
	if layer.has_meta(GHOST):
		from = _mod(layer).color.a
	_stop(layer)
	_resume(layer)
	var m: CanvasModulate = _mod(layer)
	if not enabled or not layer.is_inside_tree():
		m.color = Color.WHITE
		return
	m.color = Color(1, 1, 1, from)
	var tw: Tween = _tween(layer)
	tw.tween_property(m, "color:a", 1.0, IN_SEC * (1.0 - from)).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)

## Call after the layer is logically closed (open false, visible false). free_after: queue_free at the end.
static func fade_out(layer: CanvasLayer, free_after: bool = false) -> void:
	_stop(layer)
	var m: CanvasModulate = layer.get_node_or_null(NODE) as CanvasModulate
	if not enabled or m == null or not layer.is_inside_tree() or m.color.a <= 0.02:
		_settle(layer, free_after)
		return
	if not layer.has_meta(GHOST):
		layer.set_meta(GHOST, layer.process_mode)
	layer.process_mode = Node.PROCESS_MODE_DISABLED
	# Hide first (a no-op when the caller already did): a Back chip whose tap closed the menu lets its action go
	# on hide (prompt_chip.gd), so nothing stays held while the ghost fades.
	layer.visible = false
	layer.visible = true
	var tw: Tween = _tween(layer)
	tw.tween_property(m, "color:a", 0.0, OUT_SEC * m.color.a).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	tw.tween_callback(_settle.bind(layer, free_after))

## True while a closed layer is still fading out (drawn, takes no input).
static func ghosting(layer: CanvasLayer) -> bool:
	return layer != null and layer.has_meta(GHOST)

## Fade an overlay Control in (confirm slip, title news). Closing it stays instant (it is freed).
static func pop_in(c: Control) -> void:
	if not enabled or not c.is_inside_tree():
		return
	c.modulate.a = 0.0
	var tw: Tween = c.get_tree().create_tween()
	tw.bind_node(c)
	tw.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	tw.set_ignore_time_scale(true)
	tw.tween_property(c, "modulate:a", 1.0, IN_SEC).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)

static func _settle(layer: CanvasLayer, free_after: bool) -> void:
	if not is_instance_valid(layer):
		return
	_resume(layer)
	if layer.has_meta(TWEEN):
		layer.remove_meta(TWEEN)
	layer.visible = false
	var m: CanvasModulate = layer.get_node_or_null(NODE) as CanvasModulate
	if m:
		m.color = Color.WHITE
	if free_after:
		layer.queue_free()

static func _resume(layer: CanvasLayer) -> void:
	if layer.has_meta(GHOST):
		layer.process_mode = int(layer.get_meta(GHOST)) as Node.ProcessMode
		layer.remove_meta(GHOST)

static func _stop(layer: CanvasLayer) -> void:
	if not layer.has_meta(TWEEN):
		return
	var old: Variant = layer.get_meta(TWEEN)
	if old is Tween and (old as Tween).is_valid():
		(old as Tween).kill()
	layer.remove_meta(TWEEN)

static func _tween(layer: CanvasLayer) -> Tween:
	var tw: Tween = layer.get_tree().create_tween()
	tw.bind_node(layer)
	tw.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	tw.set_ignore_time_scale(true)
	layer.set_meta(TWEEN, tw)
	return tw

static func _mod(layer: CanvasLayer) -> CanvasModulate:
	var m: CanvasModulate = layer.get_node_or_null(NODE) as CanvasModulate
	if m == null:
		m = CanvasModulate.new()
		m.name = NODE
		layer.add_child(m)
	return m
