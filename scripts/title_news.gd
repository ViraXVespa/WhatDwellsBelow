extends Object

const GameVer := preload("res://scripts/data/game_ver.gd")
const Pad := preload("res://scripts/input/pad.gd")
const ThemeS := preload("res://scripts/ui/theme.gd")


static func all_entries() -> Array:
	var rows: Array = []
	for e in GameVer.entries():
		if typeof(e) == TYPE_DICTIONARY:
			rows.append(e)
	rows.sort_custom(func(a, b): return GameVer.cmp(str(a.get("label", "")), str(b.get("label", ""))) > 0)
	return rows


static func new_labels(host: Node) -> Dictionary:
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
	host._news_open = true
	host._set_title_focus(false)
	host._news_layer = Control.new()
	host._news_layer.set_anchors_preset(Control.PRESET_FULL_RECT)
	host._news_layer.mouse_filter = Control.MOUSE_FILTER_STOP
	host.add_child(host._news_layer)
	var dim := ColorRect.new()
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.color = Color(0.02, 0.015, 0.01, 0.72)
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	host._news_layer.add_child(dim)
	var box := VBoxContainer.new()
	box.set_anchors_preset(Control.PRESET_CENTER)
	box.offset_left = -380
	box.offset_right = 380
	box.offset_top = -280
	box.offset_bottom = 280
	box.add_theme_constant_override("separation", 12)
	host._news_layer.add_child(box)
	box.add_child(host._lab("What's new", 32, Color(0.92, 0.78, 0.48)))
	var text_wrap := Control.new()
	text_wrap.custom_minimum_size = Vector2(720, 320)
	text_wrap.size_flags_vertical = Control.SIZE_EXPAND_FILL
	text_wrap.mouse_filter = Control.MOUSE_FILTER_STOP
	box.add_child(text_wrap)
	var text_bg := ColorRect.new()
	text_bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	text_bg.color = Color(0.11, 0.09, 0.07, 1)
	text_bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	text_wrap.add_child(text_bg)
	var text_edge := ColorRect.new()
	text_edge.set_anchors_preset(Control.PRESET_TOP_WIDE)
	text_edge.offset_bottom = 6
	text_edge.color = Color(0.55, 0.42, 0.22, 1)
	text_edge.mouse_filter = Control.MOUSE_FILTER_IGNORE
	text_wrap.add_child(text_edge)
	var scroll := ScrollContainer.new()
	scroll.set_anchors_preset(Control.PRESET_FULL_RECT)
	scroll.offset_left = 16
	scroll.offset_top = 16
	scroll.offset_right = -16
	scroll.offset_bottom = -16
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.mouse_filter = Control.MOUSE_FILTER_STOP
	text_wrap.add_child(scroll)
	host._news_scroll = scroll
	var body := RichTextLabel.new()
	body.bbcode_enabled = true
	body.fit_content = true
	body.scroll_active = false
	body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	body.custom_minimum_size = Vector2(668, 0)
	body.add_theme_font_size_override("normal_font_size", 18)
	body.add_theme_color_override("default_color", Color(0.86, 0.8, 0.7))
	body.add_theme_color_override("font_outline_color", Color(0.05, 0.03, 0.02))
	body.add_theme_constant_override("outline_size", 4)
	body.mouse_filter = Control.MOUSE_FILTER_IGNORE
	body.focus_mode = Control.FOCUS_NONE
	body.text = news_text(all_entries(), new_labs)
	scroll.add_child(body)
	var close_btn: Button = host._btn("Close", host._dismiss_news)
	box.add_child(close_btn)
	var older_btn: Button = null
	if older:
		older_btn = host._btn("Earlier weeks", host._open_older)
		box.add_child(older_btn)
	lock_news_focus(close_btn, older_btn)
	close_btn.grab_focus()


static func lock_news_focus(close_btn: Button, older_btn: Button) -> void:
	close_btn.focus_neighbor_left = close_btn.get_path()
	close_btn.focus_neighbor_right = close_btn.get_path()
	if older_btn == null:
		close_btn.focus_neighbor_top = close_btn.get_path()
		close_btn.focus_neighbor_bottom = close_btn.get_path()
		close_btn.focus_next = close_btn.get_path()
		close_btn.focus_previous = close_btn.get_path()
		return
	close_btn.focus_neighbor_top = older_btn.get_path()
	close_btn.focus_neighbor_bottom = older_btn.get_path()
	close_btn.focus_next = older_btn.get_path()
	close_btn.focus_previous = older_btn.get_path()
	older_btn.focus_neighbor_left = older_btn.get_path()
	older_btn.focus_neighbor_right = older_btn.get_path()
	older_btn.focus_neighbor_top = close_btn.get_path()
	older_btn.focus_neighbor_bottom = close_btn.get_path()
	older_btn.focus_next = close_btn.get_path()
	older_btn.focus_previous = close_btn.get_path()


static func esc_bb(t: String) -> String:
	return t.replace("[", "[lb]")


static func md_inline(t: String) -> String:
	var s := esc_bb(t)
	var out := ""
	var i := 0
	while i < s.length():
		if s.substr(i, 2) == "**":
			var close := s.find("**", i + 2)
			if close >= 0:
				out += "[b]%s[/b]" % s.substr(i + 2, close - i - 2)
				i = close + 2
				continue
		if s.substr(i, 1) == "`":
			var close2 := s.find("`", i + 1)
			if close2 >= 0:
				out += "[code]%s[/code]" % s.substr(i + 1, close2 - i - 1)
				i = close2 + 1
				continue
		out += s.substr(i, 1)
		i += 1
	return out


static func entry_bbcode(e: Dictionary, is_new: bool) -> String:
	var lab := str(e.get("label", "")).strip_edges()
	if lab == "":
		lab = "Build"
	var head := "[font_size=24][b]%s[/b][/font_size]" % esc_bb(lab)
	if is_new:
		head = "[color=#f0d878]%s[/color]" % head
	var lines: PackedStringArray = [head]
	var points: Variant = e.get("points", [])
	if points is Array:
		for p in points:
			if typeof(p) == TYPE_DICTIONARY:
				var text := str((p as Dictionary).get("text", "")).strip_edges()
				if text != "":
					lines.append("• %s" % md_inline(text))
				var subs: Variant = (p as Dictionary).get("subs", [])
				if subs is Array:
					for sub in subs:
						var st := str(sub).strip_edges()
						if st != "":
							lines.append("    ◦ %s" % md_inline(st))
			else:
				var pt := str(p).strip_edges()
				if pt != "":
					lines.append("• %s" % md_inline(pt))
	var summary := str(e.get("summary", "")).strip_edges()
	if summary != "":
		lines.append("")
		lines.append("[i]Summary:[/i] %s" % md_inline(summary))
	return "\n".join(lines)


static func news_text(rows: Array, new_labs: Dictionary) -> String:
	if rows.is_empty():
		return "Updates from earlier weeks are on the public changelog."
	var parts: PackedStringArray = []
	for e in rows:
		if typeof(e) != TYPE_DICTIONARY:
			continue
		var lab := str((e as Dictionary).get("label", ""))
		parts.append(entry_bbcode(e, new_labs.has(lab)))
	return "\n\n".join(parts)


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
