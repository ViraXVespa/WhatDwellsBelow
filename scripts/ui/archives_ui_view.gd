extends Object

const Docs := preload("res://scripts/data/archives_docs.gd")
const ThemeS := preload("res://scripts/ui/theme.gd")
const PromptView := preload("res://scripts/ui/prompt_view.gd")

const COL_LIVE := Color(1, 1, 1, 1)
const COL_DIM := Color(0.55, 0.52, 0.48, 1)
const RULE_ON := Color(0.95, 0.78, 0.35, 1)
const RULE_OFF := Color(0.35, 0.28, 0.18, 1)
const GOLD := Color(1, 0.92, 0.45, 1)


static func setup(host: Node) -> void:
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
	var title := ThemeS.lab("Archives", 32, Color(0.95, 0.86, 0.55))
	title.position = Vector2(192, 92)
	title.size = Vector2(700, 48)
	host.add_child(title)
	var hint := ThemeS.lab("Standalone snapshots. Title Play always launches the live path.", 18, Color(0.8, 0.76, 0.66))
	hint.position = Vector2(192, 140)
	hint.size = Vector2(520, 36)
	host.add_child(hint)
	host._path = ThemeS.lab("Snapshots", 18, Color(0.95, 0.86, 0.55))
	host._path.position = Vector2(740, 140)
	host._path.size = Vector2(980, 36)
	host.add_child(host._path)
	host._list_rule = ColorRect.new()
	host._list_rule.position = Vector2(192, 182)
	host._list_rule.size = Vector2(520, 6)
	host._list_rule.color = RULE_ON
	host.add_child(host._list_rule)
	host._info_rule = ColorRect.new()
	host._info_rule.position = Vector2(740, 182)
	host._info_rule.size = Vector2(980, 6)
	host._info_rule.color = RULE_OFF
	host.add_child(host._info_rule)
	host._list_root = Control.new()
	host._list_root.position = Vector2(192, 190)
	host._list_root.size = Vector2(520, 720)
	host._list_root.mouse_filter = Control.MOUSE_FILTER_STOP
	host.add_child(host._list_root)
	host.list_box = VBoxContainer.new()
	host.list_box.set_anchors_preset(Control.PRESET_FULL_RECT)
	host.list_box.add_theme_constant_override("separation", 10)
	host._list_root.add_child(host.list_box)
	host._info_root = Control.new()
	host._info_root.position = Vector2(740, 190)
	host._info_root.size = Vector2(980, 720)
	host._info_root.mouse_filter = Control.MOUSE_FILTER_STOP
	host.add_child(host._info_root)
	var scroll := ScrollContainer.new()
	scroll.set_anchors_preset(Control.PRESET_FULL_RECT)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	host._info_root.add_child(scroll)
	host.info_box = VBoxContainer.new()
	host.info_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	host.info_box.add_theme_constant_override("separation", 10)
	scroll.add_child(host.info_box)
	host._chevron = ThemeS.lab(">", 28, GOLD)
	host._chevron.position = Vector2(716, 190)
	host._chevron.size = Vector2(24, 36)
	host._chevron.mouse_filter = Control.MOUSE_FILTER_IGNORE
	host.add_child(host._chevron)
	host.status = ThemeS.lab("", 18, Color(0.95, 0.8, 0.45))
	host.status.position = Vector2(192, 920)
	host.status.size = Vector2(1520, 40)
	host.add_child(host.status)


static func rebuild(host: Node) -> void:
	rebuild_list(host)
	rebuild_info(host)
	apply_col(host)
	host.call_deferred("_focus_col")


static func rebuild_list(host: Node) -> void:
	for c in host.list_box.get_children():
		c.queue_free()
	host.list_btns.clear()
	host.back_btn = null
	var n: int = host.entries.size()
	for i in n:
		var e: Dictionary = host.entries[i]
		var ii: int = i
		var b := ThemeS.btn(str(e.label), func(): host._on_list_pressed(ii))
		b.focus_entered.connect(func(): host._on_list_focus(ii))
		b.mouse_entered.connect(func(): host._on_list_hover(ii))
		host.list_box.add_child(b)
		host.list_btns.append(b)
	host.back_btn = ThemeS.btn("Back", host.hide_browser)
	host.list_box.add_child(host.back_btn)
	paint_list(host)
	var chain: Array = []
	for b in host.list_btns:
		chain.append(b)
	chain.append(host.back_btn)
	wire_vert(chain)


