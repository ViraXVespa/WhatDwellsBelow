extends Object

const Docs := preload("res://scripts/data/archives_docs.gd")
const ThemeS := preload("res://scripts/ui/theme.gd")
const PromptView := preload("res://scripts/ui/prompt_view.gd")
const SplitView := preload("res://scripts/ui/split_menu_view.gd")


static func rebuild(host: Node) -> void:
	SplitView.rebuild_list(host)
	rebuild_info(host)
	apply_col(host)
	host.call_deferred("_focus_col")


static func rebuild_list(host: Node) -> void:
	SplitView.rebuild_list(host)


static func rebuild_info(host: Node) -> void:
	for c: Node in host.info_box.get_children():
		c.queue_free()
	host.info_btns.clear()
	var mode: String = str(host.mode)
	if mode == "docs":
		docs_panel(host)
	elif mode == "read":
		read_panel(host)
	else:
		info_panel(host)
	SplitView.wire_vert(host.info_btns)
	path_text(host)


static func paint_list(host: Node) -> void:
	SplitView.paint_list(host)


static func place_chevron(host: Node) -> void:
	SplitView.place_chevron(host)


static func apply_col(host: Node) -> void:
	SplitView.apply_col(host)
	hint(host)
	path_text(host)


static func set_col_focus(host: Node) -> void:
	SplitView.set_col_focus(host)


static func focus_col(host: Node) -> void:
	SplitView.focus_col(host)


static func first_enabled_info(host: Node) -> Button:
	return SplitView.first_enabled_info(host)


static func wire_vert(btns: Array) -> void:
	SplitView.wire_vert(btns)


static func add_info_btn(host: Node, b: Button) -> void:
	host.info_box.add_child(b)
	host.info_btns.append(b)


static func hint(host: Node) -> void:
	if not (host is CanvasLayer):
		return
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
	if host.has_method("split_path_text"):
		host._path.text = str(host.split_path_text())
		return
	host._path.text = "Snapshots"


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
	for i: int in n:
		var ii: int = i
		add_info_btn(host, ThemeS.btn(Docs.display_name(str(docs[i])), func() -> void: host._open_read(ii)))
	add_info_btn(host, ThemeS.btn("Back to info", host._back))


static func read_panel(host: Node) -> void:
	var e: Dictionary = host._cur()
	var docs: PackedStringArray = host._docs_of(e)
	var doc_i: int = int(host.doc_i)
	var name: String = str(docs[doc_i]) if doc_i >= 0 and doc_i < docs.size() else ""
	host.info_box.add_child(ThemeS.lab(Docs.display_name(name), 24, Color(0.95, 0.86, 0.55)))
	host.info_box.add_child(ThemeS.lab(host._read_doc(str(e.get("id", "")), name), 16, Color(0.86, 0.82, 0.74)))
	add_info_btn(host, ThemeS.btn("Back to documents", host._back))
