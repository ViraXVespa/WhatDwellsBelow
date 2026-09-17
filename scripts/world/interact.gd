extends Node3D

const InteractFx := preload("res://scripts/world/interact_fx.gd")
const Prompt := preload("res://scripts/world/interact_prompt.gd")

static var _act_s: GDScript

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
var pressed := false


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
	var Catalog: GDScript = load("res://scripts/data/catalog.gd") as GDScript
	stock = Catalog.pick(rng, n)


func refresh() -> void:
	Prompt.refresh(self)


func _title() -> String:
	return Prompt.title(self)


func _act() -> GDScript:
	if _act_s == null:
		_act_s = load("res://scripts/world/interact_act.gd") as GDScript
	return _act_s


func interact(who: Node) -> String:
	return _act().interact(self, who)


func unlock_hidden() -> void:
	_act().unlock_hidden(self)


func hide_as_secret() -> void:
	_act().hide_as_secret(self)


func _shrine() -> String:
	return _act().shrine(self)


func _campfire(who: Node) -> String:
	return _act().campfire(self, who)


func _open_chest() -> String:
	return _act().open_chest(self)


func _open_extract_gate() -> String:
	return _act().open_extract_gate(self)


func mark_spent() -> void:
	_act().mark_spent(self)


func _open_shop() -> String:
	return _act().open_shop(self)


func _ui() -> Node:
	return _act().ui_node(self)


func _toggle_gates() -> void:
	_act().toggle_gates(self)


func set_open(v: bool) -> void:
	_act().set_open(self, v)


func plate_held(on: bool) -> void:
	_act().plate_held(self, on)
