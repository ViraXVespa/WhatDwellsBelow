extends CanvasLayer

## Pause / title Archives browser. Section 20 layout.

const T := preload("res://scripts/data/tunables.gd")
const ThemeS := preload("res://scripts/ui/theme.gd")

var open := false
var selected := 0
var mode := "info"
var doc_i := 0
var list_box: VBoxContainer
var info_box: VBoxContainer
var status: Label
var focus_btn: Button
var entries: Array = []


func _ready() -> void:
	layer = 62
	visible = false
	process_mode = Node.PROCESS_MODE_ALWAYS
	var dim := ColorRect.new()
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.color = Color(0.03, 0.02, 0.02, 0.82)
	add_child(dim)
	var panel := ColorRect.new()
	panel.color = Color(0.13, 0.1, 0.08, 0.97)
	panel.position = Vector2(160, 70)
	panel.size = Vector2(1600, 940)
	add_child(panel)
	var edge := ColorRect.new()
	edge.color = Color(0.55, 0.42, 0.22, 1)
	edge.position = Vector2(160, 70)
	edge.size = Vector2(1600, 8)
	add_child(edge)
	var title := ThemeS.lab("Archives", 32, Color(0.95, 0.86, 0.55))
	title.position = Vector2(192, 92)
	title.size = Vector2(700, 48)
	add_child(title)
	var hint := ThemeS.lab("Standalone snapshots. Title Play always launches the live path.", 18, Color(0.8, 0.76, 0.66))
	hint.position = Vector2(192, 140)
	hint.size = Vector2(1200, 36)
	add_child(hint)
	list_box = VBoxContainer.new()
	list_box.position = Vector2(192, 190)
	list_box.size = Vector2(520, 720)
	list_box.add_theme_constant_override("separation", 10)
	add_child(list_box)
	var scroll := ScrollContainer.new()
	scroll.position = Vector2(740, 190)
	scroll.size = Vector2(980, 720)
	add_child(scroll)
	info_box = VBoxContainer.new()
	info_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	info_box.add_theme_constant_override("separation", 10)
	scroll.add_child(info_box)
	status = ThemeS.lab("", 18, Color(0.95, 0.8, 0.45))
	status.position = Vector2(192, 920)
	status.size = Vector2(1520, 40)
	add_child(status)


func show_browser() -> void:
	open = true
	visible = true
	App.ui_open = true
	mode = "info"
	entries = T.archive_catalog()
	selected = clampi(selected, 0, maxi(0, entries.size() - 1))
	_rebuild()


func hide_browser() -> void:
	open = false
	visible = false
	mode = "info"
	if App.pause_menu == null or not bool(App.pause_menu.get("open")):
		if get_tree().current_scene == null or str(get_tree().current_scene.scene_file_path).find("title") < 0:
			App.ui_open = false
	if App.pause_menu and bool(App.pause_menu.get("open")) and App.pause_menu.has_method("_focus"):
		App.pause_menu._focus()


func _rebuild() -> void:
	for c in list_box.get_children():
		c.queue_free()
	for c in info_box.get_children():
		c.queue_free()
	focus_btn = null
	for i in entries.size():
		var e: Dictionary = entries[i]
		var ii := i
		var b := ThemeS.btn(str(e.label), func(): selected = ii; mode = "info"; _rebuild())
		if i == selected:
			b.add_theme_color_override("font_color", Color(1, 0.92, 0.45))
		list_box.add_child(b)
		if focus_btn == null:
			focus_btn = b
	var back := ThemeS.btn("Back  (B)", func(): hide_browser())
	list_box.add_child(back)
	if mode == "docs":
		_docs_panel()
	elif mode == "read":
		_read_panel()
	else:
		_info_panel()
	call_deferred("_focus")


func _focus() -> void:
	if focus_btn:
		focus_btn.grab_focus()


func _cur() -> Dictionary:
	if selected < 0 or selected >= entries.size():
		return {}
	return entries[selected]


