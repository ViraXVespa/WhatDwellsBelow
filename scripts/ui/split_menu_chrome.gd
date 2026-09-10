extends Object

const ThemeS := preload("res://scripts/ui/theme.gd")

const COL_LIVE := Color(1, 1, 1, 1)
const COL_DIM := Color(0.55, 0.52, 0.48, 1)
const RULE_ON := Color(0.95, 0.78, 0.35, 1)
const RULE_OFF := Color(0.35, 0.28, 0.18, 1)
const GOLD := Color(1, 0.92, 0.45, 1)


static func setup_overlay(host: Node, title_text: String, hint_text: String) -> void:
	host.layer = 62
	host.visible = false
	host.process_mode = Node.PROCESS_MODE_ALWAYS
	var dim := ColorRect.new()
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.color = Color(0.03, 0.02, 0.02, 0.82)
	host.add_child(dim)
	var panel := ColorRect.new()
	panel.color = Color(0.13, 0.1, 0.08, 0.97)
	panel.position = Vector2(160, 70)
	panel.size = Vector2(1600, 940)
	host.add_child(panel)
	var edge := ColorRect.new()
	edge.color = Color(0.55, 0.42, 0.22, 1)
	edge.position = Vector2(160, 70)
	edge.size = Vector2(1600, 8)
	host.add_child(edge)
	var title: Label = ThemeS.lab(title_text, 32, Color(0.95, 0.86, 0.55))
	title.position = Vector2(192, 92)
	title.size = Vector2(700, 48)
	host.add_child(title)
	var hint: Label = ThemeS.lab(hint_text, 18, Color(0.8, 0.76, 0.66))
	hint.position = Vector2(192, 140)
	hint.size = Vector2(520, 36)
	host.add_child(hint)
	host._path = ThemeS.lab("", 18, Color(0.95, 0.86, 0.55))
	host._path.position = Vector2(740, 140)
	host._path.size = Vector2(980, 36)
	host.add_child(host._path)
	_mount_columns(host, host, Vector2(192, 190), Vector2(520, 720), Vector2(740, 190), Vector2(980, 720), Vector2(192, 182), Vector2(740, 182))
	host._chevron = ThemeS.lab(">", 28, GOLD)
	host._chevron.position = Vector2(716, 190)
	host._chevron.size = Vector2(24, 36)
	host._chevron.mouse_filter = Control.MOUSE_FILTER_IGNORE
	host.add_child(host._chevron)
	host.status = ThemeS.lab("", 18, Color(0.95, 0.8, 0.45))
	host.status.position = Vector2(192, 920)
	host.status.size = Vector2(1520, 40)
	host.add_child(host.status)


