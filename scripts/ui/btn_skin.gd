extends Object

## Control skins outside the pause journal: neutral (hub plates, recap, anvil), title (title, news, archives) and
## per-object ones a frame names (crystal). Palettes: ui_tokens.gd SKINS. A host picks its skin with meta
## "btn_skin" or a btn_skin() method (the progress panel asks its active frame: FrameBase.btn_skin). No skin found
## (the pause journal) = the paper look stays. ThemeS.btn / paint_tab / paint_plate call watch(); the control is restyled when it enters the tree (or at once if it already has). Buttons a frame
## dresses itself (UiBuild.button_base) keep their frame look.

const Tok := preload("res://scripts/ui/ui_tokens.gd")

static func watch(c: Control, kind: String, data: Array = []) -> void:
	c.set_meta("skin_kind", kind)
	c.set_meta("skin_data", data)
	if c.is_inside_tree():
		restyle(c)
	elif not c.has_meta("skin_wait"):
		c.set_meta("skin_wait", true)
		c.ready.connect(restyle.bind(c), CONNECT_ONE_SHOT)

## Skins with "words"/"panel" (title) also recolour ink labels and cream plates: the host calls follow(self) before
## it builds, and every Label / ColorRect that enters the tree under it is recoloured.
## follow(host, false) stops it (a host that stays alive while hidden); leaving the tree stops it too.
static func follow(host: Node, on: bool = true) -> void:
	if on:
		_track(host, palette(str(host.get_meta("btn_skin", ""))))
	else:
		_untrack(host)

## Roots whose new descendants get tinted: one node_added listener for all (bound copies of one method would
## count as one connection), freed roots drop out.
static var _roots: Dictionary = {}

static func _track(root: Node, p: Dictionary) -> void:
	_roots[root] = p
	var sig: Signal = root.get_tree().node_added
	if not sig.is_connected(_added):
		sig.connect(_added)

static func _added(n: Node) -> void:
	for root: Variant in _roots.keys():
		if not is_instance_valid(root):
			_roots.erase(root)
		elif (root as Node).is_ancestor_of(n):
			tint(n, _roots[root])
			return

## Ink words, cream plates and rules on one node -> the skin's panel colours.
static func tint(n: Node, p: Dictionary) -> void:
	var inks: Array = [Tok.INK, Tok.INK_SOFT, Tok.INK_FAINT]
	if n is RichTextLabel or n is Label:
		var key: String = "default_color" if n is RichTextLabel else "font_color"
		var src: Color = n.get_meta("ink_src", (n as Control).get_theme_color(key))
		n.set_meta("ink_src", src)
		if src.is_equal_approx(Tok.DANGER):
			(n as Control).add_theme_color_override(key, p["danger_word"])
		for i: int in inks.size():
			if src.is_equal_approx(inks[i]):
				(n as Control).add_theme_color_override(key, p["words"][i])
	elif n is ColorRect:
		var r := n as ColorRect
		var src: Color = r.get_meta("ink_src", r.color)
		r.set_meta("ink_src", src)
		if Color(src, 1.0).is_equal_approx(Color(Tok.PAPER, 1.0)):
			r.color = p["panel"]
		elif src.is_equal_approx(Tok.RULE):
			r.color = p["panel_edge"]
	elif n is TextureRect and n.has_meta("paper_tex"):
		(n as TextureRect).visible = false

## Scroll bars in the skin: a quiet track, the edge colour for the thumb, the bright edge when hovered/dragged.
static func scroll(sc: ScrollContainer, name: String, p: Dictionary) -> void:
	var key: String = "bar|" + name
	if not _faces.has(key):
		var track: StyleBoxFlat = box(Color(p["panel"].r, p["panel"].g, p["panel"].b, 0.35), Color(0, 0, 0, 0), 0, 0, 3)
		track.set_content_margin_all(0)
		var thumb: StyleBoxFlat = box(p["edge"], Color(0, 0, 0, 0), 0, 0, 3)
		thumb.set_content_margin_all(5)
		var lit: StyleBoxFlat = box(p["edge_hi"], Color(0, 0, 0, 0), 0, 0, 3)
		lit.set_content_margin_all(5)
		_faces[key] = {"scroll": track, "scroll_focus": track, "grabber": thumb, "grabber_highlight": lit, "grabber_pressed": lit}
	for bar: ScrollBar in [sc.get_v_scroll_bar(), sc.get_h_scroll_bar()]:
		bar.begin_bulk_theme_override()
		for state: String in _faces[key]:
			bar.add_theme_stylebox_override(state, _faces[key][state])
		bar.end_bulk_theme_override()

