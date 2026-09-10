extends Control

const ThemeS := preload("res://scripts/ui/theme.gd")
const Split := preload("res://scripts/ui/split_menu.gd")
const View := preload("res://scripts/ui/split_menu_view.gd")
const Confirm := preload("res://scripts/ui/confirm_dlg.gd")
const BindsPage := preload("res://scripts/ui/binds_page.gd")
const Pages := preload("res://scripts/ui/pause_settings_pages.gd")
const Disp := preload("res://scripts/display_mode.gd")
const PromptView := preload("res://scripts/ui/prompt_view.gd")

const PATREON := "https://www.patreon.com/cw/ViraXVespa"

var pause: CanvasLayer
var open := true
var selected := 0
var col := "list"
var split_page := "gameplay"
var bind_pool := "kb"
var list_box: VBoxContainer
var info_box: VBoxContainer
var list_btns: Array = []
var info_btns: Array = []
var back_btn: Button
var status: Label
@warning_ignore("unused_private_class_variable")
var _list_root: Control
@warning_ignore("unused_private_class_variable")
var _info_root: Control
@warning_ignore("unused_private_class_variable")
var _list_rule: ColorRect
@warning_ignore("unused_private_class_variable")
var _info_rule: ColorRect
var _chevron: Label
@warning_ignore("unused_private_class_variable")
var _path: Label


static func build(ui: CanvasLayer) -> void:
	var host: Control = new()
	host.name = "settings_host"
	host.pause = ui
	host.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	host.size_flags_vertical = Control.SIZE_EXPAND_FILL
	var body_h: float = 800.0
	if ui.scroll:
		ui.scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
		if ui.scroll.size.y > 1.0:
			body_h = ui.scroll.size.y
	host.custom_minimum_size = Vector2(1400, body_h)
	ui.box.add_child(host)
	host._setup()


func _setup() -> void:
	open = true
	col = "list"
	selected = 0
	split_page = "gameplay"
	View.setup_embed(self, self)
	Split.rebuild(self)
	_sync_leaf()


func split_rows() -> Array:
	var out: Array = [
		{"id": "gameplay", "label": "Gameplay", "kind": "page"},
		{"id": "audio", "label": "Audio", "kind": "page"},
		{"id": "graphics", "label": "Graphics", "kind": "page"},
		{"id": "controls", "label": "Controls", "kind": "page"},
		{"id": "patreon", "label": "Patreon", "kind": "leaf"},
	]
	if App.in_dungeon:
		out.append({"id": "leave", "label": "Dispel", "kind": "leaf"})
	else:
		out.append({"id": "leave", "label": "Main Menu", "kind": "leaf"})
	if not Disp.is_xbox():
		out.append({"id": "quit", "label": "Quit", "kind": "leaf"})
	return out


func split_back_label() -> String:
	return ""


func split_path_text() -> String:
	return ""


func split_hint() -> void:
	if pause == null:
		return
	var extra: Array = []
	if col == "list":
		var row: Dictionary = Split.current(self)
		if Split.is_leaf(row):
			extra.append({"action": "ui_accept", "verb": "select", "gap": true})
		else:
			extra.append({"action": "ui_accept", "verb": "open", "gap": true})
		extra.append({"action": "ui_cancel", "verb": "close"})
	else:
		extra.append({"action": "ui_cancel", "verb": "back"})
	PromptView.footer(pause, extra)


func split_close() -> void:
	if pause and pause.has_method("close_ui"):
		pause.close_ui()


func split_activate_leaf(id: String) -> void:
	match id:
		"patreon":
			OS.shell_open(PATREON)
		"leave":
			if App.in_dungeon:
				Confirm.open(pause, "Dispel Avatar", "End this run and return to Placeholdia?", func() -> void:
					pause.close_ui()
					App.end_run("dispel")
				)
			else:
				Confirm.open(pause, "Main Menu", "Return to the title screen?", func() -> void:
					pause.close_ui()
					App.go_title()
				)
		"quit":
			Disp.request_quit()


func split_build_page(id: String) -> void:
	View.clear_page(self)
	match id:
		"gameplay":
			Pages.page_gameplay(self)
		"audio":
			Pages.page_audio(self)
		"graphics":
			Pages.page_graphics(self)
		"controls":
			BindsPage.build(self)
		"patreon":
			_leaf_copy("Support development on Patreon. Opens in your browser.")
		"leave":
			if App.in_dungeon:
				_leaf_copy("End this run and return to Placeholdia. Unextracted loot is lost.")
			else:
				_leaf_copy("Return to the title screen.")
		"quit":
			_leaf_copy("Close the game.")
		_:
			pass
	View.wire_vert(info_btns)
	View.path_text(self)
	_sync_leaf()
	View.tune_host(self)


func _leaf_copy(text: String) -> void:
	var lab: Label = ThemeS.lab(text, 22, Color(0.88, 0.82, 0.72))
	lab.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	lab.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lab.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	lab.custom_minimum_size = Vector2(520, 80)
	info_box.add_child(lab)


func _sync_leaf() -> void:
	if _chevron:
		_chevron.visible = Split.is_page(Split.current(self))


func _on_list_pressed(i: int) -> void:
	Split.list_pressed(self, i)
	_sync_leaf()


func _on_list_focus(i: int) -> void:
	if col == "detail":
		return
	Split.preview(self, i)
	var row: Dictionary = Split.row_at(self, i)
	if Split.is_leaf(row):
		split_build_page(str(row.get("id", "")))
	_sync_leaf()


func _on_list_hover(i: int) -> void:
	if col == "detail":
		return
	_on_list_focus(i)


func _focus_col() -> void:
	View.focus_col(self)
	_sync_leaf()


func _place_chevron() -> void:
	View.place_chevron(self)
	_sync_leaf()
