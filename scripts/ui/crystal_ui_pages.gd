extends Object

## Crystal UI page bodies. Host is scripts/ui/crystal_ui.gd.

const ThemeS := preload("res://scripts/ui/theme.gd")
const CrystalNet := preload("res://scripts/world/crystal_net.gd")
const Util := preload("res://scripts/ui/crystal_ui_util.gd")
const PromptView := preload("res://scripts/ui/prompt_view.gd")


static func net_tabs(host, box: VBoxContainer) -> void:
	var shell := HBoxContainer.new()
	shell.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	shell.add_theme_constant_override("separation", 10)
	var left := HBoxContainer.new()
	left.mouse_filter = Control.MOUSE_FILTER_IGNORE
	left.custom_minimum_size = Vector2(36, 28)
	var right := HBoxContainer.new()
	right.mouse_filter = Control.MOUSE_FILTER_IGNORE
	right.custom_minimum_size = Vector2(36, 28)
	var sc := ScrollContainer.new()
	sc.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sc.custom_minimum_size = Vector2(200, 52)
	sc.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	sc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_SHOW_NEVER
	var row := HBoxContainer.new()
	row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_theme_constant_override("separation", 10)
	var local_ok := CrystalNet.local_unlocked(host.host)
	var floor_ok := CrystalNet.floor_unlocked()
	var on_local: bool = str(host.page) == "local"
	var b1 := ThemeS.btn("Local", func(): go_local(host), local_ok)
	var b2 := ThemeS.btn("Floors", func(): go_floors(host), floor_ok)
	b1.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	b2.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	b1.custom_minimum_size = Vector2(160, 44)
	b2.custom_minimum_size = Vector2(160, 44)
	if on_local:
		b1.disabled = true
		b1.focus_mode = Control.FOCUS_NONE
	else:
		b2.disabled = true
		b2.focus_mode = Control.FOCUS_NONE
	row.add_child(b1)
	row.add_child(b2)
	sc.add_child(row)
	shell.add_child(left)
	shell.add_child(sc)
	shell.add_child(right)
	PromptView.fill(left, [{"action": "tab_left"}], 16, Color(0.72, 0.66, 0.52))
	PromptView.fill(right, [{"action": "tab_right"}], 16, Color(0.72, 0.66, 0.52))
	box.add_child(shell)


static func cycle_net(host, dir: int) -> void:
	if dir == 0:
		return
	var local_ok := CrystalNet.local_unlocked(host.host)
	var floor_ok := CrystalNet.floor_unlocked()
	if str(host.page) == "local" and floor_ok:
		go_floors(host)
	elif (str(host.page) == "floors" or str(host.page) == "band") and local_ok:
		go_local(host)


static func page_root(host) -> void:
	Util.panel(host, Vector2(520, 220), Vector2(880, 620))
	var box := VBoxContainer.new()
	box.position = Vector2(552, 252)
	box.size = Vector2(816, 556)
	box.add_theme_constant_override("separation", 10)
	host.add_child(box)
	box.add_child(ThemeS.lab("Floor Crystal", 30, Color(0.95, 0.82, 0.5)))
	var cl := 1
	if host.spot:
		cl = int(host.spot.get("crystal_cl"))
	box.add_child(ThemeS.lab("F%d  ·  CL %d" % [App.floor_n, cl], 20, Color(0.78, 0.86, 0.9)))
	var local_ok := CrystalNet.local_unlocked(host.host)
	var floor_ok := CrystalNet.floor_unlocked()
	var b1 := ThemeS.btn("Local Transport Network", func(): go_local(host), local_ok)
	if not local_ok:
		b1.text = "Local Transport Network  (bind another crystal)"
	box.add_child(b1)
	host.focus_btn = b1 if local_ok else null
	var b2 := ThemeS.btn("Floor Transport Network", func(): go_floors(host), floor_ok)
	if not floor_ok:
		b2.text = "Floor Transport Network  (reach a deeper floor)"
	box.add_child(b2)
	if host.focus_btn == null and floor_ok:
		host.focus_btn = b2
	var back := ThemeS.btn("Back", func(): host.close_ui())
	box.add_child(back)
	if host.focus_btn == null:
		host.focus_btn = back
	host.status = ThemeS.lab("", 18, Color(0.7, 0.66, 0.58))
	box.add_child(host.status)


static func go_local(host) -> void:
	if not CrystalNet.local_unlocked(host.host):
		return
	host.page = "local"
	host._rebuild()


static func go_floors(host) -> void:
	if not CrystalNet.floor_unlocked():
		return
	host.page = "floors"
	host._rebuild()


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
	net_tabs(host, box)
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


static func page_floors(host) -> void:
	Util.panel(host, Vector2(520, 160), Vector2(880, 760))
	var box := VBoxContainer.new()
	box.position = Vector2(552, 192)
	box.size = Vector2(816, 696)
	box.add_theme_constant_override("separation", 8)
	host.add_child(box)
	net_tabs(host, box)
	box.add_child(ThemeS.lab("Floor Transport Network", 28, Color(0.95, 0.82, 0.5)))
	var deepest := maxi(1, int(App.prog.deepest))
	if str(host.page) == "band":
		box.add_child(ThemeS.lab("Floors %d–%d" % [host.band_lo, host.band_hi], 20, Color(0.78, 0.86, 0.9)))
		list_floors(host, box, host.band_lo, mini(host.band_hi, deepest), deepest)
	elif deepest > 10:
		box.add_child(ThemeS.lab("Deepest floor: %d" % deepest, 20, Color(0.78, 0.86, 0.9)))
		var lo := 1
		var first: Button = null
		while lo <= deepest:
			var hi: int = lo + 9
			var lab := "Floors %d–%d" % [lo, hi]
			var a := lo
			var b := hi
			var btn := ThemeS.btn(lab, func(): open_band(host, a, b))
			box.add_child(btn)
			if first == null:
				first = btn
			lo += 10
		host.focus_btn = first
	else:
		box.add_child(ThemeS.lab("Deepest floor: %d" % deepest, 20, Color(0.78, 0.86, 0.9)))
		list_floors(host, box, 1, deepest, deepest)
	var back := ThemeS.btn("Back", func(): host._back())
	box.add_child(back)
	if host.focus_btn == null:
		host.focus_btn = back


static func open_band(host, lo: int, hi: int) -> void:
	host.band_lo = lo
	host.band_hi = hi
	host.page = "band"
	host._rebuild()


static func list_floors(host, box: VBoxContainer, lo: int, hi: int, deepest: int) -> void:
	var first: Button = null
	for n in range(lo, hi + 1):
		var here: bool = n == App.floor_n
		var reached: bool = n <= deepest
		var title := "Floor %d" % n
		if here:
			title += "  (here)"
		elif not reached:
			title += "  (locked)"
		var btn := ThemeS.btn(title, func(): host._pick_floor(n), reached and not here)
		box.add_child(btn)
		if first == null and reached and not here:
			first = btn
	if first:
		host.focus_btn = first
