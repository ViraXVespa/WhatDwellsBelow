extends Object

const ThemeS := preload("res://scripts/ui/theme.gd")
const CatalogS := preload("res://scripts/data/catalog.gd")
const T := preload("res://scripts/data/tunables.gd")
const PauseInv := preload("res://scripts/ui/pause_inv.gd")
const PauseSkills := preload("res://scripts/ui/pause_skills.gd")
const PauseSettings := preload("res://scripts/ui/pause_settings.gd")
const GearAct := preload("res://scripts/ui/gear_board/gear_board_act.gd")
const Board := preload("res://scripts/ui/gear_board/gear_board.gd")
const Util := preload("res://scripts/ui/pause_menu_util.gd")
const View := preload("res://scripts/ui/pause_menu_view.gd")
const Pad := preload("res://scripts/ui/menu_pad.gd")
const Prompts := preload("res://scripts/input/prompts.gd")
const PromptView := preload("res://scripts/ui/prompt_view.gd")
const UiSession := preload("res://scripts/ui/ui_session.gd")
const UiText := preload("res://scripts/ui/ui_text.gd")
const Disp := preload("res://scripts/display_mode.gd")
const Confirm := preload("res://scripts/ui/confirm_dlg.gd")
const Split := preload("res://scripts/ui/split_menu.gd")

static func toggle(host: CanvasLayer) -> void:
	if host.open:
		host.close_ui()
	else:
		host.show_menu()



static func show_menu(host: CanvasLayer) -> void:
	host.open = true
	host.visible = true
	UiSession.open(host)
	host.tab = host.TAB_SETTINGS
	host.sys_page = "main"
	host.pending = false
	host.pending_id = ""
	host.rebind_action = ""
	host.inv_sel = "slot:weapon"
	host.gear_mode = "inv"
	host.gear_sub = false
	host.gear_sub_slot = ""
	host.gear_hover = false
	host.set_meta("gear_tip_restore", false)
	Util.hide_tip(host)
	Board.hide_tip(host)
	Board._flag(host, "gear_hover", false)
	Board._flag(host, "gear_tip_ready", false)
	host._rebuild()



static func show_inventory(host: CanvasLayer) -> void:
	if not host.open:
		host.show_menu()
	if host.tab != host.TAB_INV:
		host.tab = host.TAB_INV
		host.sys_page = "main"
		host._rebuild()



static func close_ui(host: CanvasLayer) -> void:
	host.open = false
	host.visible = false
	host.pending = false
	host.pending_id = ""
	host.rebind_action = ""
	host.sys_page = "main"
	host.gear_sub = false
	host.gear_sub_slot = ""
	host.gear_hover = false
	host.set_meta("gear_tip_restore", false)
	Confirm.close(host)
	var old: Node = host.get_node_or_null("gear_sub_panel")
	if old:
		old.queue_free()
	if host.gear_tip_host:
		host.gear_tip_host.visible = false
	Util.hide_tip(host)
	Board.hide_tip(host)
	Board._flag(host, "gear_hover", false)
	Board._flag(host, "gear_tip_ready", false)
	UiSession.close(host)
	App.save_now()
	App.swallow_close_pad()
	App.wake_web_pad()
	Disp.consume_web_esc()
