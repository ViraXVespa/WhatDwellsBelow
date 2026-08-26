extends CanvasLayer

## Dungeon-themed clerk / shop panels. Gamepad-first.

const Catalog := preload("res://scripts/data/catalog.gd")

var open := false
var mode := ""
var shop_spot: Node = null
var box: VBoxContainer
var status: Label
var focus_btn: Button


func _ready() -> void:
	layer = 40
	visible = false
	process_mode = Node.PROCESS_MODE_ALWAYS
	var dim := ColorRect.new()
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.color = Color(0.04, 0.03, 0.02, 0.72)
	add_child(dim)
	var panel := ColorRect.new()
	panel.color = Color(0.14, 0.11, 0.09, 0.96)
	panel.position = Vector2(480, 160)
	panel.size = Vector2(960, 720)
	add_child(panel)
	var edge := ColorRect.new()
	edge.color = Color(0.55, 0.42, 0.22, 1)
	edge.position = Vector2(480, 160)
	edge.size = Vector2(960, 8)
	add_child(edge)
	box = VBoxContainer.new()
	box.position = Vector2(520, 190)
	box.size = Vector2(880, 660)
	box.add_theme_constant_override("separation", 10)
	add_child(box)


func open_clerk(role: String) -> void:
	mode = "clerk"
	shop_spot = null
	_rebuild_clerk(role)
	_show()


func open_shop(spot: Node) -> void:
	mode = "shop"
	shop_spot = spot
	_rebuild_shop()
	_show()


func close_ui() -> void:
	open = false
	visible = false
	App.ui_open = false


func _show() -> void:
	open = true
	visible = true
	App.ui_open = true
	if focus_btn:
		focus_btn.grab_focus()


func _rebuild_clerk(role: String) -> void:
	_clear()
	var title := _lab(_clerk_title(role), 32, Color(0.95, 0.82, 0.5))
	box.add_child(title)
	box.add_child(_lab("Send gathered goods to the surface. Gear waits for later.", 20, Color(0.82, 0.76, 0.66)))
	box.add_child(_lab("Carried  ·  %dg   %d ore   %d wood" % [App.gold, App.ore, App.wood], 22, Color(0.9, 0.88, 0.78)))
	box.add_child(_lab("Banked   ·  %dg   %d ore   %d wood" % [App.bank_gold, App.bank_ore, App.bank_wood], 22, Color(0.7, 0.85, 0.7)))
	status = _lab("", 20, Color(0.95, 0.8, 0.45))
	box.add_child(status)
	if role == "gather" or role == "patty":
		focus_btn = _btn("Extract ore & wood", func(): _extract_gather())
		box.add_child(focus_btn)
	if role == "misc" or role == "patty":
		var b := _btn("Extract gold", func(): _extract_gold())
		box.add_child(b)
		if focus_btn == null:
			focus_btn = b
	if role == "patty":
		box.add_child(_btn("Extract everything", func(): _extract_all()))
	box.add_child(_btn("Leave  (B)", func(): close_ui()))


func _clerk_title(role: String) -> String:
	if role == "patty":
		return "Packmule Patty"
	if role == "misc":
		return "Misc Clerk"
	return "Gather Clerk"


func _extract_gather() -> void:
	App.bank_ore += App.ore
	App.bank_wood += App.wood
	var msg := "Sent %d ore, %d wood." % [App.ore, App.wood]
	App.ore = 0
	App.wood = 0
	App.extracted = true
	App.toast(msg)
	if status:
		status.text = msg
	App.sfx("ui")


func _extract_gold() -> void:
	App.bank_gold += App.gold
	var msg := "Sent %dg." % App.gold
	App.gold = 0
	App.extracted = true
	App.toast(msg)
	if status:
		status.text = msg
	App.sfx("ui")


func _extract_all() -> void:
	_extract_gather()
	_extract_gold()


