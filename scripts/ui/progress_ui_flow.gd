extends Object

const ThemeS := preload("res://scripts/ui/theme.gd")
const CatalogS := preload("res://scripts/data/catalog.gd")
const Inv := preload("res://scripts/ui/progress_ui_inv.gd")
const Shop := preload("res://scripts/ui/progress_ui_shop.gd")
const Hub := preload("res://scripts/ui/progress_ui_hub.gd")
const GearAct := preload("res://scripts/ui/gear_board_act.gd")
const Board := preload("res://scripts/ui/gear_board.gd")
const Anvil := preload("res://scripts/ui/gear_board_anvil.gd")
const ForgeUI := preload("res://scripts/ui/gear_board_anvil_forge.gd")
const MenuPad := preload("res://scripts/ui/menu_pad.gd")
const Prompts := preload("res://scripts/input/prompts.gd")
const PromptView := preload("res://scripts/ui/prompt_view.gd")

static func _ready(host: CanvasLayer) -> void:
	host.layer = 45
	host.visible = false
	host.process_mode = Node.PROCESS_MODE_ALWAYS
	var dim := ColorRect.new()
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	dim.color = Color(0.04, 0.03, 0.02, 0.74)
	host.add_child(dim)
	var panel := ColorRect.new()
	panel.color = Color(0.14, 0.11, 0.09, 0.96)
	panel.position = Vector2(360, 80)
	panel.size = Vector2(1200, 920)
	host.add_child(panel)
	var edge := ColorRect.new()
	edge.color = Color(0.55, 0.42, 0.22, 1)
	edge.position = Vector2(360, 80)
	edge.size = Vector2(1200, 8)
	host.add_child(edge)
	var scroll := ScrollContainer.new()
	scroll.position = Vector2(384, 104)
	scroll.size = Vector2(1152, 832)
	host.add_child(scroll)
	host.box = VBoxContainer.new()
	host.box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	host.box.add_theme_constant_override("separation", 8)
	scroll.add_child(host.box)



static func close_ui(host: CanvasLayer) -> void:
	if host.mode == "extract" and host.extract_mailed and host.extract_spot and is_instance_valid(host.extract_spot) and host.extract_spot.has_method("mark_spent"):
		host.extract_spot.mark_spent()
	host.extract_spot = null
	host.extract_mailed = false
	host._drop_sub()
	host.open = false
	host.visible = false
	host.pending = false
	host.pending_id = ""
	host.anvil_item = {}
	host.anvil_src = ""
	host.gear_hover = false
	if host.gear_tip_host:
		host.gear_tip_host.visible = false
	App.ui_open = false
	host.get_tree().paused = false
	var p := host.get_tree().get_first_node_in_group("player")
	if p:
		p.set("interact_lock", 0.25)
	App.swallow_close_pad()
	App.wake_web_pad()



static func _focus(host: CanvasLayer) -> void:
	if host._sub_up():
		return
	if host.mode == "loadout" or host.mode == "inv" or host.mode == "anvil":
		var hit: Control = Board.find_sel(host)
		if hit and is_instance_valid(hit) and hit.is_inside_tree() and not hit.is_queued_for_deletion():
			if hit.focus_mode != Control.FOCUS_NONE:
				hit.grab_focus()
				return
	if host.focus_btn and is_instance_valid(host.focus_btn) and host.focus_btn.is_inside_tree() and not host.focus_btn.is_queued_for_deletion():
		if host.focus_btn.focus_mode != Control.FOCUS_NONE:
			host.focus_btn.grab_focus()



static func open_anvil(host: CanvasLayer) -> void:
	host.mode = "anvil"
	host.pending = false
	host.anvil_item = {}
	host.anvil_src = ""
	host.anvil_tab = "analyze"
	host.inv_sel = "slot:weapon"
	host._drop_sub()
	host.forge_type = ""
	host.forge_rarity = "green"
	host.forge_ilvl = 1
	host.forge_qty = 1
	host.forge_locks = PackedStringArray()
	host._rebuild_anvil()
	host._show()



