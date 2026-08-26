extends Node3D

const Depth := preload("res://scripts/world/depth.gd")

var kind := "mine"
var hits := 4
var interval := 2.4
var spr: Sprite3D
var label: Label3D
var busy := false


func setup(k: String, pos: Vector3) -> void:
	kind = k
	position = pos
	add_to_group("interact")
	add_to_group("gather")
	if kind == "wood":
		hits = clampi(int(App.bal.wood_hits), 6, 10)
		interval = App.bal.wood_time
	else:
		kind = "mine"
		hits = clampi(int(App.bal.mine_hits), 3, 5)
		interval = App.bal.mine_time
	_visual()
	_label()
	refresh()


func refresh() -> void:
	if label:
		label.text = "ORE" if kind == "mine" else "WOOD"
		label.modulate = Color(0.75, 0.9, 1.0) if kind == "mine" else Color(0.7, 0.9, 0.55)


func interact(who: Node) -> String:
	if hits <= 0:
		return ""
	if kind == "mine" and App.prog.tool_type != "pickaxe":
		App.toast("Need a pickaxe this run.")
		return "Tool locked to hatchet."
	if kind == "wood" and App.prog.tool_type != "hatchet":
		App.toast("Need a hatchet this run.")
		return "Tool locked to pickaxe."
	if who and who.has_method("start_gather"):
		who.start_gather(self)
		return "Gathering…  (move to stop)"
	return "A: Gather"


func strike() -> Dictionary:
	if hits <= 0:
		return {"ok": false, "done": true}
	hits -= 1
	var chance := App.bal.wood_chance if kind == "wood" else App.bal.mine_chance
	if kind == "wood":
		chance += float(App.prog.skill_lv("wood")) * App.bal.skill_gather + float(App.hatchet_q) * App.bal.tool_gather + float(App.prog.set_stats().gather)
		App.wood_hits_landed += 1
		if App.tel:
			App.tel.wood_hits += 1
	else:
		chance += float(App.prog.skill_lv("mine")) * App.bal.skill_gather + float(App.pickaxe_q) * App.bal.tool_gather + float(App.prog.set_stats().gather)
		App.mine_hits_landed += 1
		if App.tel:
			App.tel.mine_hits += 1
	var ok := randf() < clampf(chance, 0.05, 0.95)
	var gold := 0
	var ore := 0
	var wood := 0
	if ok:
		if kind == "wood":
			wood = 1
			App.wood += wood
			App.wood_success += 1
			App.prog.add_run_xp("wood", 6.0)
			if App.tel:
				App.tel.wood_ok += 1
			if randf() < 0.18:
				App.prog.root += 1
		else:
			ore = 1
			App.ore += ore
			App.mine_success += 1
			App.prog.add_run_xp("mine", 6.0)
			if App.tel:
				App.tel.mine_ok += 1
		if randf() < 0.25:
			gold = 1 + randi() % 3
			App.gain_gold(gold)
	App.sfx("wood" if kind == "wood" else "mine")
	var msg := "clink…"
	if ok:
		if kind == "wood":
			msg = "+1 wood"
		else:
			msg = "+1 ore"
		if gold > 0:
			msg += "  +%dg" % gold
	App.toast(msg)
	_flash()
	var done := hits <= 0
	if done:
		_break()
	else:
		refresh()
		if label:
			label.text = ("%s  %d" % [label.text, hits])
	return {"ok": ok, "done": done, "ore": ore, "wood": wood, "gold": gold}


func _flash() -> void:
	if spr == null:
		return
	spr.modulate = Color(1.4, 1.4, 1.4)
	var tw := create_tween()
	tw.tween_property(spr, "modulate", Color.WHITE, 0.12)


func _break() -> void:
	remove_from_group("interact")
	remove_from_group("gather")
	var tw := create_tween()
	if spr:
		tw.tween_property(spr, "modulate:a", 0.0, 0.18)
	tw.finished.connect(queue_free)


func _visual() -> void:
	spr = Sprite3D.new()
	spr.centered = true
	spr.shaded = false
	spr.billboard = BaseMaterial3D.BILLBOARD_FIXED_Y
	spr.alpha_cut = SpriteBase3D.ALPHA_CUT_OPAQUE_PREPASS
	spr.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	var path := "res://assets/sprites/props/tree.png" if kind == "wood" else "res://assets/sprites/props/ore.png"
	if ResourceLoader.exists(path):
		spr.texture = load(path)
		spr.pixel_size = (1.55 if kind == "wood" else 1.05) / float(maxi(1, spr.texture.get_height()))
	spr.position.y = 0.72 if kind == "wood" else 0.42
	add_child(spr)
	Depth.apply(spr, position)


func _label() -> void:
	label = Label3D.new()
	label.position = Vector3(0.0, 1.35 if kind == "wood" else 1.05, 0.0)
	label.font_size = 34
	label.outline_size = 8
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.no_depth_test = true
	label.pixel_size = 0.011
	add_child(label)
