extends Object

const GameVer := preload("res://scripts/data/game_ver.gd")
const Pad := preload("res://scripts/input/pad.gd")
const Show := preload("res://scripts/title_news_show.gd")
const Fmt := preload("res://scripts/title_news_fmt.gd")


static func all_entries() -> Array:
	var rows: Array = []
	for e in GameVer.entries():
		if typeof(e) == TYPE_DICTIONARY:
			rows.append(e)
	rows.sort_custom(func(a, b): return GameVer.cmp(str(a.get("label", "")), str(b.get("label", ""))) > 0)
	return rows


static func new_labels(_host: Node) -> Dictionary:
	var out := {}
	var info: Dictionary = GameVer.unseen(str(App.last_seen_game_ver))
	for e in info.get("entries", []):
		if typeof(e) == TYPE_DICTIONARY:
			var lab := str((e as Dictionary).get("label", ""))
			if lab != "":
				out[lab] = true
	return out


static func maybe_news(host: Node) -> void:
	if host._debug_open():
		return
	var info: Dictionary = GameVer.unseen(str(App.last_seen_game_ver))
	var unseen_rows: Array = info.get("entries", [])
	if unseen_rows.is_empty() and not bool(info.get("older_series", false)):
		return
	show_news(host, bool(info.get("older_series", false)), new_labels(host))


static func open_updates(host: Node) -> void:
	if host._busy or host._debug_open() or host._news_open:
		return
	var info: Dictionary = GameVer.unseen(str(App.last_seen_game_ver))
	show_news(host, bool(info.get("older_series", false)), new_labels(host))


static func show_news(host: Node, older: bool, new_labs: Dictionary) -> void:
	Show.show_news(host, older, new_labs)


static func lock_news_focus(close_btn: Button, older_btn: Button) -> void:
	Fmt.lock_news_focus(close_btn, older_btn)


static func esc_bb(t: String) -> String:
	return Fmt.esc_bb(t)


static func md_inline(t: String) -> String:
	return Fmt.md_inline(t)


static func entry_bbcode(e: Dictionary, is_new: bool) -> String:
	return Fmt.entry_bbcode(e, is_new)


static func news_text(rows: Array, new_labs: Dictionary) -> String:
	return Fmt.news_text(rows, new_labs)


static func dismiss(host: Node) -> void:
	if App.has_method("ack_game_ver"):
		App.ack_game_ver()
	if host._news_layer:
		host._news_layer.queue_free()
	host._news_layer = null
	host._news_scroll = null
	host._news_open = false
	host._set_title_focus(true)
	host._focus_first()


static func open_older() -> void:
	OS.shell_open(GameVer.PAGES_CHANGELOG)


static func scroll_news(host: Node, px: int) -> void:
	if host._news_scroll == null or not is_instance_valid(host._news_scroll):
		return
	host._news_scroll.scroll_vertical = maxi(0, host._news_scroll.scroll_vertical + px)


static func tick(host: Node, delta: float) -> void:
	if host._news_open and host._news_scroll != null and is_instance_valid(host._news_scroll):
		var y := Pad.stick(JOY_AXIS_RIGHT_X, JOY_AXIS_RIGHT_Y).y
		if absf(y) > 0.2:
			scroll_news(host, int(y * 520.0 * delta))


static func wheel(host: Node, event: InputEvent) -> void:
	if not host._news_open or host._busy or host._debug_open():
		return
	if event is InputEventMouseButton and event.pressed:
		var mb := event as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_WHEEL_UP:
			scroll_news(host, -48)
			host.get_viewport().set_input_as_handled()
		elif mb.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			scroll_news(host, 48)
			host.get_viewport().set_input_as_handled()
