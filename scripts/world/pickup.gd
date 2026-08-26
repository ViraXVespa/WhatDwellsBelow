extends Node3D

const Depth := preload("res://scripts/world/depth.gd")

var kind := "hp"
var amount := 0
var item: Dictionary = {}
var spr: Sprite3D
var label: Label3D
var life := 18.0


static func drop_item(it: Dictionary, pos: Vector3) -> void:
	var tree := Engine.get_main_loop()
	if tree == null or it.is_empty():
		return
	var host: Node = (tree as SceneTree).current_scene
	if host == null:
		return
	var p := new()
	host.add_child(p)
	p.setup_item(it, pos)


func setup(k: String, pos: Vector3, n := 0) -> void:
	kind = k
	amount = n
	position = pos
	_visual()


func setup_item(it: Dictionary, pos: Vector3) -> void:
	item = it.duplicate(true)
	kind = "item"
	life = 0.0
	position = pos
	_visual()


func _visual() -> void:
	spr = Sprite3D.new()
	spr.centered = true
	spr.shaded = false
	spr.billboard = BaseMaterial3D.BILLBOARD_FIXED_Y
	spr.alpha_cut = SpriteBase3D.ALPHA_CUT_OPAQUE_PREPASS
	spr.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	var path := "res://assets/sprites/props/hp_orb.png"
	if ResourceLoader.exists(path):
		spr.texture = load(path)
		spr.pixel_size = 0.45 / float(maxi(1, spr.texture.get_height()))
	if kind == "gold":
		spr.modulate = Color(1.0, 0.85, 0.25)
	elif kind == "item":
		var r := str(item.get("rarity", "white"))
		if r == "blue":
			spr.modulate = Color(0.45, 0.7, 1.0)
		elif r == "green":
			spr.modulate = Color(0.45, 0.9, 0.5)
		else:
			spr.modulate = Color(0.92, 0.88, 0.75)
		label = Label3D.new()
		label.text = str(item.get("name", "item"))
		label.font_size = 48
		label.pixel_size = 0.012
		label.billboard = BaseMaterial3D.BILLBOARD_FIXED_Y
		label.modulate = Color(0.95, 0.88, 0.7)
		label.outline_modulate = Color(0.05, 0.03, 0.02)
		label.outline_size = 6
		label.position = Vector3(0, 0.7, 0)
		add_child(label)
	spr.position.y = 0.35
	add_child(spr)
	Depth.apply(spr, position)


func _process(delta: float) -> void:
	if life > 0.0:
		life -= delta
		if life <= 0.0:
			queue_free()
			return
	if spr:
		spr.position.y = 0.35 + sin(Time.get_ticks_msec() * 0.006) * 0.06
		Depth.apply(spr, global_position)
	var tree := get_tree()
	if tree == null:
		return
	var p := tree.get_first_node_in_group("player")
	if p is Node3D:
		var d := Vector2((p as Node3D).global_position.x - global_position.x, (p as Node3D).global_position.z - global_position.z).length()
		if d < 0.55:
			_take(p)


func _take(p: Node) -> void:
	if kind == "hp" and p.has_method("heal"):
		p.heal(App.bal.orb_heal)
		App.toast("+HP")
	elif kind == "gold":
		App.gain_gold(maxi(1, amount))
		App.toast("+%dg" % maxi(1, amount))
	elif kind == "item":
		if not App.prog.add_item(item):
			return
		App.toast(str(item.get("name", "Item")))
	App.sfx("pickup")
	queue_free()