static func rebuild_info(host: Node) -> void:
	for c in host.info_box.get_children():
		c.queue_free()
	host.info_btns.clear()
	var mode: String = str(host.mode)
	if mode == "docs":
		docs_panel(host)
	elif mode == "read":
		read_panel(host)
	else:
		info_panel(host)
	wire_vert(host.info_btns)
	path_text(host)


static func paint_list(host: Node) -> void:
	var selected: int = int(host.selected)
	for i in host.list_btns.size():
		var b: Button = host.list_btns[i]
		if not is_instance_valid(b):
			continue
		if i == selected:
			b.add_theme_color_override("font_color", GOLD)
		else:
			b.remove_theme_color_override("font_color")
	host.call_deferred("_place_chevron")


static func place_chevron(host: Node) -> void:
	if host._chevron == null:
		return
	var y: float = 190.0
	var selected: int = int(host.selected)
	if selected >= 0 and selected < host.list_btns.size() and is_instance_valid(host.list_btns[selected]):
		var b: Button = host.list_btns[selected]
		y = host._list_root.position.y + b.position.y + maxf(b.size.y, 44.0) * 0.5 - 16.0
	host._chevron.position = Vector2(716, y)


static func apply_col(host: Node) -> void:
	var col: String = str(host.col)
	if host._list_root:
		host._list_root.modulate = COL_LIVE if col == "list" else COL_DIM
	if host._info_root:
		host._info_root.modulate = COL_LIVE if col == "detail" else COL_DIM
	if host._list_rule:
		host._list_rule.color = RULE_ON if col == "list" else RULE_OFF
	if host._info_rule:
		host._info_rule.color = RULE_ON if col == "detail" else RULE_OFF
	if host._chevron:
		host._chevron.modulate = GOLD if col == "detail" else Color(0.45, 0.4, 0.3, 1)
	set_col_focus(host)
	hint(host)
	path_text(host)
	host.call_deferred("_place_chevron")


static func set_col_focus(host: Node) -> void:
	var list_on: bool = str(host.col) == "list"
	for b in host.list_btns:
		if is_instance_valid(b):
			(b as Button).focus_mode = Control.FOCUS_ALL if list_on else Control.FOCUS_NONE
	if host.back_btn and is_instance_valid(host.back_btn):
		host.back_btn.focus_mode = Control.FOCUS_ALL if list_on else Control.FOCUS_NONE
	var detail_on: bool = str(host.col) == "detail"
	for b in host.info_btns:
		if not is_instance_valid(b):
			continue
		var btn := b as Button
		if btn.disabled:
			btn.focus_mode = Control.FOCUS_NONE
		else:
			btn.focus_mode = Control.FOCUS_ALL if detail_on else Control.FOCUS_NONE


static func focus_col(host: Node) -> void:
	if not host.open:
		return
	var col: String = str(host.col)
	var selected: int = int(host.selected)
	if col == "list":
		if selected >= 0 and selected < host.list_btns.size() and is_instance_valid(host.list_btns[selected]):
			(host.list_btns[selected] as Button).grab_focus()
		elif host.back_btn and is_instance_valid(host.back_btn):
			host.back_btn.grab_focus()
	else:
		var b := first_enabled_info(host)
		if b:
			b.grab_focus()
	place_chevron(host)


static func first_enabled_info(host: Node) -> Button:
	for b in host.info_btns:
		if b == null or not is_instance_valid(b):
			continue
		var btn := b as Button
		if btn.disabled:
			continue
		return btn
	return null


static func wire_vert(btns: Array) -> void:
	var live: Array = []
	for b in btns:
		if b != null and is_instance_valid(b) and not (b as Button).disabled:
			live.append(b)
	var n: int = live.size()
	if n == 0:
		return
	for i in n:
		var b: Button = live[i]
		var prev: Button = live[n - 1 if i == 0 else i - 1]
		var nxt: Button = live[0 if i == n - 1 else i + 1]
		b.focus_neighbor_top = prev.get_path()
		b.focus_neighbor_bottom = nxt.get_path()
		b.focus_next = nxt.get_path()
		b.focus_previous = prev.get_path()
		b.focus_neighbor_left = b.get_path()
		b.focus_neighbor_right = b.get_path()