func _rebuild_shop() -> void:
	_clear()
	box.add_child(_lab("Ghost Shop", 32, Color(0.75, 0.9, 1.0)))
	box.add_child(_lab("Pale goods. Two artifacts a visit. Snacks  %dg." % int(App.bal.snack_cost), 20, Color(0.82, 0.76, 0.66)))
	box.add_child(_lab("Gold %d   Artifacts %d   Bought %d/2" % [App.gold, App.run_artifacts.size(), int(shop_spot.get("bought") if shop_spot else 0)], 22, Color(0.9, 0.88, 0.78)))
	status = _lab("", 20, Color(0.95, 0.8, 0.45))
	box.add_child(status)
	focus_btn = _btn("Snack  (%dg, +HP)" % int(App.bal.snack_cost), func(): _buy_snack())
	box.add_child(focus_btn)
	if shop_spot:
		var stock: Array = shop_spot.stock
		for a in stock:
			var id := str(a.id)
			var nm := str(a.name)
			box.add_child(_btn("Buy %s  (%dg)" % [nm, int(App.bal.art_cost)], func(): _buy_art(id, nm)))
		if App.run_artifacts.size() > 0:
			box.add_child(_btn("Pawn an artifact  (%dg)" % int(App.bal.pawn_gold), func(): _pawn()))
	box.add_child(_btn("Leave  (B)", func(): close_ui()))


func _buy_snack() -> void:
	if App.gold < int(App.bal.snack_cost):
		_fail("Not enough gold.")
		return
	App.gold -= int(App.bal.snack_cost)
	App.shop_buys += 1
	App.shop_spent += int(App.bal.snack_cost)
	var tree := get_tree()
	if tree:
		var p := tree.get_first_node_in_group("player")
		if p and p.has_method("heal"):
			p.heal(App.bal.snack_heal)
	_fail("The snack is strangely warm. +HP")
	App.toast("Snack.")


func _buy_art(id: String, nm: String) -> void:
	if shop_spot == null:
		return
	if int(shop_spot.bought) >= 2:
		_fail("Two artifacts a visit.")
		return
	if App.gold < int(App.bal.art_cost):
		_fail("Not enough gold.")
		return
	App.gold -= int(App.bal.art_cost)
	shop_spot.bought = int(shop_spot.bought) + 1
	App.run_artifacts.append(id)
	App.shop_buys += 1
	App.shop_spent += int(App.bal.art_cost)
	_fail("Purchased " + nm)
	App.toast("Artifact: " + nm)
	_rebuild_shop()
	_show()


func _pawn() -> void:
	if App.run_artifacts.is_empty():
		_fail("Nothing to pawn.")
		return
	App.run_artifacts.remove_at(App.run_artifacts.size() - 1)
	App.gold += int(App.bal.pawn_gold)
	_fail("The ghost takes it for a pittance.")
	App.toast("+%dg" % int(App.bal.pawn_gold))
	_rebuild_shop()
	_show()


func _fail(msg: String) -> void:
	if status:
		status.text = msg
	App.sfx("ui")


func _clear() -> void:
	for c in box.get_children():
		c.queue_free()
	focus_btn = null
	status = null


func _lab(t: String, size: int, col: Color) -> Label:
	var l := Label.new()
	l.text = t
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", col)
	l.add_theme_color_override("font_outline_color", Color(0.05, 0.03, 0.02))
	l.add_theme_constant_override("outline_size", 6)
	return l


func _btn(t: String, cb: Callable) -> Button:
	var b := Button.new()
	b.text = t
	b.custom_minimum_size = Vector2(0, 48)
	b.add_theme_font_size_override("font_size", 22)
	b.add_theme_color_override("font_color", Color(0.92, 0.84, 0.62))
	b.add_theme_color_override("font_hover_color", Color(1, 0.95, 0.75))
	b.add_theme_color_override("font_focus_color", Color(1, 0.92, 0.55))
	b.add_theme_stylebox_override("normal", _sb(Color(0.22, 0.16, 0.12), Color(0.5, 0.38, 0.2)))
	b.add_theme_stylebox_override("hover", _sb(Color(0.3, 0.22, 0.14), Color(0.75, 0.58, 0.28)))
	b.add_theme_stylebox_override("pressed", _sb(Color(0.16, 0.12, 0.08), Color(0.9, 0.7, 0.3)))
	b.add_theme_stylebox_override("focus", _sb(Color(0.28, 0.2, 0.12), Color(0.95, 0.78, 0.35)))
	b.pressed.connect(cb)
	return b


func _sb(bg: Color, border: Color) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = bg
	s.border_color = border
	s.set_border_width_all(2)
	s.content_margin_left = 14
	s.content_margin_right = 14
	s.content_margin_top = 8
	s.content_margin_bottom = 8
	return s


func _unhandled_input(event: InputEvent) -> void:
	if not open:
		return
	if event.is_action_pressed("ui_cancel") or event.is_action_pressed("pause"):
		close_ui()
		get_viewport().set_input_as_handled()
