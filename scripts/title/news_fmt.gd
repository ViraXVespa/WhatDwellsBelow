extends Object

const UiBuild := preload("res://scripts/ui/ui_build.gd")
const UiText := preload("res://scripts/ui/ui_text.gd")

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
		lab = App.tr("news_fmt.build")
	var head := "[font_size=%d][b]%s[/b][/font_size]" % [UiText.font_px(24), esc_bb(lab)]
	if is_new:
		head = "[color=#e2b862]%s[/color]" % head
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
							lines.append("\t◦ %s" % md_inline(st))
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
		return App.tr("news_fmt.updates_from_earlier_weeks_are")
	var parts: PackedStringArray = []
	for e in rows:
		if typeof(e) != TYPE_DICTIONARY:
			continue
		var lab := str((e as Dictionary).get("label", ""))
		parts.append(entry_bbcode(e, new_labs.has(lab)))
	return "\n\n".join(parts)

static func lock_news_focus(close_btn: Button, older_btn: Button) -> void:
	if older_btn == null:
		UiBuild.focus(close_btn, close_btn, close_btn, close_btn, close_btn, close_btn, close_btn)
		return
	UiBuild.focus(close_btn, close_btn, close_btn, older_btn, older_btn, older_btn, older_btn)
	UiBuild.focus(older_btn, older_btn, older_btn, close_btn, close_btn, close_btn, close_btn)
