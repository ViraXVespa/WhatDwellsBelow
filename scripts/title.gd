extends Control

const T := preload("res://scripts/data/tunables.gd")
const GameVer := preload("res://scripts/data/game_ver.gd")
const News := preload("res://scripts/title_news.gd")

var _busy := false
var _archives_open := false
var _news_open := false
var _news_layer: Control = null
var _news_scroll: ScrollContainer = null
var _title_btns: Array = []


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	var bg := ColorRect.new()
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.color = Color(0.06, 0.05, 0.045, 1)
	add_child(bg)
	var card := VBoxContainer.new()
	card.set_anchors_preset(Control.PRESET_CENTER)
	card.offset_left = -420
	card.offset_right = 420
	card.offset_top = -320
	card.offset_bottom = 340
	card.alignment = BoxContainer.ALIGNMENT_CENTER
	card.add_theme_constant_override("separation", 14)
	add_child(card)
	card.add_child(_lab("WHAT DWELLS BELOW", 48, Color(0.92, 0.78, 0.48)))
	card.add_child(_lab(T.ONE_LINER, 18, Color(0.78, 0.72, 0.62)))
	card.add_child(_lab("Version: %s" % GameVer.label(), 16, Color(0.7, 0.62, 0.48)))
	var play_a: Button = null
	var play_b: Button = null
	var updates: Button = null
	var archives: Button = null
	if App.character_chosen:
		card.add_child(_lab("A / Start  —  Play launches the live path.", 18, Color(0.95, 0.86, 0.4)))
		play_a = _btn("Play", func(): _play(App.character_type))
		card.add_child(play_a)
	else:
		card.add_child(_lab("A / Start  ·  choose a delver  ·  switch later from pause.", 18, Color(0.95, 0.86, 0.4)))
		var row := HBoxContainer.new()
		row.alignment = BoxContainer.ALIGNMENT_CENTER
		row.add_theme_constant_override("separation", 16)
		row.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		card.add_child(row)
		play_a = _btn("Play — Male", func(): _play("male"))
		play_b = _btn("Play — Female", func(): _play("female"))
		row.add_child(play_a)
		row.add_child(play_b)
	updates = _btn("Updates", _open_updates)
	card.add_child(updates)
	archives = _btn("Archives", _open_archives)
	card.add_child(archives)
	card.add_child(_lab("Dungeon Music: Bitter - by Vira X Vespa", 16, Color(0.62, 0.66, 0.7)))
	_title_btns.clear()
	for b in [play_a, play_b, updates, archives]:
		if b:
			_title_btns.append(b)
	_wire_focus(play_a, play_b, updates, archives)
	call_deferred("_focus_first")
	call_deferred("_maybe_news")


func _debug_open() -> bool:
	return App.debug != null and bool(App.debug.get("open"))


func _wire_focus(play_a: Button, play_b: Button, updates: Button, archives: Button) -> void:
	if play_a == null or updates == null or archives == null:
		return
	if play_b == null:
		_loop_btn(play_a, archives, updates)
		_loop_btn(updates, play_a, archives)
		_loop_btn(archives, updates, play_a)
		play_a.focus_next = updates.get_path()
		play_a.focus_previous = archives.get_path()
		updates.focus_next = archives.get_path()
		updates.focus_previous = play_a.get_path()
		archives.focus_next = play_a.get_path()
		archives.focus_previous = updates.get_path()
		return
	play_a.focus_neighbor_left = play_b.get_path()
	play_a.focus_neighbor_right = play_b.get_path()
	play_a.focus_neighbor_top = archives.get_path()
	play_a.focus_neighbor_bottom = updates.get_path()
	play_a.focus_next = play_b.get_path()
	play_a.focus_previous = archives.get_path()
	play_b.focus_neighbor_left = play_a.get_path()
	play_b.focus_neighbor_right = play_a.get_path()
	play_b.focus_neighbor_top = archives.get_path()
	play_b.focus_neighbor_bottom = updates.get_path()
	play_b.focus_next = updates.get_path()
	play_b.focus_previous = play_a.get_path()
	_loop_btn(updates, play_a, archives)
	updates.focus_neighbor_left = play_a.get_path()
	updates.focus_neighbor_right = play_b.get_path()
	updates.focus_next = archives.get_path()
	updates.focus_previous = play_b.get_path()
	_loop_btn(archives, updates, play_a)
	archives.focus_neighbor_left = play_a.get_path()
	archives.focus_neighbor_right = play_b.get_path()
	archives.focus_next = play_a.get_path()
	archives.focus_previous = updates.get_path()


func _loop_btn(b: Button, up: Button, down: Button) -> void:
	b.focus_neighbor_top = up.get_path()
	b.focus_neighbor_bottom = down.get_path()
	if b.focus_neighbor_left == NodePath():
		b.focus_neighbor_left = b.get_path()
	if b.focus_neighbor_right == NodePath():
		b.focus_neighbor_right = b.get_path()


func _set_title_focus(on: bool) -> void:
	var mode := Control.FOCUS_ALL if on else Control.FOCUS_NONE
	for b in _title_btns:
		if b == null or not is_instance_valid(b):
			continue
		(b as Button).focus_mode = mode


func _focus_first() -> void:
	if _debug_open() or _news_open:
		return
	for n in find_children("*", "Button", true, false):
		if _news_layer != null and _news_layer.is_ancestor_of(n):
			continue
		(n as Button).grab_focus()
		return


func _lab(text: String, size: int, col: Color) -> Label:
	var l := Label.new()
	l.text = text
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", col)
	l.add_theme_color_override("font_outline_color", Color(0.05, 0.03, 0.02))
	l.add_theme_constant_override("outline_size", 6)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	l.focus_mode = Control.FOCUS_NONE
	return l


func _btn(text: String, cb: Callable) -> Button:
	var ThemeS := load("res://scripts/ui/theme.gd")
	var b: Button = ThemeS.btn(text, cb)
	b.custom_minimum_size = Vector2(280, 56)
	b.focus_mode = Control.FOCUS_ALL
	return b


func _maybe_news() -> void:
	News.maybe_news(self)


func _open_updates() -> void:
	News.open_updates(self)


func _dismiss_news() -> void:
	News.dismiss(self)


func _open_older() -> void:
	News.open_older()


func _process(delta: float) -> void:
	if _debug_open():
		return
	News.tick(self, delta)
	if _archives_open and (App.archives_ui == null or not bool(App.archives_ui.get("open"))):
		_archives_open = false
		_focus_first()


func _input(event: InputEvent) -> void:
	News.wheel(self, event)


func _unhandled_input(event: InputEvent) -> void:
	if _busy:
		return
	if _debug_open():
		return
	if _news_open and (event.is_action_pressed("ui_cancel") or event.is_action_pressed("pause") or event.is_action_pressed("anim_back")):
		_dismiss_news()
		get_viewport().set_input_as_handled()
		return
	if App.archives_ui and bool(App.archives_ui.get("open")):
		return


func _play(kind: String) -> void:
	if _busy or _debug_open() or _news_open:
		return
	_busy = true
	App.set_character(kind)
	App.save_now()
	if App.has_method("play_from_menu"):
		App.play_from_menu()
	else:
		App.go_camp()


func _open_archives() -> void:
	if _busy or _debug_open() or _news_open:
		return
	_archives_open = true
	if App.archives_ui and App.archives_ui.has_method("show_browser"):
		App.archives_ui.show_browser()


func _close_archives() -> void:
	_archives_open = false
	if App.archives_ui and App.archives_ui.has_method("hide_browser"):
		App.archives_ui.hide_browser()
	_focus_first()
