extends Object

const ThemeS := preload("res://scripts/ui/theme.gd")
const Split := preload("res://scripts/ui/split_menu.gd")
const Chrome := preload("res://scripts/ui/split_menu_chrome.gd")

const COL_LIVE := Color(1, 1, 1, 1)
const COL_DIM := Color(0.55, 0.52, 0.48, 1)
const RULE_ON := Color(0.95, 0.78, 0.35, 1)
const RULE_OFF := Color(0.35, 0.28, 0.18, 1)
const GOLD := Color(1, 0.92, 0.45, 1)


static func _live(host: Node) -> bool:
	return host != null and is_instance_valid(host)


static func setup_overlay(host: Node, title_text: String, hint_text: String) -> void:
	if not _live(host):
		return
	Chrome.setup_overlay(host, title_text, hint_text)


static func setup_embed(host: Node, parent: Control) -> void:
	if not _live(host):
		return
	Chrome.setup_embed(host, parent)


static func _col_scroll(host: Node, key: String) -> ScrollContainer:
	if not _live(host):
		return null
	if host.has_meta(key):
		var n: Variant = host.get_meta(key)
		if n is ScrollContainer:
			return n as ScrollContainer
	return null


static func tune_scroll(sc: ScrollContainer) -> void:
	if sc == null or not is_instance_valid(sc):
		return
	sc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	var need := false
	if sc.size.y > 1.0 and sc.get_child_count() > 0 and sc.get_child(0) is Control:
		var c: Control = sc.get_child(0) as Control
		need = c.get_combined_minimum_size().y > sc.size.y + 2.0
	sc.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_SHOW_ALWAYS if need else ScrollContainer.SCROLL_MODE_SHOW_NEVER


static func tune_host(host: Node) -> void:
	if not _live(host):
		return
	tune_scroll(_col_scroll(host, "_list_scroll"))
	tune_scroll(_col_scroll(host, "_info_scroll"))


static func rebuild_list(host: Node) -> void:
	if not _live(host) or host.list_box == null:
		return
	for c: Node in host.list_box.get_children():
		c.queue_free()
	host.list_btns.clear()
	host.back_btn = null
	var list: Array = Split.rows(host)
	var n: int = list.size()
	for i: int in n:
		var row: Dictionary = Split.row_at(host, i)
		var ii: int = i
		var b: Button = ThemeS.btn(str(row.get("label", row.get("id", ""))), func() -> void: host._on_list_pressed(ii))
		b.focus_entered.connect(func() -> void: host._on_list_focus(ii))
		b.mouse_entered.connect(func() -> void: host._on_list_hover(ii))
		host.list_box.add_child(b)
		host.list_btns.append(b)
	var back_lab: String = ""
	if host.has_method("split_back_label"):
		back_lab = str(host.split_back_label())
	if back_lab != "":
		host.back_btn = ThemeS.btn(back_lab, func() -> void: Split.back(host))
		host.list_box.add_child(host.back_btn)
	paint_list(host)
	var chain: Array = []
	for b: Variant in host.list_btns:
		chain.append(b)
	if host.back_btn:
		chain.append(host.back_btn)
	wire_vert(chain)
	if host.get_tree():
		host.get_tree().process_frame.connect(func() -> void:
			if _live(host):
				tune_host(host)
		, CONNECT_ONE_SHOT)


static func rebuild_page(host: Node) -> void:
	clear_page(host)


static func clear_page(host: Node) -> void:
	if not _live(host) or host.info_box == null:
		return
	for c: Node in host.info_box.get_children():
		c.queue_free()
	host.info_btns.clear()
	path_text(host)
	if host.get_tree():
		host.get_tree().process_frame.connect(func() -> void:
			if _live(host):
				tune_host(host)
		, CONNECT_ONE_SHOT)


static func add_page_btn(host: Node, b: Button) -> void:
	if not _live(host) or host.info_box == null:
		return
	host.info_box.add_child(b)
	host.info_btns.append(b)


static func paint_list(host: Node) -> void:
	if not _live(host):
		return
	var selected: int = int(host.get("selected"))
	for i: int in host.list_btns.size():
		var b: Button = host.list_btns[i]
		if not is_instance_valid(b):
			continue
		if i == selected:
			b.add_theme_color_override("font_color", GOLD)
		else:
			b.remove_theme_color_override("font_color")
	if host.has_method("_place_chevron"):
		host.call_deferred("_place_chevron")
	else:
		place_chevron(host)