## A popup (tooltip, picker, confirm) under a skinned host: skin face, and every ink label in it (now and later)
## takes the skin's panel words. No skin = paper stays (journal).
static func pop(c: Control, name: String, p: Dictionary) -> void:
	if c is PanelContainer:
		var key: String = "pop|" + name
		if not _faces.has(key):
			var s: StyleBoxFlat = box(p["panel"], p["panel_edge"], 2, 2, int(p["radius"]))
			s.shadow_color = Color(0, 0, 0, 0.45)
			s.shadow_size = 6
			_faces[key] = s
		c.add_theme_stylebox_override("panel", _faces[key])
	tint_tree(c, p)

static func tint_tree(root: Node, p: Dictionary) -> void:
	tint(root, p)
	for n: Node in root.find_children("*", "", true, false):
		tint(n, p)
	if root.has_meta("skin_static"):
		return
	_track(root, p)
	if not root.has_meta("skin_untrack"):
		root.set_meta("skin_untrack", true)
		root.tree_exiting.connect(_untrack.bind(root))

static func _untrack(root: Node) -> void:
	_roots.erase(root)

## The skin name for a control: the nearest ancestor that names one, else "".
static func skin_of(c: Node) -> String:
	var n: Node = c.get_parent()
	while n != null:
		if n.has_meta("btn_skin"):
			return str(n.get_meta("btn_skin"))
		if n.has_method("btn_skin"):
			return str(n.call("btn_skin"))
		n = n.get_parent()
	return ""

static func palette(name: String) -> Dictionary:
	if name == "":
		return {}
	assert(Tok.SKINS.has(name), "unknown control skin " + name)
	return Tok.SKINS.get(name, {})

static func restyle(c: Control) -> void:
	if not is_instance_valid(c):
		return
	var name: String = skin_of(c)
	var p: Dictionary = palette(name)
	if p.is_empty():
		return
	var kind: String = str(c.get_meta("skin_kind", ""))
	var data: Array = c.get_meta("skin_data", [])
	match kind:
		"btn":
			if not c.has_meta("frame_dressed"):
				button(c as Button, name, str(data[0]) if data.size() > 0 else "secondary", false)
		"tab":
			button(c as Button, name, str(data[1]) if data.size() > 1 else "secondary", bool(data[0]))
		"panel":
			pop(c, name, p)
		"scroll":
			scroll(c as ScrollContainer, name, p)
		"card":
			card(c as PanelContainer, p, data)
		"plate":
			slot(c as Button, name, data[0], data[1], bool(data[2]))

static func box(bg: Color, edge: Color, width: int, foot: int, radius: int) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = bg
	s.border_color = edge
	s.set_border_width_all(width)
	s.border_width_bottom = foot
	s.set_corner_radius_all(radius)
	s.anti_aliasing = false
	s.content_margin_left = 14
	s.content_margin_right = 14
	s.content_margin_top = 6
	s.content_margin_bottom = 6
	return s

## Focus ring drawn over the current state: no fill, bright edge and a soft glow, so gamepad focus always reads.
static func ring(p: Dictionary) -> StyleBoxFlat:
	var w: int = int(p.get("ring", 2))
	var s: StyleBoxFlat = box(Color(0, 0, 0, 0), p["glow"], w, w, int(p["radius"]))
	s.draw_center = false
	s.shadow_color = Color(p["glow"].r, p["glow"].g, p["glow"].b, 0.55)
	s.shadow_size = 5
	s.expand_margin_left = 2
	s.expand_margin_right = 2
	s.expand_margin_top = 2
	s.expand_margin_bottom = 2
	return s

static var _faces: Dictionary = {}

## Make every skin's button faces once (UiWarm.start), so a menu's first open only hands them out.
static func prewarm() -> void:
	for name: String in Tok.SKINS:
		for role: String in ["secondary", "primary", "danger"]:
			for lit: bool in [false, true]:
				var key: String = name + "|" + role + ("|lit" if lit else "")
				if not _faces.has(key):
					_faces[key] = _face(palette(name), role, lit)

## A button face set. lit = the selected tab/option. Boxes are shared per skin, role and lit.
static func button(b: Button, name: String, role: String, lit: bool) -> void:
	var key: String = name + "|" + role + ("|lit" if lit else "")
	if not _faces.has(key):
		_faces[key] = _face(palette(name), role, lit)
	_wear(b, _faces[key])

