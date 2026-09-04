extends CanvasLayer

## Pause / title Archives browser. Section 20 layout.

const T := preload("res://scripts/data/tunables.gd")
const Docs := preload("res://scripts/data/archives_docs.gd")
const View := preload("res://scripts/ui/archives_ui_view.gd")
const Act := preload("res://scripts/ui/archives_ui_act.gd")

var open := false
var selected := 0
var mode := "info"
var col := "list"
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
	View.setup(self)
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
	View.rebuild(self)


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


func _cur() -> Dictionary:
	if selected < 0 or selected >= entries.size():
		return {}
	return entries[selected]


func _docs_of(e: Dictionary) -> PackedStringArray:
	return Docs.names(e)


func _st(msg: String) -> void:
	if status:
		status.text = msg
	App.sfx("ui")


func _rebuild() -> void:
	View.rebuild(self)


func _place_chevron() -> void:
	View.place_chevron(self)


func _focus_col() -> void:
	View.focus_col(self)


func _on_list_hover(i: int) -> void:
	Act.preview(self, i)


func _on_list_focus(i: int) -> void:
	Act.preview(self, i)


func _on_list_pressed(i: int) -> void:
	Act.list_pressed(self, i)


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
