extends Object

## Control skins outside the pause journal: neutral (hub plates, recap, anvil), title (title, news, archives) and
## per-object ones a frame names (crystal). Palettes: ui_tokens.gd SKINS. A host picks its skin with meta
## "btn_skin" or a btn_skin() method (the progress panel asks its active frame: FrameBase.btn_skin). No skin found
## (the pause journal) = the paper look stays. ThemeS.btn / paint_tab / paint_plate call watch(); the control is restyled when it enters the tree (or at once if it already has). Buttons a frame
## dresses itself (UiBuild.button_base) keep their frame look.

const Tok := preload("res://scripts/ui/ui_tokens.gd")

const Face := preload("res://scripts/ui/btn_skin/face.gd")
const Tint := preload("res://scripts/ui/btn_skin/tint.gd")
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
	Tint.tint(n, p)

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
	return Face.box(bg, edge, width, foot, radius)

## Focus ring drawn over the current state: no fill, bright edge and a soft glow, so gamepad focus always reads.
static func ring(p: Dictionary) -> StyleBoxFlat:
	return Face.ring(p)

static var _faces: Dictionary = {}

## Make every skin's button faces once (UiWarm.start), so a menu's first open only hands them out.
static func prewarm() -> void:
	for name: String in Tok.SKINS:
		for role: String in ["secondary", "primary", "danger"]:
			for lit: bool in [false, true]:
				var key: String = name + "|" + role + ("|lit" if lit else "")
				if not _faces.has(key):
					_faces[key] = Face._face(palette(name), role, lit)

## A button face set. lit = the selected tab/option. Boxes are shared per skin, role and lit.
static func button(b: Button, name: String, role: String, lit: bool) -> void:
	var key: String = name + "|" + role + ("|lit" if lit else "")
	if not _faces.has(key):
		_faces[key] = Face._face(palette(name), role, lit)
	_wear(b, _faces[key])

static func _wear(b: Button, f: Dictionary) -> void:
	b.begin_bulk_theme_override()
	for state: String in f["boxes"]:
		b.add_theme_stylebox_override(state, f["boxes"][state])
	for col: String in f["words"]:
		b.add_theme_color_override(col, f["words"][col])
	b.end_bulk_theme_override()

## Gear slot / item cell: the frame's slot face, tinted by rarity, rarity edge when it has one. Shared per look.
static func slot(b: Button, name: String, fill: Color, border: Color, on: bool) -> void:
	var key: String = "slot|%s|%s|%s|%s" % [name, fill.to_html(), border.to_html(), on]
	if not _faces.has(key):
		_faces[key] = Face._slot_face(palette(name), fill, border, on)
	_wear(b, _faces[key])

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
