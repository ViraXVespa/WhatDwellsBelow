extends Node3D

const Catalog := preload("res://scripts/data/catalog.gd")
const InteractFx := preload("res://scripts/world/interact_fx.gd")
const Prompt := preload("res://scripts/world/interact_prompt.gd")
const Act := preload("res://scripts/world/interact_act.gd")

var kind := "crystal"
var locked := false
var pending := false
var prompt := ""
var spr: Sprite3D
var mesh: MeshInstance3D
var label: Label3D
var body: StaticBody3D
var pair := "puzzle"
var used := false
var hidden := false
var role := "gather"
var stock: Array = []
var bought := 0
var open := false
var latched := false


func setup(k: String, pos: Vector3, lock := false) -> void:
	kind = k
	locked = lock
	position = pos
	if kind != "gate":
		add_to_group("interact")
	else:
		add_to_group("gates")
	if kind == "plate":
		add_to_group("plates")
	InteractFx.build(self)
	InteractFx.add_label(self)
	refresh()


func setup_extract_gate(pos: Vector3) -> void:
	role = "gate"
	setup("extract_gate", pos)


func setup_clerk(_role_id: String, pos: Vector3) -> void:
	setup_extract_gate(pos)


func setup_shop(pos: Vector3, rng: RandomNumberGenerator) -> void:
	setup("shop", pos)
	var lo := int(App.bal.shop_stock_min)
	var hi := int(App.bal.shop_stock_max)
	if hi < lo:
		hi = lo
	var n := rng.randi_range(lo, hi)
	stock = Catalog.pick(rng, n)


func refresh() -> void:
	Prompt.refresh(self)


func _title() -> String:
	return Prompt.title(self)


func interact(who: Node) -> String:
	return Act.interact(self, who)


func unlock_hidden() -> void:
	Act.unlock_hidden(self)


func hide_as_secret() -> void:
	Act.hide_as_secret(self)


func _shrine() -> String:
	return Act.shrine(self)


func _campfire(who: Node) -> String:
	return Act.campfire(self, who)


func _open_chest() -> String:
	return Act.open_chest(self)


func _open_extract_gate() -> String:
	return Act.open_extract_gate(self)


func mark_spent() -> void:
	Act.mark_spent(self)


func _open_shop() -> String:
	return Act.open_shop(self)


func _ui() -> Node:
	return Act.ui_node(self)


func _toggle_gates() -> void:
	Act.toggle_gates(self)


func set_open(v: bool) -> void:
	Act.set_open(self, v)


func plate_held(on: bool) -> void:
	Act.plate_held(self, on)