static func open_loadout(host: CanvasLayer) -> void:
	host.mode = "loadout"
	host.pending = false
	host.inv_sel = "slot:weapon"
	host._drop_sub()
	host.loadout_floor = App.prog.start_floor
	host.loadout_tool = App.prog.tool_type
	host.loadout_wpn = str(App.prog.slots.weapon.get("weapon", "great_axe")) if not App.prog.slots.weapon.is_empty() else "great_axe"
	host._rebuild_loadout()
	host._show()



static func open_flavor(host: CanvasLayer, title: String, body: String) -> void:
	host.mode = "flavor"
	host._drop_sub()
	host._clear()
	host.box.add_child(ThemeS.lab(title, 28, Color(0.95, 0.82, 0.5)))
	host.box.add_child(ThemeS.lab(body, 22, Color(0.88, 0.82, 0.7)))
	host.focus_btn = ThemeS.btn("Leave", func(): host.close_ui())
	host.box.add_child(host.focus_btn)
	host._show()



static func _process(host: CanvasLayer, delta: float) -> void:
	if host.open and host._gear_busy():
		GearAct.tick_x(host, delta)
	if host.forge_t <= 0.0:
		return
	host.forge_t = maxf(0.0, host.forge_t - delta)
	if host.status:
		var done: int = maxi(0, host.forge_need - host.forge_left) + 1
		host.status.text = "Forging %d of %d… %.1fs." % [mini(done, maxi(1, host.forge_need)), maxi(1, host.forge_need), host.forge_t]
	if host.forge_t > 0.0:
		if host.gear_sub:
			ForgeUI.refresh_bar(host)
		return
	ForgeUI.finish(host)



static func _input(host: CanvasLayer, event: InputEvent) -> void:
	if not host.open or not host._gear_busy():
		return
	if event is InputEventMouse or event is InputEventMouseButton:
		return
	if host.mode == "anvil":
		var td := MenuPad.tab_delta(event)
		if td != 0:
			Anvil.cycle_tab(host, td)
			host.get_viewport().set_input_as_handled()
			return
	if GearAct.handle_event(host, event):
		host.get_viewport().set_input_as_handled()



static func _unhandled_input(host: CanvasLayer, event: InputEvent) -> void:
	if not host.open:
		return
	if event is InputEventMouse or event is InputEventMouseButton:
		return
	if host.mode == "anvil":
		var td := MenuPad.tab_delta(event)
		if td != 0:
			Anvil.cycle_tab(host, td)
			host.get_viewport().set_input_as_handled()
			return
	if host._gear_busy() and GearAct.handle_event(host, event):
		host.get_viewport().set_input_as_handled()
		return
	if event.is_action_pressed("ui_cancel") or event.is_action_pressed("pause") or event.is_action_pressed("dash"):
		if host._sub_up() or GearAct.swallowing():
			if host._sub_up() and not GearAct.swallowing():
				if host.forge_phase == "work":
					ForgeUI.cancel_job(host)
				elif host.forge_phase == "pick":
					ForgeUI.keep_old(host)
				else:
					GearAct.close_sub(host)
			host.get_viewport().set_input_as_handled()
			return
		if host.pending:
			host.pending = false
			host.pending_id = ""
			App.sfx("ui_cancel")
			host._st("Cancelled.")
		elif host.forge_t > 0.0:
			ForgeUI.cancel_job(host)
			App.sfx("ui_cancel")
			host._st("Forge cancelled. Materials stay spent.")
		else:
			App.sfx("ui_cancel")
			host.close_ui()
		host.get_viewport().set_input_as_handled()
	elif event.is_action_pressed("interact") or event.is_action_pressed("ui_accept"):
		host.get_viewport().set_input_as_handled()

