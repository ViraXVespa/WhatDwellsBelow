extends Object

## Pinned posters on the notice board: flavor scraps, then three offer posters. Text is drawn here, not in the PNG.

const ThemeS: GDScript = preload("res://scripts/ui/theme.gd")
const UiBuild: GDScript = preload("res://scripts/ui/ui_build.gd")
const TipHover: GDScript = preload("res://scripts/ui/tip_hover.gd")
const Art: GDScript = preload("res://scripts/ui/progress_ui/poster_art.gd")
const QuestFrame: GDScript = preload("res://scripts/ui/progress_ui/quest_frame.gd")

const OFFER_SPAN: Vector2 = Vector2(210, 270)

static func seal_key(kind: String) -> String:
	if kind == "kill":
		return "quest_board.seal_kill"
	if kind == "ore":
		return "quest_board.seal_ore"
	if kind == "fetch":
		return "quest_board.seal_fetch"
	return "quest_board.seal_named"

static func rebuild(ui: CanvasLayer) -> void:
	ui._clear()
	TipHover.hide(ui)
	var layer: Control = Control.new()
	layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.clip_contents = true
	layer.custom_minimum_size = QuestFrame.CORK_SIZE
	ui.box.add_child(layer)
	ui.status = ThemeS.lab("", 18, ThemeS.INK, HORIZONTAL_ALIGNMENT_CENTER, true, false)
	ui.status.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ui.status.position = Vector2(16, 4)
	ui.status.size = Vector2(QuestFrame.CORK_SIZE.x - 32.0, 28)
	layer.add_child(ui.status)
	for spot: Dictionary in _flavor():
		_scrap(layer, spot)
	var offers: Array[Button] = []
	var cork_w: float = QuestFrame.CORK_SIZE.x
	var cork_h: float = QuestFrame.CORK_SIZE.y
	var gap: float = 36.0
	var total: float = OFFER_SPAN.x * 3.0 + gap * 2.0
	var x0: float = (cork_w - total) / 2.0
	var y0: float = cork_h - OFFER_SPAN.y - 8.0
	var i: int = 0
	for q: Variant in App.prog.quests_offered:
		if not (q is Dictionary):
			i += 1
			continue
		var idx: int = i
		var offer: Dictionary = q as Dictionary
		var at: Vector2 = Vector2(x0 + float(offers.size()) * (OFFER_SPAN.x + gap), y0)
		var btn: Button = _offer(layer, offer, at, idx, ui)
		offers.append(btn)
		if ui.focus_btn == null:
			ui.focus_btn = btn
		i += 1
	_neighbors(offers)

static func pinned(parent: Control, q: Dictionary, span: Vector2) -> void:
	var paper: TextureRect = UiBuild.picture(Art.tex("poster.png"), CanvasItem.TEXTURE_FILTER_LINEAR)
	paper.position = Vector2.ZERO
	paper.size = span
	parent.add_child(paper)
	_pin(parent, span)
	_seal(parent, str(q.get("kind", "")), span)
	_heading(parent, str(q.get("title", "")), span)

static func paint_tip(ui: CanvasLayer) -> void:
	if not TipHover.live(ui):
		return
	var idx: int = int(ui.tip_id)
	if idx < 0 or idx >= App.prog.quests_offered.size():
		TipHover.hide(ui)
		return
	var raw: Variant = App.prog.quests_offered[idx]
	if not (raw is Dictionary):
		TipHover.hide(ui)
		return
	var q: Dictionary = raw as Dictionary
	ui.tip_lab.text = App.tr("quest_board.tip") % [str(q.get("title", "")), str(q.get("reward", "")), int(q.get("have", 0)), int(q.get("need", 1))]
	ui.tip_lab.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	var from: Control = ui.tip_from
	var above: float = from.get_global_rect().position.y + 1.0
	TipHover.place_below(ui, from, 440.0, 132.0, 8.0, 20.0, 1900.0, above)

static func _flavor() -> Array:
	return [
		{"at": Vector2(18, 40), "turn": -7.0, "span": Vector2(112, 146), "tint": Color(0.96, 0.91, 0.82)},
		{"at": Vector2(150, 48), "turn": 4.0, "span": Vector2(100, 132), "tint": Color(0.9, 0.86, 0.78)},
		{"at": Vector2(280, 36), "turn": -3.0, "span": Vector2(118, 150), "tint": Color(1.0, 0.97, 0.9)},
		{"at": Vector2(430, 52), "turn": 6.0, "span": Vector2(96, 126), "tint": Color(0.93, 0.88, 0.76)},
		{"at": Vector2(560, 40), "turn": -5.0, "span": Vector2(110, 140), "tint": Color(0.97, 0.93, 0.84)},
		{"at": Vector2(700, 56), "turn": 3.0, "span": Vector2(104, 134), "tint": Color(0.88, 0.84, 0.74)},
		{"at": Vector2(820, 38), "turn": -4.0, "span": Vector2(116, 148), "tint": Color(0.98, 0.94, 0.86)},
		{"at": Vector2(940, 50), "turn": 5.0, "span": Vector2(92, 120), "tint": Color(0.92, 0.87, 0.78)},
	]

