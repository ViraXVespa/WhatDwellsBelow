extends Area3D

const V3 := preload("res://archives/art_experiment/scripts/view3d/v3.gd")

const SAFE := 2.0
const FLAME := 1.0
const DMG := 40.0

var kind := "fire"
var plate_id := 0
var latched := false
var on := false
var t := 0.0
var burned := false
var amount := 10.0
var life := 12.0
var pulled := false
var spr: Sprite3D


func _ready() -> void:
	set_process(false)


func setup_fire() -> void:
	kind = "fire"
	collision_layer = 0
	collision_mask = 2
	monitoring = true
	var cs := CollisionShape3D.new()
	var sh := BoxShape3D.new()
	sh.size = Vector3(0.88, 0.5, 0.88)
	cs.shape = sh
	cs.position.y = 0.25
	add_child(cs)
	spr = V3.sprite(Art.solid(Vector2i(48, 48), Color(0.35, 0.22, 0.12)), 0.45, true)
	add_child(spr)
	t = randf() * SAFE
	set_process(true)


func setup_plate(id: int) -> void:
	kind = "plate"
	plate_id = id
	collision_layer = 0
	collision_mask = 2
	monitoring = true
	var cs := CollisionShape3D.new()
	var sh := BoxShape3D.new()
	sh.size = Vector3(0.75, 0.12, 0.75)
	cs.shape = sh
	cs.position.y = 0.04
	add_child(cs)
	spr = V3.sprite(Art.solid(Vector2i(44, 44), Color(0.55, 0.48, 0.32)), 0.18, false)
	add_child(spr)
	body_entered.connect(_on_plate)


func setup_pickup(p_kind: String, p_amount: float, pos: Vector3) -> void:
	kind = "pickup"
	amount = p_amount
	global_position = pos
	collision_layer = 0
	collision_mask = 2
	monitoring = true
	var cs := CollisionShape3D.new()
	var sh := SphereShape3D.new()
	sh.radius = 0.28
	cs.shape = sh
	add_child(cs)
	var path := V3.a("props", "%s_orb.png" % p_kind)
	var tex := Art.load_tex(path)
	if tex == null:
		tex = Art.solid(Vector2i(16, 16), Color(0.85, 0.2, 0.2))
	spr = V3.sprite(tex, 0.32, true)
	add_child(spr)
	body_entered.connect(_on_pickup)
	set_process(true)


func _process(delta: float) -> void:
	if kind == "fire":
		_tick_fire(delta)
	elif kind == "pickup":
		_tick_pickup(delta)


func _tick_fire(delta: float) -> void:
	t += delta
	var cycle := SAFE + FLAME
	var u := fmod(t, cycle)
	on = u >= SAFE
	if not on:
		burned = false
	if spr:
		spr.modulate = Color(1.0, 0.45, 0.12) if on else Color(0.45, 0.28, 0.18)
	if not on or burned:
		return
	for a in get_overlapping_bodies():
		if a is Node and (a as Node).is_in_group("player") and a.has_method("take_damage"):
			if float(a.get("iframe")) > 0.0:
				continue
			a.take_damage(DMG, V3.xz(global_position))
			burned = true
			break


func _tick_pickup(delta: float) -> void:
	life -= delta
	if life <= 0.0:
		queue_free()
		return
	var player := get_tree().get_first_node_in_group("player")
	if player == null or not (player is Node3D):
		return
	var p: Node3D = player
	var to := Vector3(p.global_position.x - global_position.x, 0.0, p.global_position.z - global_position.z)
	if to.length() < V3.u(90.0):
		pulled = true
	if pulled:
		global_position += to.normalized() * V3.u(220.0) * delta


func _on_plate(body: Node) -> void:
	if latched:
		return
	if not body.is_in_group("player"):
		return
	latched = true
	if spr:
		spr.modulate = Color(0.85, 0.72, 0.35)
	for g in get_tree().get_nodes_in_group("gates"):
		if g.has_method("open_gate") and int(g.get("gate_id")) == plate_id:
			g.open_gate()


func _on_pickup(body: Node) -> void:
	if not body.is_in_group("player"):
		return
	Game.heal_player(amount)
	Sfx.play("pickup")
	queue_free()
