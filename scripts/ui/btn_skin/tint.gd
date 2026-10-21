extends Object

## Split from btn_skin.gd: tint.

const Tok := preload("res://scripts/ui/ui_tokens.gd")

## Ink words, cream plates and rules on one node -> the skin's panel colours.
static func tint(n: Node, p: Dictionary) -> void:
	var inks: Array = [Tok.INK, Tok.INK_SOFT, Tok.INK_FAINT]
	if n is RichTextLabel or n is Label:
		var key: String = "default_color" if n is RichTextLabel else "font_color"
		var src: Color = n.get_meta("ink_src", (n as Control).get_theme_color(key))
		n.set_meta("ink_src", src)
		if src.is_equal_approx(Tok.DANGER):
			(n as Control).add_theme_color_override(key, p["danger_word"])
		for i: int in inks.size():
			if src.is_equal_approx(inks[i]):
				(n as Control).add_theme_color_override(key, p["words"][i])
		## Outline only behind light words (UiBuild.halo): a dark halo smudges dark ink.
		if (n as Control).get_theme_color(key).get_luminance() < 0.5:
			(n as Control).add_theme_constant_override("outline_size", 0)
	elif n is ColorRect:
		var r := n as ColorRect
		var src: Color = r.get_meta("ink_src", r.color)
		r.set_meta("ink_src", src)
		if Color(src, 1.0).is_equal_approx(Color(Tok.PAPER, 1.0)):
			r.color = p["panel"]
		elif src.is_equal_approx(Tok.RULE):
			r.color = p["panel_edge"]
	elif n is TextureRect and n.has_meta("paper_tex"):
		(n as TextureRect).visible = false
