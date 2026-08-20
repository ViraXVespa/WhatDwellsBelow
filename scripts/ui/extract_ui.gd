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
	v.add_child(_btn("Analyze selected (recipe)", _send_selected))
	v.add_child(_btn("Send selected for Smithing XP", _send_xp))
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
		hint.text = "Gear Gopher. Unequip first — I only take bag gear. Analyze now = anvil recipe. If you already unlocked that family, you can send extras for Smithing XP instead."
		if clerk.spent_normal:
			hint.text += "\nI've already done my gear run. Gold only — or goodbye."
		else:
			for row in Game.run.mailable_gear():
				var it: ItemData = row.item
				var extra := "recipe"
				if Game.save.family_unlocked(it.hold_key()):
					extra = "already unlocked — analyze or XP"
				list.add_item("%s  [%s]" % [it.full_name(), extra])
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
	elif clerk.clerk_id == "patty":
		hint.text = "Packmule Patty. Lucky day — I'll haul whatever isn't nailed down."
		if clerk.spent_normal:
			hint.text += "\nMule's loaded. Gold's still an option."
		else:
			for i in RunState.BAG_SIZE:
				var it: ItemData = Game.run.bag[i]
				if it:
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
		Game.analyze_gear(idx, false)
		_refresh()
		return
	if clerk.clerk_id == "runner":
		Game.extract_misc(idx)
		_refresh()
		return
	if clerk.clerk_id == "patty":
		var it: ItemData = Game.run.bag[idx] if idx >= 0 and idx < RunState.BAG_SIZE else null
		if it == null:
			return
		if it.family == "ore":
			Game.extract_ore(idx)
		elif it.kind in [ItemData.Kind.WEAPON, ItemData.Kind.TOOL, ItemData.Kind.ARMOR, ItemData.Kind.POTION]:
			Game.analyze_gear(idx, false)
		else:
			Game.extract_misc(idx)
		_refresh()
		return
	Game.extract_ore(idx)
	_refresh()


func _send_xp() -> void:
	if clerk == null or Game.run == null:
		return
	if clerk.clerk_id != "gopher" and clerk.clerk_id != "patty":
		return
	if list.get_selected_items().is_empty():
		return
	var idx: int = list.get_item_metadata(list.get_selected_items()[0])
	var it: ItemData = Game.run.bag[idx] if idx >= 0 else null
	if it == null:
		return
	if not Game.save.family_unlocked(it.hold_key()):
		hint.text = "Nothing to duplicate yet. Analyze it first so the anvil knows the family."
		return
	Game.analyze_gear(idx, true)
	_refresh()


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
