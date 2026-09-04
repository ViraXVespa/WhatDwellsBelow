extends Object

const Cat := preload("res://scripts/data/archives_catalog.gd")
const Docs := preload("res://scripts/data/archives_docs.gd")
const View := preload("res://scripts/ui/archives_ui_view.gd")


static func preview(host: Node, i: int) -> void:
	if not host.open or host.col != "list":
		return
	if i < 0 or i >= host.entries.size():
		return
	if host.selected == i:
		View.paint_list(host)
		return
	host.selected = i
	host.mode = "info"
	View.paint_list(host)
	View.rebuild_info(host)
	View.apply_col(host)


static func list_pressed(host: Node, i: int) -> void:
	if i < 0 or i >= host.entries.size():
		return
	host.selected = i
	View.paint_list(host)
	if host.col == "detail":
		host.mode = "info"
		View.rebuild_info(host)
		enter_list(host)
		return
	host.mode = "info"
	View.rebuild_info(host)
	enter_detail(host)


static func enter_detail(host: Node) -> void:
	host.col = "detail"
	View.apply_col(host)
	host.call_deferred("_focus_col")


static func enter_list(host: Node) -> void:
	host.col = "list"
	host.mode = "info"
	View.rebuild_info(host)
	View.apply_col(host)
	host.call_deferred("_focus_col")


static func info_gui(host: Node, event: InputEvent) -> void:
	if not host.open or host.col != "list":
		return
	if event is InputEventMouseButton and event.pressed and (event as InputEventMouseButton).button_index == MOUSE_BUTTON_LEFT:
		enter_detail(host)


static func on_video(host: Node) -> void:
	if host.col != "detail":
		enter_detail(host)
	host._st("No video for this build.")


static func on_docs(host: Node) -> void:
	if host.col != "detail":
		enter_detail(host)
	open_docs(host)


static func on_play(host: Node) -> void:
	if host.col != "detail":
		enter_detail(host)
	play(host)


static func open_read(host: Node, i: int) -> void:
	host.doc_i = i
	host.mode = "read"
	host.col = "detail"
	View.rebuild_info(host)
	View.apply_col(host)
	host.call_deferred("_focus_col")


static func open_docs(host: Node) -> void:
	var e: Dictionary = host._cur()
	var docs: PackedStringArray = host._docs_of(e)
	if docs.is_empty():
		host._st("No documents for this build.")
		return
	host.mode = "docs"
	host.col = "detail"
	View.rebuild_info(host)
	View.apply_col(host)
	host.call_deferred("_focus_col")


static func play(host: Node) -> void:
	var e: Dictionary = host._cur()
	if e.is_empty():
		return
	App.launch_archive(str(e.id))
	host.hide_browser()


static func read_doc(host: Node, id: String, name: String) -> String:
	if name == "":
		return ""
	var key := "%s:%s" % [id, name]
	if host.doc_cache.has(key):
		return str(host.doc_cache[key])
	var e: Dictionary = host._cur()
	var t := Docs.read_now(e, name)
	if t != "":
		host.doc_cache[key] = t
		return t
	if OS.has_feature("web") and host.http and not host.http_busy:
		var url := Cat.raw_doc_url(e, name)
		if url != "":
			host.http_key = key
			host.http_busy = true
			host.http.request(url)
			return "Loading…"
	return "(missing)"


static func http_done(host: Node, code: int, body: PackedByteArray) -> void:
	host.http_busy = false
	var key := str(host.http_key)
	host.http_key = ""
	var text := "(missing)"
	if code == 200 and not body.is_empty():
		text = Docs.clip(body.get_string_from_utf8())
	if key != "":
		host.doc_cache[key] = text
	if host.open and host.mode == "read":
		View.rebuild_info(host)
		View.apply_col(host)
		host.call_deferred("_focus_col")


static func back(host: Node) -> void:
	if host.mode == "read":
		host.mode = "docs"
		host.col = "detail"
		View.rebuild_info(host)
		View.apply_col(host)
		host.call_deferred("_focus_col")
	elif host.mode == "docs":
		host.mode = "info"
		host.col = "detail"
		View.rebuild_info(host)
		View.apply_col(host)
		host.call_deferred("_focus_col")
	elif host.col == "detail":
		enter_list(host)
	else:
		host.hide_browser()


static func unhandled(host: Node, event: InputEvent) -> void:
	if not host.open:
		return
	if event.is_action_pressed("ui_cancel") or event.is_action_pressed("pause") or event.is_action_pressed("anim_back"):
		back(host)
		host.get_viewport().set_input_as_handled()