static func setup_embed(host: Node, parent: Control) -> void:
	host.process_mode = Node.PROCESS_MODE_ALWAYS
	if host is Control:
		var shell: Control = host as Control
		shell.set_anchors_preset(Control.PRESET_FULL_RECT)
		shell.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		shell.size_flags_vertical = Control.SIZE_EXPAND_FILL
	host._path = ThemeS.lab("", 18, Color(0.95, 0.86, 0.55))
	host._path.visible = false
	parent.add_child(host._path)
	host._list_rule = ColorRect.new()
	host._list_rule.color = RULE_ON
	_anchor(host._list_rule, 0.0, 0.29, 0.0, 0.0, 0.0, -8.0, 0.0, 6.0)
	parent.add_child(host._list_rule)
	host._info_rule = ColorRect.new()
	host._info_rule.color = RULE_OFF
	_anchor(host._info_rule, 0.31, 1.0, 0.0, 0.0, 0.0, 0.0, 0.0, 6.0)
	parent.add_child(host._info_rule)
	host._list_root = Control.new()
	host._list_root.mouse_filter = Control.MOUSE_FILTER_STOP
	_anchor(host._list_root, 0.0, 0.29, 0.0, 1.0, 0.0, -8.0, 8.0, 0.0)
	parent.add_child(host._list_root)
	var list_scroll := ScrollContainer.new()
	list_scroll.set_anchors_preset(Control.PRESET_FULL_RECT)
	list_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	list_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_SHOW_NEVER
	host.set_meta("_list_scroll", list_scroll)
	host._list_root.add_child(list_scroll)
	host.list_box = VBoxContainer.new()
	host.list_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	host.list_box.add_theme_constant_override("separation", 10)
	list_scroll.add_child(host.list_box)
	host._info_root = Control.new()
	host._info_root.mouse_filter = Control.MOUSE_FILTER_STOP
	_anchor(host._info_root, 0.31, 1.0, 0.0, 1.0, 0.0, 0.0, 8.0, 0.0)
	parent.add_child(host._info_root)
	var scroll := ScrollContainer.new()
	scroll.set_anchors_preset(Control.PRESET_FULL_RECT)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_SHOW_NEVER
	host.set_meta("_info_scroll", scroll)
	host._info_root.add_child(scroll)
	host.info_box = VBoxContainer.new()
	host.info_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	host.info_box.add_theme_constant_override("separation", 10)
	scroll.add_child(host.info_box)
	host._chevron = ThemeS.lab(">", 28, GOLD)
	host._chevron.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_anchor(host._chevron, 0.29, 0.31, 0.0, 0.0, 0.0, 0.0, 8.0, 44.0)
	parent.add_child(host._chevron)
	host.status = ThemeS.lab("", 16, Color(0.95, 0.8, 0.45))
	host.status.visible = false
	parent.add_child(host.status)
	host.list_btns = []
	host.info_btns = []
	host.back_btn = null


static func _anchor(n: Control, al: float, ar: float, at: float, ab: float, ol: float, oright: float, ot: float, ob: float) -> void:
	n.anchor_left = al
	n.anchor_right = ar
	n.anchor_top = at
	n.anchor_bottom = ab
	n.offset_left = ol
	n.offset_right = oright
	n.offset_top = ot
	n.offset_bottom = ob


static func _mount_columns(host: Node, parent: Node, list_pos: Vector2, list_sz: Vector2, info_pos: Vector2, info_sz: Vector2, list_rule_pos: Vector2, info_rule_pos: Vector2) -> void:
	host._list_rule = ColorRect.new()
	host._list_rule.position = list_rule_pos
	host._list_rule.size = Vector2(list_sz.x, 6)
	host._list_rule.color = RULE_ON
	parent.add_child(host._list_rule)
	host._info_rule = ColorRect.new()
	host._info_rule.position = info_rule_pos
	host._info_rule.size = Vector2(info_sz.x, 6)
	host._info_rule.color = RULE_OFF
	parent.add_child(host._info_rule)
	host._list_root = Control.new()
	host._list_root.position = list_pos
	host._list_root.size = list_sz
	host._list_root.mouse_filter = Control.MOUSE_FILTER_STOP
	parent.add_child(host._list_root)
	var list_scroll := ScrollContainer.new()
	list_scroll.set_anchors_preset(Control.PRESET_FULL_RECT)
	list_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	list_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_SHOW_NEVER
	host.set_meta("_list_scroll", list_scroll)
	host._list_root.add_child(list_scroll)
	host.list_box = VBoxContainer.new()
	host.list_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	host.list_box.add_theme_constant_override("separation", 10)
	list_scroll.add_child(host.list_box)
	host._info_root = Control.new()
	host._info_root.position = info_pos
	host._info_root.size = info_sz
	host._info_root.mouse_filter = Control.MOUSE_FILTER_STOP
	parent.add_child(host._info_root)
	var scroll := ScrollContainer.new()
	scroll.set_anchors_preset(Control.PRESET_FULL_RECT)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_SHOW_NEVER
	host.set_meta("_info_scroll", scroll)
	host._info_root.add_child(scroll)
	host.info_box = VBoxContainer.new()
	host.info_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	host.info_box.add_theme_constant_override("separation", 10)
	scroll.add_child(host.info_box)
	host.list_btns = []
	host.info_btns = []
	host.back_btn = null
