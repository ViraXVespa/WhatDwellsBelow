extends RefCounted

## Shot flow text dump: every visible Label / Button / RichTextLabel / LineEdit under a root.
## Rows: text, font_size, rect [x, y, w, h], path. Lets a flow assert copy and size rules without pixels.

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
			out.append({
				"text": t,
				"font_size": c.get_theme_font_size("font_size"),
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