static func add_info_btn(host: Node, b: Button) -> void:
	host.info_box.add_child(b)
	host.info_btns.append(b)


static func hint(host: Node) -> void:
	if host is CanvasLayer:
		var extra: Array = []
		var col: String = str(host.col)
		var mode: String = str(host.mode)
		if col == "list":
			extra.append({"action": "ui_accept", "verb": "inspect snapshot", "gap": true})
			extra.append({"action": "ui_cancel", "verb": "close"})
		elif mode == "docs":
			extra.append({"action": "ui_accept", "verb": "open", "gap": true})
			extra.append({"action": "ui_cancel", "verb": "back"})
		elif mode == "read":
			extra.append({"action": "ui_cancel", "verb": "back"})
		else:
			extra.append({"action": "ui_accept", "verb": "use", "gap": true})
			extra.append({"action": "ui_cancel", "verb": "back"})
		PromptView.footer(host as CanvasLayer, extra)


static func path_text(host: Node) -> void:
	if host._path == null:
		return
	var e: Dictionary = host._cur()
	var lab: String = str(e.get("label", "Snapshot"))
	var col: String = str(host.col)
	var mode: String = str(host.mode)
	if col == "list":
		host._path.text = "Snapshots"
	elif mode == "docs":
		host._path.text = "Snapshots  ›  %s  ›  Documents" % lab
	elif mode == "read":
		var docs: PackedStringArray = host._docs_of(e)
		var doc_i: int = int(host.doc_i)
		var name: String = str(docs[doc_i]) if doc_i >= 0 and doc_i < docs.size() else ""
		host._path.text = "Snapshots  ›  %s  ›  %s" % [lab, Docs.display_name(name)]
	else:
		host._path.text = "Snapshots  ›  %s" % lab


static func info_panel(host: Node) -> void:
	var e: Dictionary = host._cur()
	if e.is_empty():
		host.info_box.add_child(ThemeS.lab("No archives.", 22, Color(0.85, 0.7, 0.55)))
		return
	host.info_box.add_child(ThemeS.lab(str(e.label), 28, Color(0.95, 0.86, 0.55)))
	host.info_box.add_child(ThemeS.lab(str(e.desc), 20, Color(0.88, 0.82, 0.72)))
	var docs: PackedStringArray = host._docs_of(e)
	var has_video: bool = str(e.get("video", "")) != ""
	add_info_btn(host, ThemeS.btn("Video", host._on_video, has_video))
	add_info_btn(host, ThemeS.btn("Documents", host._on_docs, docs.size() > 0))
	add_info_btn(host, ThemeS.btn("Play", host._on_play))


static func docs_panel(host: Node) -> void:
	var e: Dictionary = host._cur()
	host.info_box.add_child(ThemeS.lab("%s — Documents" % str(e.label), 26, Color(0.95, 0.86, 0.55)))
	var docs: PackedStringArray = host._docs_of(e)
	if docs.is_empty():
		host.info_box.add_child(ThemeS.lab("No documents for this build.", 20, Color(0.8, 0.74, 0.64)))
	var n: int = docs.size()
	for i in n:
		var ii: int = i
		add_info_btn(host, ThemeS.btn(Docs.display_name(str(docs[i])), func(): host._open_read(ii)))
	add_info_btn(host, ThemeS.btn("Back to info", host._back))


static func read_panel(host: Node) -> void:
	var e: Dictionary = host._cur()
	var docs: PackedStringArray = host._docs_of(e)
	var doc_i: int = int(host.doc_i)
	var name: String = str(docs[doc_i]) if doc_i >= 0 and doc_i < docs.size() else ""
	host.info_box.add_child(ThemeS.lab(Docs.display_name(name), 24, Color(0.95, 0.86, 0.55)))
	host.info_box.add_child(ThemeS.lab(host._read_doc(str(e.get("id", "")), name), 16, Color(0.86, 0.82, 0.74)))
	add_info_btn(host, ThemeS.btn("Back to documents", host._back))