func _info_panel() -> void:
	var e := _cur()
	if e.is_empty():
		info_box.add_child(ThemeS.lab("No archives.", 22, Color(0.85, 0.7, 0.55)))
		return
	info_box.add_child(ThemeS.lab(str(e.label), 28, Color(0.95, 0.86, 0.55)))
	info_box.add_child(ThemeS.lab(str(e.desc), 20, Color(0.88, 0.82, 0.72)))
	var docs := _docs_of(e)
	var has_video := str(e.get("video", "")) != ""
	var vid := ThemeS.btn("Video", func(): _st("No video for this build."), has_video)
	info_box.add_child(vid)
	var doc_btn := ThemeS.btn("Documents", func(): _open_docs(), docs.size() > 0)
	info_box.add_child(doc_btn)
	info_box.add_child(ThemeS.btn("Play", func(): _play()))


func _docs_panel() -> void:
	var e := _cur()
	info_box.add_child(ThemeS.lab("%s — Documents" % str(e.label), 26, Color(0.95, 0.86, 0.55)))
	var docs := _docs_of(e)
	if docs.is_empty():
		info_box.add_child(ThemeS.lab("No documents for this build.", 20, Color(0.8, 0.74, 0.64)))
	for i in docs.size():
		var name := str(docs[i])
		var ii := i
		var b := ThemeS.btn(name, func(): doc_i = ii; mode = "read"; _rebuild())
		if focus_btn == null:
			focus_btn = b
		info_box.add_child(b)
	info_box.add_child(ThemeS.btn("Back to info  (B)", func(): mode = "info"; _rebuild()))


func _read_panel() -> void:
	var e := _cur()
	var docs := _docs_of(e)
	var name := str(docs[doc_i]) if doc_i >= 0 and doc_i < docs.size() else ""
	info_box.add_child(ThemeS.lab(name, 24, Color(0.95, 0.86, 0.55)))
	info_box.add_child(ThemeS.lab(_read_doc(str(e.id), name), 16, Color(0.86, 0.82, 0.74)))
	if focus_btn == null:
		focus_btn = ThemeS.btn("Back to documents  (B)", func(): mode = "docs"; _rebuild())
		info_box.add_child(focus_btn)
	else:
		info_box.add_child(ThemeS.btn("Back to documents  (B)", func(): mode = "docs"; _rebuild()))


func _open_docs() -> void:
	var e := _cur()
	var docs := _docs_of(e)
	if docs.is_empty():
		_st("No documents for this build.")
		return
	mode = "docs"
	_rebuild()


func _play() -> void:
	var e := _cur()
	if e.is_empty():
		return
	hide_browser()
	App.launch_archive(str(e.id))


func _docs_of(e: Dictionary) -> PackedStringArray:
	var raw: Variant = e.get("docs", PackedStringArray())
	var docs := PackedStringArray()
	if raw is PackedStringArray:
		return raw
	if raw is Array:
		for x in raw:
			docs.append(str(x))
	return docs


func _read_doc(id: String, name: String) -> String:
	if name == "":
		return ""
	var root := ProjectSettings.globalize_path("res://").trim_suffix("/")
	var path := root.path_join("archives").path_join(id).path_join(name)
	if not FileAccess.file_exists(path):
		return "(missing)"
	var t := FileAccess.get_file_as_string(path)
	if t.length() > 4000:
		return t.substr(0, 4000) + "\n…"
	return t


func _st(msg: String) -> void:
	if status:
		status.text = msg
	App.sfx("ui")


func _unhandled_input(event: InputEvent) -> void:
	if not open:
		return
	if event.is_action_pressed("ui_cancel") or event.is_action_pressed("pause") or event.is_action_pressed("anim_back"):
		if mode == "read":
			mode = "docs"
			_rebuild()
		elif mode == "docs":
			mode = "info"
			_rebuild()
		else:
			hide_browser()
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("ui_up") or event.is_action_pressed("ui_down"):
		if mode != "info" or entries.is_empty():
			return
		var d := -1 if event.is_action_pressed("ui_up") else 1
		selected = (selected + d + entries.size()) % entries.size()
		_rebuild()
		get_viewport().set_input_as_handled()
