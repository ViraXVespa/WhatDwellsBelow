extends CanvasLayer

const ThemeS := preload("res://scripts/ui/theme.gd")
const CrystalNet := preload("res://scripts/world/crystal_net.gd")
const Util := preload("res://scripts/ui/crystal_ui_util.gd")

const ZOOM_NEAR := 96

var page := "root"
var spot: Node
var host: Node
var focus_btn: Button
var status: Label
var map_rect: TextureRect
var map_clip: Control
var map_mark: ColorRect
var band_lo := 1
var band_hi := 10
var zoom_lv := 0
var aim_cell := Vector2i.ZERO


static func open(from: Node) -> void:
	var old: Node = from.get_tree().get_first_node_in_group("crystal_ui")
	if old:
		old.queue_free()
	var ui := new()
	from.get_tree().current_scene.add_child(ui)
	ui.begin(from)


func begin(from: Node) -> void:
	spot = from
	host = from.get_tree().current_scene
	add_to_group("crystal_ui")
	layer = 46
	process_mode = Node.PROCESS_MODE_ALWAYS
	App.ui_open = true
	get_tree().paused = true
	page = "root"
	zoom_lv = 0
	_rebuild()


func close_ui() -> void:
	App.ui_open = false
	get_tree().paused = false
	var p := get_tree().get_first_node_in_group("player")
	if p:
		p.set("interact_lock", 0.25)
	App.swallow_close_pad()
	App.wake_web_pad()
	queue_free()


func _rebuild() -> void:
	for c in get_children():
		remove_child(c)
		c.queue_free()
	focus_btn = null
	status = null
	map_rect = null
	map_clip = null
	map_mark = null
	var dim := ColorRect.new()
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	dim.color = Color(0.04, 0.03, 0.02, 0.78)
	add_child(dim)
	if page == "local":
		_page_local()
	elif page == "floors" or page == "band":
		_page_floors()
	else:
		_page_root()
	call_deferred("_focus")


func _page_root() -> void:
	Util.panel(self, Vector2(520, 220), Vector2(880, 620))
	var box := VBoxContainer.new()
	box.position = Vector2(552, 252)
	box.size = Vector2(816, 556)
	box.add_theme_constant_override("separation", 10)
	add_child(box)
	box.add_child(ThemeS.lab("Floor Crystal", 30, Color(0.95, 0.82, 0.5)))
	var cl := 1
	if spot:
		cl = int(spot.get("crystal_cl"))
	box.add_child(ThemeS.lab("F%d  ·  CL %d" % [App.floor_n, cl], 20, Color(0.78, 0.86, 0.9)))
	var local_ok := CrystalNet.local_unlocked(host)
	var floor_ok := CrystalNet.floor_unlocked()
	var b1 := ThemeS.btn("Local Transport Network", func(): _go_local(), local_ok)
	if not local_ok:
		b1.text = "Local Transport Network  (bind another crystal)"
	box.add_child(b1)
	focus_btn = b1 if local_ok else null
	var b2 := ThemeS.btn("Floor Transport Network", func(): _go_floors(), floor_ok)
	if not floor_ok:
		b2.text = "Floor Transport Network  (reach a deeper floor)"
	box.add_child(b2)
	if focus_btn == null and floor_ok:
		focus_btn = b2
	var back := ThemeS.btn("Back  (B)", func(): close_ui())
	box.add_child(back)
	if focus_btn == null:
		focus_btn = back
	status = ThemeS.lab("A selects.  B back.", 18, Color(0.7, 0.66, 0.58))
	box.add_child(status)


func _go_local() -> void:
	if not CrystalNet.local_unlocked(host):
		return
	page = "local"
	_rebuild()


func _go_floors() -> void:
	if not CrystalNet.floor_unlocked():
		return
	page = "floors"
	_rebuild()


func _page_local() -> void:
	if host and host.has_method("_redraw_map"):
		host._redraw_map()
		CrystalNet.paint(host)
	Util.panel(self, Vector2(80, 80), Vector2(1760, 920))
	map_clip = Control.new()
	map_clip.position = Vector2(112, 128)
	map_clip.size = Vector2(980, 820)
	map_clip.clip_contents = true
	add_child(map_clip)
	map_rect = TextureRect.new()
	map_rect.position = Vector2.ZERO
	map_rect.size = Vector2(980, 820)
	map_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	map_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	map_rect.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	map_clip.add_child(map_rect)
	map_mark = ColorRect.new()
	map_mark.color = Color(1.0, 0.92, 0.35, 0.95)
	map_mark.size = Vector2(10, 10)
	map_mark.mouse_filter = Control.MOUSE_FILTER_IGNORE
	map_clip.add_child(map_mark)
	var box := VBoxContainer.new()
	box.position = Vector2(1120, 128)
	box.size = Vector2(680, 820)
	box.add_theme_constant_override("separation", 8)
	add_child(box)
	box.add_child(ThemeS.lab("Local Transport Network", 28, Color(0.95, 0.82, 0.5)))
	box.add_child(ThemeS.lab("Bound crystals on this floor.", 18, Color(0.78, 0.74, 0.66)))
	box.add_child(ThemeS.lab("Y / Tab: Zoom map", 18, Color(0.88, 0.78, 0.48)))
	status = ThemeS.lab(Util.zoom_tip(self), 18, Color(0.7, 0.66, 0.58))
	box.add_child(status)
	var first: Button = null
	for n: Node in CrystalNet.activated_on_floor(host):
		var cell: Vector2i = Vector2i(n.get("crystal_cell"))
		var here: bool = spot != null and Vector2i(spot.get("crystal_cell")) == cell
		var title := "Entrance  ·  CL %d" % int(n.get("crystal_cl"))
		if not bool(n.get("crystal_gate")):
			title = "CL %d Crystal" % int(n.get("crystal_cl"))
		if here:
			title += "  (here)"
		var b := ThemeS.btn(title, func(): _pick_local(cell), not here)
		b.focus_entered.connect(func(): _aim(cell))
		box.add_child(b)
		if first == null and not here:
			first = b
			_aim(cell)
	var back := ThemeS.btn("Back  (B)", func(): _back())
	box.add_child(back)
	focus_btn = first if first else back
	if first == null:
		_aim(Vector2i(spot.get("crystal_cell")) if spot else host.data.spawn)