static func place_chevron(host: Node) -> void:
	if not _live(host) or host._chevron == null or host._list_root == null:
		return
	var y: float = host._list_root.position.y
	var selected: int = int(host.get("selected"))
	if selected >= 0 and selected < host.list_btns.size() and is_instance_valid(host.list_btns[selected]):
		var b: Button = host.list_btns[selected]
		y = host._list_root.position.y + b.position.y + maxf(b.size.y, 44.0) * 0.5 - 16.0
	host._chevron.position.y = y


static func apply_col(host: Node) -> void:
	if not _live(host):
		return
	var col: String = str(host.get("col"))
	var leaf: bool = Split.is_leaf(Split.current(host))
	if host._list_root:
		host._list_root.modulate = COL_LIVE if col == "list" else COL_DIM
	if host._info_root:
		host._info_root.modulate = COL_LIVE if (col == "detail" or leaf) else COL_DIM
	if host._list_rule:
		host._list_rule.color = RULE_ON if col == "list" else RULE_OFF
	if host._info_rule:
		host._info_rule.color = RULE_ON if (col == "detail" or leaf) else RULE_OFF
	if host._chevron:
		host._chevron.modulate = GOLD if col == "detail" else Color(0.45, 0.4, 0.3, 1)
	set_col_focus(host)
	path_text(host)
	if host.has_method("split_hint"):
		host.split_hint()
	place_chevron(host)
	tune_host(host)


static func _focusable(n: Variant) -> bool:
	if n == null or not is_instance_valid(n) or not (n is Control):
		return false
	if n is BaseButton and (n as BaseButton).disabled:
		return false
	return true


static func set_col_focus(host: Node) -> void:
	if not _live(host):
		return
	var list_on: bool = str(host.get("col")) == "list"
	for b: Variant in host.list_btns:
		if is_instance_valid(b) and b is Control:
			(b as Control).focus_mode = Control.FOCUS_ALL if list_on else Control.FOCUS_NONE
	if host.back_btn and is_instance_valid(host.back_btn):
		host.back_btn.focus_mode = Control.FOCUS_ALL if list_on else Control.FOCUS_NONE
	var detail_on: bool = str(host.get("col")) == "detail"
	for b: Variant in host.info_btns:
		if not _focusable(b):
			if b is Control and is_instance_valid(b):
				(b as Control).focus_mode = Control.FOCUS_NONE
			continue
		(b as Control).focus_mode = Control.FOCUS_ALL if detail_on else Control.FOCUS_NONE


static func focus_col(host: Node) -> void:
	if not _live(host) or not bool(host.get("open")):
		return
	var col: String = str(host.get("col"))
	var selected: int = int(host.get("selected"))
	if col == "list":
		if selected >= 0 and selected < host.list_btns.size() and is_instance_valid(host.list_btns[selected]):
			(host.list_btns[selected] as Control).grab_focus()
		elif host.back_btn and is_instance_valid(host.back_btn):
			host.back_btn.grab_focus()
	else:
		var c: Control = first_enabled_info(host)
		if c:
			c.grab_focus()
	place_chevron(host)


static func first_enabled_info(host: Node) -> Control:
	if not _live(host):
		return null
	for b: Variant in host.info_btns:
		if not _focusable(b):
			continue
		return b as Control
	return null


static func wire_vert(btns: Array) -> void:
	var live: Array = []
	for b: Variant in btns:
		if _focusable(b):
			live.append(b)
	var n: int = live.size()
	if n == 0:
		return
	for i: int in n:
		var c: Control = live[i]
		var prev: Control = live[n - 1 if i == 0 else i - 1]
		var nxt: Control = live[0 if i == n - 1 else i + 1]
		c.focus_neighbor_top = prev.get_path()
		c.focus_neighbor_bottom = nxt.get_path()
		c.focus_next = nxt.get_path()
		c.focus_previous = prev.get_path()
		c.focus_neighbor_left = c.get_path()
		c.focus_neighbor_right = c.get_path()


static func path_text(host: Node) -> void:
	if not _live(host) or host.get("_path") == null:
		return
	if host.has_method("split_path_text"):
		host._path.text = str(host.split_path_text())
		return
	var row: Dictionary = Split.current(host)
	var lab: String = str(row.get("label", ""))
	if str(host.get("col")) == "list" or lab == "":
		host._path.text = ""
		return
	host._path.text = lab
