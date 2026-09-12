extends CanvasLayer

const ThemeS := preload("res://scripts/ui/theme.gd")
const CatalogS := preload("res://scripts/data/catalog.gd")
const Inv := preload("res://scripts/ui/progress_ui_inv.gd")
const Shop := preload("res://scripts/ui/progress_ui_shop.gd")
const Hub := preload("res://scripts/ui/progress_ui_hub.gd")
const GearAct := preload("res://scripts/ui/gear_board/gear_board_act.gd")
const Board := preload("res://scripts/ui/gear_board/gear_board.gd")
const Anvil := preload("res://scripts/ui/gear_board/gear_board_anvil.gd")
const ForgeUI := preload("res://scripts/ui/gear_board/gear_board_anvil_forge.gd")
const MenuPad := preload("res://scripts/ui/menu_pad.gd")
const Prompts := preload("res://scripts/input/prompts.gd")
const PromptView := preload("res://scripts/ui/prompt_view.gd")
const Flow := preload("res://scripts/ui/progress_ui_flow.gd")

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
var forge_wait := 0.0
var forge_it: Dictionary = {}
var forge_type := ""
var forge_rarity := "green"
var forge_ilvl := 1
var forge_qty := 1
var forge_left := 0
var forge_need := 0
var forge_locks: PackedStringArray = PackedStringArray()
var forge_new: Dictionary = {}
var forge_batch: Array = []
var forge_picks: Array = []
var forge_phase := ""
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
	Flow._ready(self)

func _drop_sub() -> void:
	gear_sub = false
	gear_sub_slot = ""
	var old: Node = get_node_or_null("gear_sub_panel")
	while old:
		old.name = "gear_sub_dead"
		old.queue_free()
		old = get_node_or_null("gear_sub_panel")
	ForgeUI.reset_job(self)



func _sub_up() -> bool:
	if gear_sub:
		return true
	var old: Node = get_node_or_null("gear_sub_panel")
	return old != null and not old.is_queued_for_deletion()



func close_ui() -> void:
	Flow.close_ui(self)

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
	Flow._focus(self)

func _wipe(n: Node) -> void:
	while n.get_child_count() > 0:
		var c: Node = n.get_child(0)
		n.remove_child(c)
		c.call_deferred("free")



func _clear() -> void:
	Board.hide_tip(self)
	Board._flag(self, "gear_hover", false)
	Board._flag(self, "gear_tip_ready", false)
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
	_drop_sub()
	_rebuild_inv()
	_show()



func open_extract(role: String, spot: Node = null) -> void:
	mode = "extract"
	extract_role = role
	extract_spot = spot
	extract_mailed = false
	pending = false
	_drop_sub()
	_rebuild_extract()
	_show()



func open_clerk(role: String) -> void:
	open_extract(role)



func open_shop(spot: Node) -> void:
	mode = "shop"
	shop_spot = spot
	_drop_sub()
	_rebuild_shop()
	_show()



func open_anvil() -> void:
	Flow.open_anvil(self)

func open_loadout() -> void:
	Flow.open_loadout(self)

func open_vendor() -> void:
	mode = "vendor"
	_drop_sub()
	_rebuild_vendor()
	_show()



func open_controls() -> void:
	mode = "controls"
	_drop_sub()
	_rebuild_controls()
	_show()



func open_flavor(title: String, body: String) -> void:
	Flow.open_flavor(self, title, body)

func open_quest() -> void:
	mode = "quest"
	_drop_sub()
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



func _buy_snack() -> void:
	Shop.buy_snack(self)


func _buy_art(id: String, nm: String) -> void:
	Shop.buy_art(self, id, nm)


func _extract_all() -> void:
	_st(App.prog.extract_all("gate"))
	extract_mailed = true



func _process(delta: float) -> void:
	Flow._process(self, delta)

func _gear_busy() -> bool:
	return mode == "loadout" or mode == "inv" or mode == "anvil"



func _input(event: InputEvent) -> void:
	Flow._input(self, event)

func _unhandled_input(event: InputEvent) -> void:
	Flow._unhandled_input(self, event)