func _cycle_zoom() -> void:
	if page != "local":
		return
	zoom_lv = (zoom_lv + 1) % 3
	if status:
		status.text = Util.zoom_tip(self)
	_aim(aim_cell)
	App.sfx("ui")


func _aim(cell: Vector2i) -> void:
	aim_cell = cell
	if map_rect == null or host == null or host.map_tex == null:
		return
	var w: int = int(host.data.w)
	var h: int = int(host.data.h)
	var view := Util.zoom_view(self, host)
	view = clampi(view, 1, maxi(w, h))
	var x := 0
	var y := 0
	if view < w:
		x = clampi(cell.x - view / 2, 0, w - view)
	if view < h:
		y = clampi(cell.y - view / 2, 0, h - view)
	var rw: int = mini(view, w)
	var rh: int = mini(view, h)
	var atlas := AtlasTexture.new()
	atlas.atlas = host.map_tex
	atlas.region = Rect2(x, y, rw, rh)
	atlas.filter_clip = true
	map_rect.texture = atlas
	Util.place_mark(self, cell, x, y, rw, rh)


func _pick_local(cell: Vector2i) -> void:
	if spot and Vector2i(spot.get("crystal_cell")) == cell:
		return
	CrystalNet.warp_local(host, cell)
	close_ui()


func _page_floors() -> void:
	Util.panel(self, Vector2(520, 160), Vector2(880, 760))
	var box := VBoxContainer.new()
	box.position = Vector2(552, 192)
	box.size = Vector2(816, 696)
	box.add_theme_constant_override("separation", 8)
	add_child(box)
	box.add_child(ThemeS.lab("Floor Transport Network", 28, Color(0.95, 0.82, 0.5)))
	var deepest := maxi(1, int(App.prog.deepest))
	if page == "band":
		box.add_child(ThemeS.lab("Floors %d–%d" % [band_lo, band_hi], 20, Color(0.78, 0.86, 0.9)))
		_list_floors(box, band_lo, mini(band_hi, deepest), deepest)
	elif deepest > 10:
		box.add_child(ThemeS.lab("Deepest floor: %d" % deepest, 20, Color(0.78, 0.86, 0.9)))
		var lo := 1
		var first: Button = null
		while lo <= deepest:
			var hi: int = lo + 9
			var lab := "Floors %d–%d" % [lo, hi]
			var a := lo
			var b := hi
			var btn := ThemeS.btn(lab, func(): _open_band(a, b))
			box.add_child(btn)
			if first == null:
				first = btn
			lo += 10
		focus_btn = first
	else:
		box.add_child(ThemeS.lab("Deepest floor: %d" % deepest, 20, Color(0.78, 0.86, 0.9)))
		_list_floors(box, 1, deepest, deepest)
	var back := ThemeS.btn("Back  (B)", func(): _back())
	box.add_child(back)
	if focus_btn == null:
		focus_btn = back


func _open_band(lo: int, hi: int) -> void:
	band_lo = lo
	band_hi = hi
	page = "band"
	_rebuild()


func _list_floors(box: VBoxContainer, lo: int, hi: int, deepest: int) -> void:
	var first: Button = null
	for n in range(lo, hi + 1):
		var here: bool = n == App.floor_n
		var reached: bool = n <= deepest
		var title := "Floor %d" % n
		if here:
			title += "  (here)"
		elif not reached:
			title += "  (locked)"
		var btn := ThemeS.btn(title, func(): _pick_floor(n), reached and not here)
		box.add_child(btn)
		if first == null and reached and not here:
			first = btn
	if first:
		focus_btn = first


func _pick_floor(n: int) -> void:
	if n == App.floor_n or n < 1 or n > int(App.prog.deepest):
		return
	close_ui()
	CrystalNet.warp_floor(n)


func _back() -> void:
	if page == "band":
		page = "floors"
		_rebuild()
		return
	if page == "local" or page == "floors":
		page = "root"
		_rebuild()
		return
	close_ui()


func _focus() -> void:
	if focus_btn and not focus_btn.is_queued_for_deletion():
		focus_btn.grab_focus()


func _unhandled_input(event: InputEvent) -> void:
	if page == "local" and Util.zoom_event(event):
		_cycle_zoom()
		get_viewport().set_input_as_handled()
		return
	if event.is_action_pressed("ui_cancel") or event.is_action_pressed("pause") or event.is_action_pressed("dash"):
		App.sfx("ui_cancel")
		_back()
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("interact") or event.is_action_pressed("ui_accept"):
		get_viewport().set_input_as_handled()
