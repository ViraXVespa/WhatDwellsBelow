class_name PadUi
extends Object


static func wire(root: Control) -> void:
	_wire_node(root)


static func _wire_node(n: Node) -> void:
	if n is BaseButton:
		var b := n as BaseButton
		b.focus_mode = Control.FOCUS_ALL
		b.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	elif n is ItemList:
		var il := n as ItemList
		il.focus_mode = Control.FOCUS_ALL
		il.mouse_filter = Control.MOUSE_FILTER_STOP
		if not il.has_meta("pad_list"):
			il.set_meta("pad_list", true)
			il.gui_input.connect(func(ev: InputEvent) -> void:
				_itemlist_gui(ev, il)
			)
	elif n is Control:
		var c := n as Control
		if c is Panel:
			c.mouse_filter = Control.MOUSE_FILTER_STOP
	for child in n.get_children():
		_wire_node(child)


static func _itemlist_gui(event: InputEvent, il: ItemList) -> void:
	if not il.has_focus() or il.item_count <= 0:
		return
	# Analog ui_up/down turbo-scrolls to the last row and steals neighbor focus.
	if event is InputEventJoypadMotion and (
		event.is_action("ui_up") or event.is_action("ui_down") or event.is_action("ui_left") or event.is_action("ui_right")
	):
		il.accept_event()
		return
	var sel := il.get_selected_items()
	var cur := 0 if sel.is_empty() else int(sel[0])
	if event.is_action_pressed("ui_down"):
		if cur < il.item_count - 1:
			il.select(cur + 1)
			il.ensure_current_is_visible()
			il.accept_event()
		return
	if event.is_action_pressed("ui_up"):
		if cur > 0:
			il.select(cur - 1)
			il.ensure_current_is_visible()
			il.accept_event()
		return


static func focus_first(root: Control) -> void:
	var target := _first_focusable(root)
	if target:
		target.grab_focus()


static func _first_focusable(n: Node) -> Control:
	if n is ItemList and (n as ItemList).visible:
		var il := n as ItemList
		if il.item_count > 0:
			return il
	if n is BaseButton and (n as BaseButton).visible and not (n as BaseButton).disabled:
		return n as Control
	for child in n.get_children():
		var found := _first_focusable(child)
		if found:
			return found
	return null
