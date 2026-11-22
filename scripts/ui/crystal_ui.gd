extends CanvasLayer

const Plate := preload("res://scripts/ui/plate_chrome.gd")
const CrystalNet := preload("res://scripts/world/crystal/net.gd")
const Util := preload("res://scripts/ui/crystal_ui/ui_util.gd")
const PromptView := preload("res://scripts/ui/prompt_view.gd")
const UiSession := preload("res://scripts/ui/ui_session.gd")
const MenuPad := preload("res://scripts/ui/menu_pad.gd")
const Net := preload("res://scripts/ui/crystal_ui/pages_net.gd")
const Local := preload("res://scripts/ui/crystal_ui/pages_local.gd")
const Floors := preload("res://scripts/ui/crystal_ui/pages_floors.gd")

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
	App.Touch.scene_host().add_child(ui)
	ui.begin(from)

func begin(from: Node) -> void:
	spot = from
	host = App.Touch.scene_host()
	add_to_group("crystal_ui")
	set_meta("btn_skin", "crystal")
	layer = 46
	process_mode = Node.PROCESS_MODE_ALWAYS
	UiSession.open(self)
	page = "root"
	zoom_lv = 0
	_rebuild()

func close_ui() -> void:
	focus_btn = null
	remove_from_group("crystal_ui")
	UiSession.close(self, true)
	var p := get_tree().get_first_node_in_group("player")
	if p:
		p.set("interact_lock", 0.25)
	App.swallow_close_pad()
	App.wake_web_pad()

func _rebuild() -> void:
	for c in get_children():
		if str(c.name) == PromptView.BAR_NAME or str(c.name) == UiSession.MenuFade.NODE:
			continue
		remove_child(c)
		c.queue_free()
	focus_btn = null
	status = null
	map_rect = null
	map_clip = null
	map_mark = null
	Plate.dim(self)
	if page == "local":
		Local.page_local(self)
	elif page == "floors" or page == "band":
		Floors.page_floors(self)
	else:
		Net.page_root(self)
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
	if map_rect == null or map_clip == null or host == null or host.map_tex == null:
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
	map_rect.texture = host.map_tex
	map_rect.stretch_mode = TextureRect.STRETCH_SCALE
	var box: Vector2 = map_clip.size
	var fit: float = minf(box.x / float(rw), box.y / float(rh))
	var drawn := Vector2(float(rw) * fit, float(rh) * fit)
	var origin: Vector2 = (box - drawn) * 0.5
	map_rect.position = origin
	map_rect.size = drawn
	var MapS: GDScript = load("res://scripts/world/dungeon/minimap.gd") as GDScript
	var region := Rect2(float(x) / float(w), float(y) / float(h), float(rw) / float(w), float(rh) / float(h))
	MapS.attach(host, map_rect, region)
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
	if not is_inside_tree():
		return
	if focus_btn == null or not is_instance_valid(focus_btn):
		return
	if focus_btn.is_queued_for_deletion() or not focus_btn.is_inside_tree():
		return
	if focus_btn.focus_mode == Control.FOCUS_NONE:
		return
	focus_btn.grab_focus()

func _process(_delta: float) -> void:
	MenuPad.web_back()

func _input(event: InputEvent) -> void:
	if page == "local" and Util.zoom_event(event):
		_cycle_zoom()
		get_viewport().set_input_as_handled()

func _unhandled_input(event: InputEvent) -> void:
	if page == "local" or page == "floors" or page == "band":
		var td := MenuPad.tab_delta(event)
		if td != 0:
			Net.cycle_net(self, td)
			get_viewport().set_input_as_handled()
			return
	if event.is_action_pressed("ui_cancel") or event.is_action_pressed("pause"):
		App.sfx("ui_cancel")
		_back()
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("interact") or event.is_action_pressed("ui_accept"):
		get_viewport().set_input_as_handled()
