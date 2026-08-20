class_name ShopUI
extends CanvasLayer

var panel: Panel
var hint: Label
var list: ItemList
var stock: Array = []
var bought := 0
var rng := RandomNumberGenerator.new()


func _ready() -> void:
	add_to_group("shop_ui")
	layer = 37
	process_mode = Node.PROCESS_MODE_ALWAYS
	rng.randomize()
	panel = Panel.new()
	panel.visible = false
	panel.position = Vector2(500, 120)
	panel.size = Vector2(920, 720)
	add_child(panel)
	var v := VBoxContainer.new()
	v.set_anchors_preset(Control.PRESET_FULL_RECT)
	v.offset_left = 24
	v.offset_top = 20
	v.offset_right = -24
	v.offset_bottom = -20
	v.add_theme_constant_override("separation", 10)
	panel.add_child(v)
	var t := Label.new()
	t.text = "Someone's stall. Or what's left of someone."
	t.add_theme_font_size_override("font_size", 24)
	v.add_child(t)
	hint = Label.new()
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	hint.add_theme_font_size_override("font_size", 16)
	v.add_child(hint)
	list = ItemList.new()
	list.custom_minimum_size = Vector2(0, 280)
	v.add_child(list)
	v.add_child(_btn("Buy selected", _buy))
	v.add_child(_btn("Pawn selected bag gear/potion (peanuts)", _pawn))
	v.add_child(_btn("Close", close))
	PadUi.wire(panel)


func _unhandled_input(event: InputEvent) -> void:
	if not panel.visible:
		return
	if event.is_action_pressed("ui_cancel") or event.is_action_pressed("pause"):
		close()
		get_viewport().set_input_as_handled()


func open() -> void:
	Sfx.play("ui")
	panel.visible = true
	get_tree().paused = true
	if stock.is_empty():
		_roll_stock()
	_refresh()
	PadUi.focus_first(panel)


func close() -> void:
	panel.visible = false
	get_tree().paused = false


func _roll_stock() -> void:
	stock.clear()
	var n := rng.randi_range(2, 4)
	var used: Array = []
	if Game.run:
		used = Game.run.artifact_ids.duplicate()
	for _i in n:
		var art_s = load("res://scripts/data/artifacts.gd")
		var art: Dictionary = art_s.pick(rng, used)
		used.append(str(art.id))
		stock.append({"kind": "art", "id": str(art.id), "name": str(art.name), "desc": str(art.desc), "price": int(art.price), "sold": false})
	var snacks: Array = [
		{"name": "Emergency ration", "desc": "Town sells these for 5g. Down here? 25."},
		{"name": "Dusty biscuit", "desc": "Keeps. That's the nicest thing I can say."},
		{"name": "Hole jerky", "desc": "Don't ask which hole."},
	]
	snacks.shuffle()
	for i in rng.randi_range(2, 3):
		var sn: Dictionary = snacks[i]
		stock.append({"kind": "food", "name": str(sn.name), "desc": str(sn.desc), "price": 25, "sold": false})


func _refresh() -> void:
	list.clear()
	var gold := Game.run.gold if Game.run else 0
	hint.text = "Gold on you: %d\nI don't mail gold. Clerks do that. Two relics max from me, then I just look smug.\nArtifacts bought: %d/2" % [gold, bought]
	for i in stock.size():
		var row: Dictionary = stock[i]
		var tag := "SOLD" if row.get("sold") else "%dg" % int(row.price)
		if row.get("kind") == "art" and bought >= 2 and not row.get("sold"):
			tag = "LOCKED"
		list.add_item("%s  [%s]  %s" % [str(row.name), tag, str(row.get("desc", ""))])
		list.set_item_metadata(list.item_count - 1, {"kind": "stock", "i": i})
	list.add_item("— pawn from bag (unequip first) —")
	list.set_item_disabled(list.item_count - 1, true)
	if Game.run:
		for row in Game.run.mailable_gear():
			var it: ItemData = row.item
			list.add_item("Pawn %s  (a few coins)" % it.full_name())
			list.set_item_metadata(list.item_count - 1, {"kind": "pawn", "i": int(row.index)})
	if list.item_count > 0:
		list.select(0)


func _buy() -> void:
	if Game.run == null or list.get_selected_items().is_empty():
		return
	var meta = list.get_item_metadata(list.get_selected_items()[0])
	if not (meta is Dictionary) or meta.get("kind") != "stock":
		hint.text = "That's a pawn line. Use the pawn button."
		return
	var i: int = int(meta.i)
	var row: Dictionary = stock[i]
	if row.get("sold"):
		return
	if row.get("kind") == "art" and bought >= 2:
		hint.text = "Two's the house limit. Snacks still exist. Gold still doesn't go up."
		return
	if row.get("kind") == "art" and Game.run.artifact_ids.has(str(row.id)):
		hint.text = "You already carry that whisper. I don't double-charge ghosts."
		return
	var price := int(row.price)
	if Game.run.gold < price:
		hint.text = "Cute. Come back with coins that aren't imaginary."
		return
	if row.get("kind") == "art":
		if not Game.give_artifact(str(row.id)):
			hint.text = "That one's already living in your dream."
			return
		Game.run.gold -= price
		Game.gold_changed.emit()
		bought += 1
		row.sold = true
		stock[i] = row
	else:
		if Game.run.food_count() >= 20:
			hint.text = "Twenty rations is the lid. Eat some or I keep the jerky."
			return
		Game.run.gold -= price
		Game.gold_changed.emit()
		if not Game.add_to_bag(ItemData.make_food(1)):
			var p := get_tree().get_first_node_in_group("player")
			var pos := p.global_position if p is Node2D else Vector2.ZERO
			Game.give_or_drop(ItemData.make_food(1), pos)
	_refresh()


func _pawn() -> void:
	if Game.run == null or list.get_selected_items().is_empty():
		return
	var meta = list.get_item_metadata(list.get_selected_items()[0])
	if not (meta is Dictionary) or meta.get("kind") != "pawn":
		hint.text = "Unequip it into the bag first, then pick the pawn line. I don't lift off a living belt."
		return
	var g := Game.pawn_bag_item(int(meta.i))
	if g <= 0:
		hint.text = "Nothing in the bag I'd insult with a price."
		return
	hint.text = "I'll take it off your hands. +%dg. Don't spend it all on ghosts." % g
	_refresh()


func _btn(text: String, cb: Callable) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(0, 48)
	b.pressed.connect(cb)
	return b
