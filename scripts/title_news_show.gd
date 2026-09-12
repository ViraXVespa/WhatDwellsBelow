extends Object

const GameVer := preload("res://scripts/data/game_ver.gd")
const Pad := preload("res://scripts/input/pad.gd")
const ThemeS := preload("res://scripts/ui/theme.gd")
const Fmt := preload("res://scripts/title_news_fmt.gd")

static func show_news(host: Node, older: bool, new_labs: Dictionary) -> void:
	var _fac = load("res://scripts/title_news.gd")
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
	var text_shell := Control.new()
	text_shell.custom_minimum_size = Vector2(720, 320)
	text_shell.size_flags_vertical = Control.SIZE_EXPAND_FILL
	text_shell.mouse_filter = Control.MOUSE_FILTER_STOP
	box.add_child(text_shell)
	var text_bg := ColorRect.new()
	text_bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	text_bg.color = Color(0.11, 0.09, 0.07, 1)
	text_bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	text_shell.add_child(text_bg)
	var text_edge := ColorRect.new()
	text_edge.set_anchors_preset(Control.PRESET_TOP_WIDE)
	text_edge.offset_bottom = 6
	text_edge.color = Color(0.55, 0.42, 0.22, 1)
	text_edge.mouse_filter = Control.MOUSE_FILTER_IGNORE
	text_shell.add_child(text_edge)
	var scroll := ScrollContainer.new()
	scroll.set_anchors_preset(Control.PRESET_FULL_RECT)
	scroll.offset_left = 16
	scroll.offset_top = 16
	scroll.offset_right = -16
	scroll.offset_bottom = -16
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.mouse_filter = Control.MOUSE_FILTER_STOP
	text_shell.add_child(scroll)
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
	body.text = _fac.news_text(_fac.all_entries(), new_labs)
	scroll.add_child(body)
	var close_btn: Button = host._btn("Close", host._dismiss_news)
	box.add_child(close_btn)
	var older_btn: Button = null
	if older:
		older_btn = host._btn("Earlier weeks", host._open_older)
		box.add_child(older_btn)
	Fmt.lock_news_focus(close_btn, older_btn)
	close_btn.grab_focus()

static func entry_bbcode(e: Dictionary, is_new: bool) -> String:
	var _fac = load("res://scripts/title_news.gd")
	var lab := str(e.get("label", "")).strip_edges()
	if lab == "":
		lab = "Build"
	var head := "[font_size=24][b]%s[/b][/font_size]" % _fac.esc_bb(lab)
	if is_new:
		head = "[color=#f0d878]%s[/color]" % head
	var lines: PackedStringArray = [head]
	var points: Variant = e.get("points", [])
	if points is Array:
		for p in points:
			if typeof(p) == TYPE_DICTIONARY:
				var text := str((p as Dictionary).get("text", "")).strip_edges()
				if text != "":
					lines.append("\u2022 %s" % _fac.md_inline(text))
				var subs: Variant = (p as Dictionary).get("subs", [])
				if subs is Array:
					for sub in subs:
						var st := str(sub).strip_edges()
						if st != "":
							lines.append("\t\u25e6 %s" % _fac.md_inline(st))
			else:
				var pt := str(p).strip_edges()
				if pt != "":
					lines.append("\u2022 %s" % _fac.md_inline(pt))
	var summary := str(e.get("summary", "")).strip_edges()
	if summary != "":
		lines.append("")
		lines.append("[i]Summary:[/i] %s" % _fac.md_inline(summary))
	return "\n".join(lines)
