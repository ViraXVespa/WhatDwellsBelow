class_name AnvilUI
extends CanvasLayer

var panel: Panel
var list: ItemList
var hint: Label
var forging := false


func _ready() -> void:
	add_to_group("anvil_ui")
	layer = 36
	process_mode = Node.PROCESS_MODE_ALWAYS
	panel = Panel.new()
	panel.visible = false
	panel.position = Vector2(480, 80)
	panel.size = Vector2(960, 820)
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
	t.text = "Anvil"
	t.add_theme_font_size_override("font_size", 28)
	v.add_child(t)
	hint = Label.new()
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	hint.add_theme_font_size_override("font_size", 16)
	v.add_child(hint)
	list = ItemList.new()
	list.custom_minimum_size = Vector2(0, 360)
	v.add_child(list)
	v.add_child(_btn("Forge selected into a free hold", _forge))
	v.add_child(_btn("Destroy a hold (frees a slot)", _destroy_prompt))
	v.add_child(_btn("Close", close))
	PadUi.wire(panel)


func _unhandled_input(event: InputEvent) -> void:
	if not panel.visible:
		return
	if event.is_action_pressed("ui_cancel"):
		close()
		get_viewport().set_input_as_handled()


func open() -> void:
	Sfx.play("ui")
	panel.visible = true
	get_tree().paused = true
	_refresh()
	PadUi.focus_first(panel)


func close() -> void:
	panel.visible = false
	get_tree().paused = false


func _refresh() -> void:
	list.clear()
	var sm := Game.skill_level("smithing")
	hint.text = "Gold %d   Ore %d   Smithing L%d\nRecipes are unlimited. 3 forged holds per type is what you can actually take on a run.\nFirst forge costs gold+ore. Re-forge after destroy is cheaper (no new root)." % [
		Game.save.gold, Game.save.banked_ore, sm
	]
	list.add_item("— RECIPES —")
	list.set_item_disabled(list.item_count - 1, true)
	var i := 0
	for it in Game.save.recipes:
		var cost := LootGen.forge_cost(it, not it.forged_once, sm)
		var key := it.hold_key()
		var n: int = Game.save.holds_of(key).size()
		list.add_item("%s  %s   forge %dg + %d ore   holds %d/3" % [it.full_name(), it.stat_line(), cost.gold, cost.ore, n])
		list.set_item_metadata(list.item_count - 1, {"kind": "recipe", "i": i})
		i += 1
	list.add_item("— HOLDS —")
	list.set_item_disabled(list.item_count - 1, true)
	for k in SaveData.HOLD_KEYS:
		var j := 0
		for it in Game.save.holds_of(k):
			list.add_item("[%s %d]  %s  %s" % [k, j + 1, it.full_name(), it.stat_line()])
			list.set_item_metadata(list.item_count - 1, {"kind": "hold", "key": k, "i": j})
			j += 1
	if list.item_count > 1:
		list.select(1)


func _forge() -> void:
	if forging:
		return
	if list.get_selected_items().is_empty():
		return
	var meta = list.get_item_metadata(list.get_selected_items()[0])
	if not (meta is Dictionary) or meta.get("kind") != "recipe":
		hint.text = "Pick a recipe, not a hold."
		return
	var it: ItemData = Game.save.recipes[int(meta.i)]
	var key := it.hold_key()
	if Game.save.holds_of(key).size() >= 3:
		hint.text = "That type is full (3/3). Destroy a hold first."
		return
	var first := not it.forged_once
	var cost := LootGen.forge_cost(it, first, Game.skill_level("smithing"))
	if Game.save.gold < int(cost.gold) or Game.save.banked_ore < int(cost.ore):
		hint.text = "Need %dg and %d ore." % [cost.gold, cost.ore]
		return
	forging = true
	hint.text = "Hammering…"
	await get_tree().create_timer(Skills.smith_bar_time(Game.skill_level("smithing"))).timeout
	forging = false
	if not panel.visible:
		return
	Game.save.gold -= int(cost.gold)
	Game.save.banked_ore -= int(cost.ore)
	it.forged_once = true
	Game.save.add_hold(it)
	Game.grant_xp("smithing", 18.0 if first else 10.0, true)
	Game.save.write()
	Sfx.play("ui")
	_refresh()


func _destroy_prompt() -> void:
	if list.get_selected_items().is_empty():
		return
	var meta = list.get_item_metadata(list.get_selected_items()[0])
	if not (meta is Dictionary) or meta.get("kind") != "hold":
		hint.text = "Select a hold line to destroy it. Recipe stays."
		return
	Game.save.destroy_hold(str(meta.key), int(meta.i))
	Game.save.write()
	_refresh()


func _btn(text: String, cb: Callable) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(0, 48)
	b.pressed.connect(cb)
	return b
