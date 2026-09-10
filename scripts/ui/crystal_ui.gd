extends CanvasLayer

const ThemeS := preload("res://scripts/ui/theme.gd")
const CrystalNet := preload("res://scripts/world/crystal_net.gd")
const Util := preload("res://scripts/ui/crystal_ui_util.gd")
const PromptView := preload("res://scripts/ui/prompt_view.gd")
const MenuPad := preload("res://scripts/ui/menu_pad.gd")
const Pages := preload("res://scripts/ui/crystal_ui_pages.gd")

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
		if str(c.name) == PromptView.BAR_NAME:
			continue
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
		Pages.page_local(self)
	elif page == "floors" or page == "band":
		Pages.page_floors(self)
	else:
		Pages.page_root(self)
	_paint_hint()
	call_deferred("_focus")


func _paint_hint() -> void:
	var extra: Array = []
	if page == "local":
		extra.append({"action": "crystal_zoom", "verb": "zoom map", "gap": true})
	extra.append({"action": "ui_cancel", "verb": "back"})
	PromptView.footer(self, extra)


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
		x = clampi(cell.x - int(view / 2.0), 0, w - view)
	if view < h:
		y = clampi(cell.y - int(view / 2.0), 0, h - view)
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
	if page == "local" or page == "floors" or page == "band":
		var td := MenuPad.tab_delta(event)
		if td != 0:
			Pages.cycle_net(self, td)
			get_viewport().set_input_as_handled()
			return
	if event.is_action_pressed("ui_cancel") or event.is_action_pressed("pause") or event.is_action_pressed("dash"):
		App.sfx("ui_cancel")
		_back()
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("interact") or event.is_action_pressed("ui_accept"):
		get_viewport().set_input_as_handled()
