extends Object

## Crystal UI local transport page.

const ThemeS := preload("res://scripts/ui/theme.gd")
const CrystalNet := preload("res://scripts/world/crystal_net.gd")
const Util := preload("res://scripts/ui/crystal_ui_util.gd")
const Net := preload("res://scripts/ui/crystal_ui_pages_net.gd")


static func page_local(host) -> void:
	if host.host and host.host.has_method("_redraw_map"):
		host.host._redraw_map()
		CrystalNet.paint(host.host)
	Util.panel(host, Vector2(80, 80), Vector2(1760, 920))
	host.map_clip = Control.new()
	host.map_clip.position = Vector2(112, 128)
	host.map_clip.size = Vector2(980, 820)
	host.map_clip.clip_contents = true
	host.add_child(host.map_clip)
	host.map_rect = TextureRect.new()
	host.map_rect.position = Vector2.ZERO
	host.map_rect.size = Vector2(980, 820)
	host.map_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	host.map_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	host.map_rect.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	host.map_clip.add_child(host.map_rect)
	host.map_mark = ColorRect.new()
	host.map_mark.color = Color(1.0, 0.92, 0.35, 0.95)
	host.map_mark.size = Vector2(10, 10)
	host.map_mark.mouse_filter = Control.MOUSE_FILTER_IGNORE
	host.map_clip.add_child(host.map_mark)
	var box := VBoxContainer.new()
	box.position = Vector2(1120, 128)
	box.size = Vector2(680, 820)
	box.add_theme_constant_override("separation", 8)
	host.add_child(box)
	Net.net_tabs(host, box)
	box.add_child(ThemeS.lab("Local Transport Network", 28, Color(0.95, 0.82, 0.5)))
	box.add_child(ThemeS.lab("Bound crystals on this floor.", 18, Color(0.78, 0.74, 0.66)))
	host.status = ThemeS.lab(Util.zoom_tip(host), 18, Color(0.7, 0.66, 0.58))
	box.add_child(host.status)
	var first: Button = null
	for n: Node in CrystalNet.activated_on_floor(host.host):
		var cell: Vector2i = Vector2i(n.get("crystal_cell"))
		var here: bool = host.spot != null and Vector2i(host.spot.get("crystal_cell")) == cell
		var title := "Entrance  ·  CL %d" % int(n.get("crystal_cl"))
		if not bool(n.get("crystal_gate")):
			title = "CL %d Crystal" % int(n.get("crystal_cl"))
		if here:
			title += "  (here)"
		var b := ThemeS.btn(title, func(): host._pick_local(cell), not here)
		b.focus_entered.connect(func(): host._aim(cell))
		box.add_child(b)
		if first == null and not here:
			first = b
			host._aim(cell)
	var back := ThemeS.btn("Back", func(): host._back())
	box.add_child(back)
	host.focus_btn = first if first else back
	if first == null:
		host._aim(Vector2i(host.spot.get("crystal_cell")) if host.spot else host.host.data.spawn)
