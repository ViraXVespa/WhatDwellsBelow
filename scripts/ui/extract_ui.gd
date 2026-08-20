class_name ExtractUI
extends CanvasLayer

var panel: Panel
var title: Label
var list: ItemList
var clerk: Clerk
var hint: Label


func _ready() -> void:
	add_to_group("extract_ui")
	layer = 35
	process_mode = Node.PROCESS_MODE_ALWAYS
	panel = Panel.new()
	panel.visible = false
	panel.position = Vector2(520, 160)
	panel.size = Vector2(880, 640)
	add_child(panel)
	var v := VBoxContainer.new()
	v.set_anchors_preset(Control.PRESET_FULL_RECT)
	v.offset_left = 28
	v.offset_top = 24
	v.offset_right = -28
	v.offset_bottom = -24
	v.add_theme_constant_override("separation", 10)
	panel.add_child(v)
	title = Label.new()
	title.add_theme_font_size_override("font_size", 28)
	v.add_child(title)
	hint = Label.new()
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	hint.add_theme_font_size_override("font_size", 18)
	v.add_child(hint)
	list = ItemList.new()
	list.custom_minimum_size = Vector2(0, 280)
	v.add_child(list)
	v.add_child(_btn("Send selected", _send_selected))
	v.add_child(_btn("Send gold instead (50% to town, 10% fee, clerk spent)", _send_gold))
	v.add_child(_btn("Close", close))
	PadUi.wire(panel)


func _unhandled_input(event: InputEvent) -> void:
	if not panel.visible:
		return
	if event.is_action_pressed("ui_cancel"):
		close()
		get_viewport().set_input_as_handled()
		return
	if event.is_action_pressed("ui_accept") and list.has_focus() and list.item_count > 0:
		_send_selected()
		get_viewport().set_input_as_handled()


func open_for(c: Clerk) -> void:
	clerk = c
	Sfx.play("ui")
	panel.visible = true
	get_tree().paused = true
	_refresh()
	PadUi.focus_first(panel)


func close() -> void:
	panel.visible = false
	get_tree().paused = false
	clerk = null


func _refresh() -> void:
	list.clear()
	if clerk == null or Game.run == null:
		return
	title.text = clerk.display_name()
	if clerk.clerk_id == "gopher":
		hint.text = "Gear Gopher. I'll take axes and picks for analysis. Three per type — you pick what to evict."
		if clerk.spent_normal:
			hint.text += "\nI've already done my gear run. Gold only — or goodbye."
		else:
			for row in Game.run.items_of_kind(ItemData.Kind.WEAPON) + Game.run.items_of_kind(ItemData.Kind.TOOL):
				var it: ItemData = row.item
				list.add_item("%s  [%s]" % [it.full_name(), "green" if it.rarity == ItemData.Rarity.GREEN else "white"])
				list.set_item_metadata(list.item_count - 1, row.index)
	elif clerk.clerk_id == "runner":
		hint.text = "Guild Runner. Food, potions, junk. Not rocks, not your fancy axe. I have a route."
		if clerk.spent_normal:
			hint.text += "\nThat's my last parcel."
		else:
			for i in RunState.BAG_SIZE:
				var it: ItemData = Game.run.bag[i]
				if it and it.kind == ItemData.Kind.CONSUMABLE:
					list.add_item(it.full_name())
					list.set_item_metadata(list.item_count - 1, i)
	else:
		var fam := clerk.family_accepted()
		hint.text = "I'll take %s. Gold mail is my whole shift if you ask — pick one, I've got a lunch." % fam
		if clerk.spent_normal:
			hint.text = "I already took my category. Gold's still an option until I close shop."
		else:
			for row in Game.run.items_of_family(fam):
				var it: ItemData = row.item
				list.add_item(it.full_name())
				list.set_item_metadata(list.item_count - 1, row.index)
	hint.text += "\nCarried gold: %d\nA confirm  |  B close  |  stick/D-pad move" % Game.run.gold
	if list.item_count > 0:
		list.select(0)


func _send_selected() -> void:
	if clerk == null or Game.run == null:
		return
	if clerk.spent_normal or clerk.spent_gold:
		return
	if list.get_selected_items().is_empty():
		return
	var idx: int = list.get_item_metadata(list.get_selected_items()[0])
	if clerk.clerk_id == "gopher":
		var result = Game.extract_gear(idx)
		if result is Array:
			_overwrite_picker(result)
			return
		clerk.spent_normal = false
		_refresh()
		return
	if clerk.clerk_id == "runner":
		Game.extract_misc(idx)
		_refresh()
		return
	Game.extract_ore(idx)
	_refresh()


func _overwrite_picker(existing: Array) -> void:
	list.clear()
	hint.text = "Stash full. Pick a slot to overwrite."
	for i in existing.size():
		var it: ItemData = existing[i]
		list.add_item("Replace: " + it.full_name())
		list.set_item_metadata(i, i)
	for child in panel.get_children():
		pass
	var confirm := _btn("Overwrite selected slot", func():
		if list.get_selected_items().is_empty():
			return
		var slot: int = list.get_item_metadata(list.get_selected_items()[0])
		Game.confirm_overwrite("", slot)
		_refresh()
	)
	panel.get_child(0).add_child(confirm)


func _send_gold() -> void:
	if clerk == null or Game.run == null:
		return
	if clerk.spent_gold:
		return
	Game.mail_gold()
	clerk.spent_gold = true
	clerk.spent_normal = true
	_refresh()
	close()


func _btn(text: String, cb: Callable) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(0, 48)
	b.pressed.connect(cb)
	return b
