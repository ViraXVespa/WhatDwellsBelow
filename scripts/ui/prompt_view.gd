extends Object

const ThemeS := preload("res://scripts/ui/theme.gd")
const Prompts := preload("res://scripts/input/prompts.gd")

const BAR_NAME := "gear_hint_bar"
const BAR_W := 620.0
const BAR_H := 40.0
const BAR_INSET := Vector2(28.0, 20.0)


static func fill(host: Control, parts: Array, font_size: int = 16, color: Color = Color(0.86, 0.80, 0.66)) -> void:
	if host == null:
		return
	_wipe(host)
	for row: Variant in parts:
		if not (row is Dictionary):
			continue
		var action := str(row.get("action", ""))
		var verb := _cap_verb(str(row.get("verb", "")))
		var text := str(row.get("text", ""))
		if action != "":
			var tex: Texture2D = Prompts.texture_for(action)
			if tex:
				host.add_child(_glyph(tex, font_size))
			else:
				host.add_child(_lab(Prompts.chip_for(action), font_size, color))
			if verb != "":
				host.add_child(_lab(verb, font_size, color))
		elif text != "":
			host.add_child(_lab(text, font_size, color))
		if bool(row.get("gap", false)):
			var gap := Control.new()
			gap.custom_minimum_size = Vector2(16, 1)
			gap.mouse_filter = Control.MOUSE_FILTER_IGNORE
			host.add_child(gap)


static func footer(ui: CanvasLayer, extra: Array = [], font_size: int = 16, color: Color = Color(0.86, 0.80, 0.66)) -> Control:
	var bar := ensure_bar(ui)
	place_bar(ui, bar)
	bar.set_meta("prompt_extra", extra)
	bar.set_meta("prompt_font", font_size)
	bar.set_meta("prompt_color", color)
	fill(bar, merge_parts(extra), font_size, color)
	return bar


static func pulse() -> void:
	var tree := Engine.get_main_loop() as SceneTree
	if tree == null:
		return
	for n: Node in tree.root.find_children(BAR_NAME, "", true, false):
		if not (n is Control):
			continue
		var host := n.get_parent()
		if not (host is CanvasLayer):
			continue
		var extra: Array = n.get_meta("prompt_extra", [])
		var font_size := int(n.get_meta("prompt_font", 16))
		var color: Color = n.get_meta("prompt_color", Color(0.86, 0.80, 0.66))
		footer(host as CanvasLayer, extra, font_size, color)


static func ensure_bar(ui: CanvasLayer) -> Control:
	var bar: Control = ui.get_node_or_null(BAR_NAME)
	if bar == null:
		bar = HBoxContainer.new()
		bar.name = BAR_NAME
		bar.alignment = BoxContainer.ALIGNMENT_END
		bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
		bar.z_index = 30
		ui.add_child(bar)
	if ui.get("gear_hint") != null or "gear_hint" in ui:
		ui.gear_hint = bar
	return bar


static func place_bar(ui: CanvasLayer, bar: Control = null) -> void:
	if bar == null:
		bar = ui.get_node_or_null(BAR_NAME)
	if bar == null:
		return
	var panel := _menu_panel(ui)
	var vp := ui.get_viewport().get_visible_rect().size
	var pos := Vector2.ZERO
	if panel:
		pos = Vector2(
			panel.position.x + panel.size.x - BAR_W - BAR_INSET.x,
			panel.position.y + panel.size.y - BAR_H - BAR_INSET.y
		)
	else:
		pos = Vector2(vp.x - BAR_W - BAR_INSET.x, vp.y - BAR_H - BAR_INSET.y)
	pos.x = clampf(pos.x, 16.0, maxf(16.0, vp.x - BAR_W - 16.0))
	pos.y = clampf(pos.y, 16.0, maxf(16.0, vp.y - BAR_H - 16.0))
	bar.position = pos
	bar.size = Vector2(BAR_W, BAR_H)
	bar.custom_minimum_size = Vector2(BAR_W, BAR_H)


static func _menu_panel(ui: CanvasLayer) -> ColorRect:
	var best: ColorRect = null
	var best_a := 0.0
	for c: Node in ui.get_children():
		if not (c is ColorRect):
			continue
		var r := c as ColorRect
		if r.anchor_left <= 0.01 and r.anchor_right >= 0.99 and r.anchor_top <= 0.01 and r.anchor_bottom >= 0.99:
			continue
		if r.size.y < 64.0 or r.size.x < 200.0:
			continue
		var a := r.size.x * r.size.y
		if a > best_a:
			best = r
			best_a = a
	return best


static func merge_parts(extra: Array) -> Array:
	var out: Array = []
	var seen: Dictionary = {}
	for row: Variant in extra:
		if not (row is Dictionary):
			continue
		var action := str(row.get("action", ""))
		if action == "" and str(row.get("text", "")) == "":
			continue
		if action == Prompts.page_prev() or action == Prompts.page_next():
			continue
		if action == "tab_left" or action == "tab_right":
			continue
		if action != "" and seen.has(action):
			continue
		if action != "":
			seen[action] = true
		out.append(row)
	if not seen.has("ui_accept"):
		out.insert(0, {"action": "ui_accept", "verb": "Select", "gap": true})
	if not seen.has("ui_cancel"):
		out.append({"action": "ui_cancel", "verb": "Back"})
	return out


static func _cap_verb(verb: String) -> String:
	if verb == "":
		return ""
	return verb.substr(0, 1).to_upper() + verb.substr(1)


static func hint_line(host: Control, action: String, verb: String, font_size: int = 16, color: Color = Color(0.86, 0.80, 0.66)) -> void:
	fill(host, [{"action": action, "verb": verb}], font_size, color)


static func verb(host: Control, action: String, verb: String, font_size: int = 16, color: Color = Color(0.86, 0.80, 0.66)) -> void:
	hint_line(host, action, verb, font_size, color)


static func bind_icon(host: Control, action: String, font_size: int = 16) -> void:
	fill(host, [{"action": action}], font_size)


static func apply_label(lab: Label, action: String, verb: String = "") -> void:
	if lab == null:
		return
	lab.text = Prompts.verb_line(action, _cap_verb(verb))


static func _wipe(n: Node) -> void:
	while n.get_child_count() > 0:
		var c: Node = n.get_child(0)
		n.remove_child(c)
		c.queue_free()


static func _glyph(tex: Texture2D, font_size: int) -> TextureRect:
	var r := TextureRect.new()
	var h := float(maxi(font_size + 14, 28))
	var sz := tex.get_size()
	var w := h
	if sz.y > 0.0:
		w = h * (sz.x / sz.y)
	r.texture = tex
	r.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	r.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	r.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	r.custom_minimum_size = Vector2(w, h)
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return r


static func _lab(text: String, font_size: int, color: Color) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", font_size)
	l.add_theme_color_override("font_color", color)
	l.add_theme_color_override("font_outline_color", Color(0.05, 0.03, 0.02))
	l.add_theme_constant_override("outline_size", 5)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	return l
