extends CanvasLayer

## Title Archives browser. Shared two-column shell.

const T := preload("res://scripts/data/tunables.gd")
const Docs := preload("res://scripts/data/archives_docs.gd")
const ArchView := preload("res://scripts/ui/archives_ui_view.gd")
const Act := preload("res://scripts/ui/archives_ui_act.gd")
const Split := preload("res://scripts/ui/split_menu.gd")
const SplitView := preload("res://scripts/ui/split_menu_view.gd")

var open := false
var selected := 0
var mode := "info"
var col := "list"
var split_page := ""
var doc_i := 0
var list_box: VBoxContainer
var info_box: VBoxContainer
var status: Label
var entries: Array = []
var doc_cache := {}
var http: HTTPRequest
var http_key := ""
var http_busy := false
var list_btns: Array = []
var info_btns: Array = []
var back_btn: Button
var _list_root: Control
var _info_root: Control
var _list_rule: ColorRect
var _info_rule: ColorRect
var _chevron: Label
var _path: Label


func _ready() -> void:
	SplitView.setup_overlay(self, "Archives", "Standalone snapshots. Title Play always launches the live path.")
	if _info_root:
		_info_root.gui_input.connect(_on_info_gui)
	http = HTTPRequest.new()
	http.timeout = 12.0
	http.request_completed.connect(_http_done)
	add_child(http)


func show_browser() -> void:
	open = true
	visible = true
	App.ui_open = true
	mode = "info"
	col = "list"
	entries = T.archive_catalog()
	selected = clampi(selected, 0, maxi(0, entries.size() - 1))
	split_page = str(_cur().get("id", ""))
	Split.rebuild(self)


func hide_browser() -> void:
	open = false
	visible = false
	mode = "info"
	col = "list"
	if App.pause_menu == null or not bool(App.pause_menu.get("open")):
		if get_tree().current_scene == null or str(get_tree().current_scene.scene_file_path).find("title") < 0:
			App.ui_open = false
		App.wake_web_pad()
	if App.pause_menu and bool(App.pause_menu.get("open")) and App.pause_menu.has_method("_focus"):
		App.pause_menu._focus()


func split_rows() -> Array:
	var out: Array = []
	for raw: Variant in entries:
		if not (raw is Dictionary):
			continue
		var e: Dictionary = raw
		out.append({
			"id": str(e.get("id", "")),
			"label": str(e.get("label", e.get("id", ""))),
			"kind": "page",
		})
	return out


func split_back_label() -> String:
	return "Back"


func split_close() -> void:
	hide_browser()


func split_path_text() -> String:
	var e: Dictionary = _cur()
	var lab: String = str(e.get("label", "Snapshot"))
	if col == "list":
		return "Snapshots"
	if mode == "docs":
		return "Snapshots  ›  %s  ›  Documents" % lab
	if mode == "read":
		var docs: PackedStringArray = _docs_of(e)
		var name: String = str(docs[doc_i]) if doc_i >= 0 and doc_i < docs.size() else ""
		return "Snapshots  ›  %s  ›  %s" % [lab, Docs.display_name(name)]
	return "Snapshots  ›  %s" % lab


func split_build_page(id: String) -> void:
	if id == "":
		SplitView.clear_page(self)
		return
	ArchView.rebuild_info(self)


func _cur() -> Dictionary:
	if selected < 0 or selected >= entries.size():
		return {}
	var raw: Variant = entries[selected]
	if raw is Dictionary:
		return raw
	return {}


func _docs_of(e: Dictionary) -> PackedStringArray:
	return Docs.names(e)


func _st(msg: String) -> void:
	if status:
		status.text = msg
	App.sfx("ui")


func _rebuild() -> void:
	Split.rebuild(self)


func _place_chevron() -> void:
	SplitView.place_chevron(self)


func _focus_col() -> void:
	SplitView.focus_col(self)


func _on_list_hover(i: int) -> void:
	Split.preview(self, i)


func _on_list_focus(i: int) -> void:
	Split.preview(self, i)


func _on_list_pressed(i: int) -> void:
	Split.list_pressed(self, i)


func _on_info_gui(event: InputEvent) -> void:
	Act.info_gui(self, event)


func _on_video() -> void:
	Act.on_video(self)


func _on_docs() -> void:
	Act.on_docs(self)


func _on_play() -> void:
	Act.on_play(self)


func _open_read(i: int) -> void:
	Act.open_read(self, i)


func _open_docs() -> void:
	Act.open_docs(self)


func _play() -> void:
	Act.play(self)


func _read_doc(id: String, name: String) -> String:
	return Act.read_doc(self, id, name)


func _http_done(_result: int, code: int, _headers: PackedStringArray, body: PackedByteArray) -> void:
	Act.http_done(self, code, body)


func _back() -> void:
	Act.back(self)


func _unhandled_input(event: InputEvent) -> void:
	Act.unhandled(self, event)