static func _scrap(layer: Control, spot: Dictionary) -> void:
	var span: Vector2 = spot["span"]
	var scrap: Control = Control.new()
	scrap.mouse_filter = Control.MOUSE_FILTER_IGNORE
	scrap.position = spot["at"]
	scrap.size = span
	scrap.pivot_offset = span * 0.5
	scrap.rotation = deg_to_rad(float(spot["turn"]))
	layer.add_child(scrap)
	var paper: TextureRect = UiBuild.picture(Art.tex("poster.png"), CanvasItem.TEXTURE_FILTER_LINEAR)
	paper.modulate = spot["tint"]
	paper.size = span
	scrap.add_child(paper)
	_pin(scrap, span)

static func _offer(layer: Control, q: Dictionary, at: Vector2, idx: int, ui: CanvasLayer) -> Button:
	var btn: Button = Button.new()
	btn.focus_mode = Control.FOCUS_ALL
	btn.position = at
	btn.size = OFFER_SPAN
	btn.custom_minimum_size = OFFER_SPAN
	btn.text = ""
	btn.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	UiBuild.button_base(btn)
	var face: StyleBoxTexture = UiBuild.tex_box(Art.tex("poster.png"), 28, 40, 28, false, 16, 16)
	face.content_margin_top = 8
	UiBuild.states(btn, face, face, face, face, face)
	btn.set_meta("quest_poster", true)
	layer.add_child(btn)
	_pin(btn, OFFER_SPAN)
	_seal(btn, str(q.get("kind", "")), OFFER_SPAN)
	_heading(btn, str(q.get("title", "")), OFFER_SPAN)
	var ring: Panel = _ring()
	btn.add_child(ring)
	TipHover.attach(btn, ui, str(idx), "quest", paint_tip, func(ctrl: Control, on: bool) -> void:
		var mark: Control = ctrl.get_node_or_null("ring") as Control
		if mark:
			mark.visible = on
	)
	btn.pressed.connect(func() -> void:
		var msg: String = App.prog.accept_quest(idx)
		ui._rebuild_quest()
		ui._st(msg)
		ui._show()
	)
	return btn

static func _neighbors(offers: Array[Button]) -> void:
	var n: int = offers.size()
	if n == 0:
		return
	for i: int in n:
		var btn: Button = offers[i]
		var prev: Button = offers[(i + n - 1) % n]
		var nxt: Button = offers[(i + 1) % n]
		btn.focus_neighbor_left = prev.get_path()
		btn.focus_neighbor_right = nxt.get_path()
		btn.focus_neighbor_top = btn.get_path()
		btn.focus_neighbor_bottom = btn.get_path()

static func _pin(parent: Control, span: Vector2) -> void:
	var pin: TextureRect = UiBuild.picture(Art.tex("pin.png"), CanvasItem.TEXTURE_FILTER_LINEAR)
	pin.size = Vector2(32, 32)
	pin.position = Vector2(span.x * 0.5 - 16.0, 2)
	parent.add_child(pin)

static func _seal(parent: Control, kind: String, span: Vector2) -> void:
	var seal: Panel = Panel.new()
	seal.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var box: StyleBoxFlat = StyleBoxFlat.new()
	box.bg_color = _seal_color(kind)
	box.corner_radius_top_left = _seal_radius(kind)
	box.corner_radius_top_right = _seal_radius(kind)
	box.corner_radius_bottom_left = _seal_radius(kind)
	box.corner_radius_bottom_right = _seal_radius(kind)
	seal.add_theme_stylebox_override("panel", box)
	seal.position = Vector2(span.x * 0.5 - 40.0, 28)
	seal.size = Vector2(80, 30)
	parent.add_child(seal)
	var word: Label = ThemeS.lab(App.tr(seal_key(kind)), 14, ThemeS.PAPER, HORIZONTAL_ALIGNMENT_CENTER, false, false)
	word.mouse_filter = Control.MOUSE_FILTER_IGNORE
	word.position = Vector2(0, 4)
	word.size = Vector2(80, 22)
	seal.add_child(word)

static func _heading(parent: Control, heading: String, span: Vector2) -> void:
	var lab: Label = ThemeS.lab(heading, 20, ThemeS.INK, HORIZONTAL_ALIGNMENT_CENTER, true, false)
	lab.mouse_filter = Control.MOUSE_FILTER_IGNORE
	lab.position = Vector2(16, 68)
	lab.size = Vector2(span.x - 32.0, span.y - 84.0)
	parent.add_child(lab)

static func _ring() -> Panel:
	var ring: Panel = Panel.new()
	ring.name = "ring"
	ring.visible = false
	ring.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ring.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var edge: StyleBoxFlat = StyleBoxFlat.new()
	edge.bg_color = Color(0, 0, 0, 0)
	edge.border_color = Color(0.93, 0.78, 0.38)
	edge.set_border_width_all(4)
	ring.add_theme_stylebox_override("panel", edge)
	return ring

static func _seal_color(kind: String) -> Color:
	if kind == "kill":
		return Color(0.45, 0.16, 0.13)
	if kind == "ore":
		return Color(0.5, 0.36, 0.12)
	if kind == "fetch":
		return Color(0.16, 0.32, 0.38)
	return Color(0.32, 0.16, 0.4)

static func _seal_radius(kind: String) -> int:
	if kind == "kill":
		return 15
	if kind == "ore":
		return 4
	if kind == "fetch":
		return 0
	return 12
