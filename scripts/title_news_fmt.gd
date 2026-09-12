extends Object

const GameVer := preload("res://scripts/data/game_ver.gd")


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
		return "Updates from earlier weeks are on the public changelog."
	var parts: PackedStringArray = []
	for e in rows:
		if typeof(e) != TYPE_DICTIONARY:
			continue
		var lab := str((e as Dictionary).get("label", ""))
		parts.append(entry_bbcode(e, new_labs.has(lab)))
	return "\n\n".join(parts)


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
