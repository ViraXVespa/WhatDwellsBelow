extends CanvasLayer

const ThemeS := preload("res://scripts/ui/theme.gd")
const CatalogS := preload("res://scripts/data/catalog.gd")
const Inv := preload("res://scripts/ui/progress_ui_inv.gd")
const Shop := preload("res://scripts/ui/progress_ui_shop.gd")
const Hub := preload("res://scripts/ui/progress_ui_hub.gd")
const GearAct := preload("res://scripts/ui/gear_board_act.gd")
const Board := preload("res://scripts/ui/gear_board.gd")
const Anvil := preload("res://scripts/ui/gear_board_anvil.gd")
const MenuPad := preload("res://scripts/ui/menu_pad.gd")
const Prompts := preload("res://scripts/input/prompts.gd")
const PromptView := preload("res://scripts/ui/prompt_view.gd")

var open := false
var mode := ""
var shop_spot: Node = null
var extract_spot: Node = null
var extract_mailed := false
var extract_role := "gather"
var pending := false
var pending_id := ""
var pending_fn: Callable
var box: VBoxContainer
var status: Label
var focus_btn: Button
var loadout_floor := 1
var loadout_tool := "pickaxe"
var loadout_wpn := "great_axe"
var anvil_item: Dictionary = {}
var anvil_src := ""
var anvil_tab := "analyze"
var forge_t := 0.0
var forge_it: Dictionary = {}
var inv_sel := "slot:weapon"
var gear_mode := ""
var gear_stat_page := 0
var gear_tip_mode := 1
var gear_sub := false
var gear_sub_slot := ""
var gear_x_hold := 0.0
var gear_x_fired := false
var gear_hover := false
var gear_tip: Label
var gear_tip_host: PanelContainer
var gear_stats: Control
var gear_stats_title: Label
var gear_hint: Control
var gear_page_left: Control
var gear_page_right: Control


func _ready() -> void:
	layer = 45
	visible = false
	process_mode = Node.PROCESS_MODE_ALWAYS
	var dim := ColorRect.new()
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	dim.color = Color(0.04, 0.03, 0.02, 0.74)
	add_child(dim)
	var panel := ColorRect.new()
	panel.color = Color(0.14, 0.11, 0.09, 0.96)
	panel.position = Vector2(360, 80)
	panel.size = Vector2(1200, 920)
	add_child(panel)
	var edge := ColorRect.new()
	edge.color = Color(0.55, 0.42, 0.22, 1)
	edge.position = Vector2(360, 80)
	edge.size = Vector2(1200, 8)
	add_child(edge)
	var scroll := ScrollContainer.new()
	scroll.position = Vector2(384, 104)
	scroll.size = Vector2(1152, 832)
	add_child(scroll)
	box = VBoxContainer.new()
	box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	box.add_theme_constant_override("separation", 8)
	scroll.add_child(box)


func close_ui() -> void:
	if mode == "extract" and extract_mailed and extract_spot and is_instance_valid(extract_spot) and extract_spot.has_method("mark_spent"):
		extract_spot.mark_spent()
	extract_spot = null
	extract_mailed = false
	if forge_t > 0.0:
		forge_t = 0.0
		forge_it = {}
	open = false
	visible = false
	pending = false
	pending_id = ""
	anvil_item = {}
	anvil_src = ""
	gear_sub = false
	gear_sub_slot = ""
	gear_hover = false
	var old: Node = get_node_or_null("gear_sub_panel")
	if old:
		old.queue_free()
	if gear_tip_host:
		gear_tip_host.visible = false
	App.ui_open = false
	get_tree().paused = false
	var p := get_tree().get_first_node_in_group("player")
	if p:
		p.set("interact_lock", 0.25)
	App.swallow_close_pad()
	App.wake_web_pad()


func _show() -> void:
	open = true
	visible = true
	App.ui_open = true
	get_tree().paused = true
	_paint_menu_hint()
	call_deferred("_focus")


func _paint_menu_hint() -> void:
	if _gear_busy():
		return
	PromptView.footer(self, [{"action": "ui_cancel", "verb": "leave"}])


func _focus() -> void:
	if mode == "loadout" or mode == "inv" or mode == "anvil":
		var hit: Control = Board.find_sel(self)
		if hit and not hit.is_queued_for_deletion():
			hit.grab_focus()
			return
	if focus_btn and not focus_btn.is_queued_for_deletion():
		focus_btn.grab_focus()


func _wipe(n: Node) -> void:
	while n.get_child_count() > 0:
		var c: Node = n.get_child(0)
		n.remove_child(c)
		c.call_deferred("free")


func _clear() -> void:
	_wipe(box)
	focus_btn = null
	status = null
	gear_tip = null
	gear_stats = null
	gear_stats_title = null
	gear_page_left = null
	gear_page_right = null


func _st(msg: String) -> void:
	if status:
		status.text = msg
	App.sfx("ui")


func open_inventory() -> void:
	mode = "inv"
	inv_sel = "slot:weapon"
	_rebuild_inv()
	_show()


func open_extract(role: String, spot: Node = null) -> void:
	mode = "extract"
	extract_role = role
	extract_spot = spot
	extract_mailed = false
	pending = false
	_rebuild_extract()
	_show()


func open_clerk(role: String) -> void:
	open_extract(role)


func open_shop(spot: Node) -> void:
	mode = "shop"
	shop_spot = spot
	_rebuild_shop()
	_show()


