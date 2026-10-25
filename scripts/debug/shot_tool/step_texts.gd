extends RefCounted

## Shot flow text dump: every visible Label / Button / RichTextLabel / LineEdit under a root.
## Rows: text, font_size, px (glyph em size in window pixels after canvas, layer and stretch scale), rect [x, y, w, h],
## path. Lets a flow assert copy and size rules without pixels; shots.py textsize turns px into CSS px.

static func _text_of(c: Control) -> String:
	if c is RichTextLabel:
		return (c as RichTextLabel).get_parsed_text()
	if c is Label:
		return (c as Label).text
	if c is Button:
		return (c as Button).text
	if c is LineEdit:
		return (c as LineEdit).text
	return ""

static func _walk(n: Node, out: Array) -> void:
	if n is CanvasItem and not (n as CanvasItem).is_visible_in_tree():
		return
	if n is Control and (n is Label or n is Button or n is RichTextLabel or n is LineEdit):
		var c: Control = n
		var t: String = _text_of(c).strip_edges()
		if not t.is_empty():
			var r: Rect2 = c.get_global_rect()
			var fs: int = c.get_theme_font_size("normal_font_size" if c is RichTextLabel else "font_size")
			var k: float = c.get_global_transform_with_canvas().get_scale().y * c.get_viewport().get_final_transform().get_scale().y
			out.append({
				"text": t,
				"font_size": c.get_theme_font_size("font_size"),
				"px": snappedf(float(fs) * absf(k), 0.1),
				"rect": [int(r.position.x), int(r.position.y), int(r.size.x), int(r.size.y)],
				"path": str(c.get_path()),
			})
	for ch: Node in n.get_children():
		_walk(ch, out)

static func collect(root: Node) -> Array:
	var out: Array = []
	if root != null:
		_walk(root, out)
	return out

## Visible texts from every CanvasLayer under the viewport root (UI, HUD, prompts), or from `root`.
static func collect_ui(host: Node, root: Node) -> Array:
	if root != null:
		return collect(root)
	var out: Array = []
	for n: Node in host.get_tree().root.get_children():
		_walk(n, out)
	return out

## What the overlays cover: one [x, y, w, h, path] per visible drawing leaf on every CanvasLayer (texture, colour
## rect, panel, text ink box), in viewport px; full-screen fills are left out. shots.py textsize unions them into a
## share of the frame (HUD footprint on a phone).
static func cover(host: Node) -> Dictionary:
	var vp: Vector2 = host.get_viewport().get_visible_rect().size
	var out: Array = []
	for n: Node in host.get_tree().root.get_children():
		_cover(n, vp, out)
	return {"vp": [vp.x, vp.y], "rects": out}

const ALIGN_K: Array[float] = [0.0, 0.5, 1.0, 0.0]

## A label's ink box (text size, placed by its alignment) rather than its layout rect.
static func _ink(c: Control) -> Rect2:
	if not (c is Label):
		return Rect2(Vector2.ZERO, c.size)
	var l := c as Label
	var f: Font = l.get_theme_font("font")
	var wrap: float = l.size.x if l.autowrap_mode != TextServer.AUTOWRAP_OFF else -1.0
	var s: Vector2 = f.get_multiline_string_size(l.text, l.horizontal_alignment, wrap, l.get_theme_font_size("font_size"))
	s = Vector2(minf(l.size.x, s.x), minf(l.size.y, s.y)) if l.size.x > 1.0 else s
	return Rect2(Vector2((l.size.x - s.x) * ALIGN_K[int(l.horizontal_alignment)], 0.0), s)

static func _draws(c: Control) -> bool:
	if c is TextureRect:
		return (c as TextureRect).texture != null
	if c is ColorRect:
		return (c as ColorRect).color.a > 0.05
	if c is Label or c is RichTextLabel:
		return not _text_of(c).strip_edges().is_empty()
	return c is NinePatchRect or c is Panel or c is PanelContainer or c is ProgressBar or c is Button

static func _cover(n: Node, vp: Vector2, out: Array) -> void:
	if n is CanvasItem and not (n as CanvasItem).is_visible_in_tree():
		return
	if n is Control and _draws(n as Control) and (n as Control).modulate.a > 0.05:
		var c: Control = n
		var r: Rect2 = (c.get_global_transform_with_canvas() * _ink(c)).intersection(Rect2(Vector2.ZERO, vp))
		if r.get_area() > 0.0 and r.get_area() < 0.9 * vp.x * vp.y:
			out.append([int(r.position.x), int(r.position.y), int(ceil(r.size.x)), int(ceil(r.size.y)), str(c.get_path())])
	for ch: Node in n.get_children():
		_cover(ch, vp, out)