static func _wear(b: Button, f: Dictionary) -> void:
	b.begin_bulk_theme_override()
	for state: String in f["boxes"]:
		b.add_theme_stylebox_override(state, f["boxes"][state])
	for col: String in f["words"]:
		b.add_theme_color_override(col, f["words"][col])
	b.end_bulk_theme_override()

static func _face(p: Dictionary, role: String, lit: bool) -> Dictionary:
	var r: int = int(p["radius"])
	var fill: Color = p["primary_fill"] if role == "primary" else p["fill"]
	var edge: Color = p["primary_edge"] if role == "primary" else p["edge"]
	var word: Color = p["word"]
	if role == "danger":
		edge = p["danger_edge"]
		word = p["danger_word"]
	if lit:
		fill = p["primary_fill"]
		edge = p["glow"]
		word = p["word_hi"]
	var normal: StyleBoxFlat = box(fill, edge, 2 if lit else 1, 4 if lit else 3, r)
	normal.shadow_color = Color(0, 0, 0, 0.35)
	normal.shadow_size = 2
	normal.shadow_offset = Vector2(0, 2)
	var hover: StyleBoxFlat = box(p["hover"], p["edge_hi"], 1, 3, r)
	var press: StyleBoxFlat = box(p["press"], p["edge_hi"], 1, 1, r)
	press.content_margin_top = 8
	press.content_margin_bottom = 4
	var off: StyleBoxFlat = box(p["off"], p["edge_off"], 1, 1, r)
	return {
		"boxes": {"normal": normal, "hover": hover, "pressed": press, "hover_pressed": press, "focus": ring(p), "disabled": off},
		"words": {"font_color": word, "font_hover_color": p["word_hi"], "font_focus_color": p["word_hi"],
			"font_pressed_color": p["word_hi"], "font_hover_pressed_color": p["word_hi"], "font_disabled_color": p["word_off"]},
	}

## Gear slot / item cell: the frame's slot face, tinted by rarity, rarity edge when it has one. Shared per look.
static func slot(b: Button, name: String, fill: Color, border: Color, on: bool) -> void:
	var key: String = "slot|%s|%s|%s|%s" % [name, fill.to_html(), border.to_html(), on]
	if not _faces.has(key):
		_faces[key] = _slot_face(palette(name), fill, border, on)
	_wear(b, _faces[key])

static func _slot_face(p: Dictionary, fill: Color, border: Color, on: bool) -> Dictionary:
	var r: int = int(p["radius"])
	var face: Color = p["slot"]
	if fill.a > 0.05 and (fill.r + fill.g + fill.b) < 2.7:
		face = face.lerp(Color(fill.r, fill.g, fill.b, face.a), 0.30)
	var edge: Color = border if border.a > 0.4 else p["slot_edge"]
	var se: Color = p["slot_edge"]
	return {
		"boxes": {
			"normal": box(face, p["glow"] if on else edge, 2 if on else 1, 3 if on else 2, r),
			"hover": box(face.lightened(0.12), p["edge_hi"], 1, 2, r),
			"pressed": box(face.darkened(0.12), p["edge_hi"], 1, 1, r),
			"focus": ring(p),
			"disabled": box(Color(face.r, face.g, face.b, 0.22), Color(se.r, se.g, se.b, 0.35), 1, 1, r),
		},
		"words": {"font_color": Tok.INK, "font_hover_color": Tok.INK, "font_focus_color": Tok.INK},
	}

## Stats card (gear board "Bonuses" pager) on a host frame: the skin's button face as panel, its words for text.
static func card(panel: PanelContainer, p: Dictionary, labels: Array) -> void:
	var key: String = "card|%s" % p["fill"].to_html()
	if not _faces.has(key):
		var s: StyleBoxFlat = box(p["fill"], p["edge"], 1, 2, int(p["radius"]))
		s.content_margin_left = 10
		s.content_margin_right = 10
		_faces[key] = s
	panel.add_theme_stylebox_override("panel", _faces[key])
	for i: int in labels.size():
		var l: Label = labels[i]
		if is_instance_valid(l):
			l.add_theme_color_override("font_color", p["word_hi"] if i == 0 else p["word"])

## Panel box for a skin with a panel colour (title card).
static func panel_box(name: String) -> StyleBoxFlat:
	var p: Dictionary = palette(name)
	var s: StyleBoxFlat = box(p["panel"], p["panel_edge"], 2, 2, int(p["radius"]) + 2)
	s.shadow_color = Color(0, 0, 0, 0.55)
	s.shadow_size = 10
	return s