func open_anvil() -> void:
	mode = "anvil"
	pending = false
	anvil_item = {}
	anvil_src = ""
	anvil_tab = "analyze"
	inv_sel = "slot:weapon"
	gear_sub = false
	_rebuild_anvil()
	_show()


func open_loadout() -> void:
	mode = "loadout"
	pending = false
	inv_sel = "slot:weapon"
	gear_sub = false
	loadout_floor = App.prog.start_floor
	loadout_tool = App.prog.tool_type
	loadout_wpn = str(App.prog.slots.weapon.get("weapon", "great_axe")) if not App.prog.slots.weapon.is_empty() else "great_axe"
	_rebuild_loadout()
	_show()


func open_vendor() -> void:
	mode = "vendor"
	_rebuild_vendor()
	_show()


func open_controls() -> void:
	mode = "controls"
	_rebuild_controls()
	_show()


func open_flavor(title: String, body: String) -> void:
	mode = "flavor"
	_clear()
	box.add_child(ThemeS.lab(title, 28, Color(0.95, 0.82, 0.5)))
	box.add_child(ThemeS.lab(body, 22, Color(0.88, 0.82, 0.7)))
	focus_btn = ThemeS.btn("Leave", func(): close_ui())
	box.add_child(focus_btn)
	_show()


func open_quest() -> void:
	mode = "quest"
	if App.prog.quests_offered.is_empty():
		App.prog.roll_quests(true)
	_rebuild_quest()
	_show()


func _rebuild_inv() -> void:
	Inv.rebuild_inv(self)


func _inv_act(uid: int) -> void:
	Inv.inv_act(self, uid)


func _sets_blurb() -> String:
	return Inv.sets_blurb()


func _rebuild_extract() -> void:
	Inv.rebuild_extract(self)


func _do_send_all() -> void:
	_st(App.prog.extract_all(extract_role))
	if App.extracted:
		extract_mailed = true
	_rebuild_extract()
	_show()


func _do_send_one(it: Dictionary) -> void:
	_st(App.prog.extract_one(it, extract_role))
	if App.extracted:
		extract_mailed = true
	_rebuild_extract()
	_show()


func _rebuild_shop() -> void:
	Shop.rebuild_shop(self)


func _rebuild_anvil() -> void:
	Hub.rebuild_anvil(self)


func _rebuild_loadout() -> void:
	Hub.rebuild_loadout(self)


func _rebuild_quest() -> void:
	Hub.rebuild_quest(self)


func _rebuild_vendor() -> void:
	Shop.rebuild_vendor(self)


func _rebuild_controls() -> void:
	Hub.rebuild_controls(self)


func _confirm(fn: Callable, id := "anon") -> void:
	if not pending or pending_id != id:
		pending = true
		pending_id = id
		pending_fn = fn
		_st("Confirm again to proceed.")
		return
	pending = false
	pending_id = ""
	fn.call()


func _extract_all() -> void:
	_st(App.prog.extract_all("gate"))
	extract_mailed = true


func _process(delta: float) -> void:
	if open and _gear_busy():
		GearAct.tick_x(self, delta)
	if forge_t <= 0.0:
		return
	forge_t = maxf(0.0, forge_t - delta)
	if status:
		status.text = "Forging… %.1fs." % forge_t
	if forge_t > 0.0:
		return
	var it: Dictionary = forge_it
	forge_it = {}
	if it.is_empty():
		return
	var msg := App.prog.forge_item(it)
	_st(msg)
	if msg.begins_with("Forged") or msg.begins_with("Re-forged"):
		anvil_item = {}
		anvil_src = ""
	if open and mode == "anvil":
		_rebuild_anvil()
		_show()


func _gear_busy() -> bool:
	return mode == "loadout" or mode == "inv" or mode == "anvil"


func _input(event: InputEvent) -> void:
	if not open or not _gear_busy():
		return
	if event is InputEventMouse or event is InputEventMouseButton:
		return
	if mode == "anvil":
		var td := MenuPad.tab_delta(event)
		if td != 0:
			Anvil.cycle_tab(self, td)
			get_viewport().set_input_as_handled()
			return
	if GearAct.handle_event(self, event):
		get_viewport().set_input_as_handled()


func _unhandled_input(event: InputEvent) -> void:
	if not open:
		return
	if event is InputEventMouse or event is InputEventMouseButton:
		return
	if mode == "anvil":
		var td := MenuPad.tab_delta(event)
		if td != 0:
			Anvil.cycle_tab(self, td)
			get_viewport().set_input_as_handled()
			return
	if _gear_busy() and GearAct.handle_event(self, event):
		get_viewport().set_input_as_handled()
		return
	if event.is_action_pressed("ui_cancel") or event.is_action_pressed("pause") or event.is_action_pressed("dash"):
		if gear_sub or GearAct.swallowing():
			get_viewport().set_input_as_handled()
			return
		if pending:
			pending = false
			pending_id = ""
			App.sfx("ui_cancel")
			_st("Cancelled.")
		elif forge_t > 0.0:
			forge_t = 0.0
			forge_it = {}
			App.sfx("ui_cancel")
			_st("Forge cancelled. Remains stay on the Forge tab.")
		else:
			App.sfx("ui_cancel")
			close_ui()
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("interact") or event.is_action_pressed("ui_accept"):
		get_viewport().set_input_as_handled()
