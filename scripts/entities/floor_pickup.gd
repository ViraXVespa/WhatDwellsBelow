class_name FloorPickup
extends Area2D

var kind := "hp"
var amount := 10.0
var life := 12.0
var pulled := false


func setup(p_kind: String, p_amount: float) -> void:
	kind = p_kind
	amount = p_amount
	collision_layer = 0
	collision_mask = 2
	monitoring = true
	monitorable = true
	var cs := CollisionShape2D.new()
	var sh := CircleShape2D.new()
	sh.radius = 18
	cs.shape = sh
	add_child(cs)
	var path := "res://assets/sprites/props/%s_orb.png" % kind
	var tex := Art.load_tex(path)
	if tex == null:
		var col := Color(0.85, 0.2, 0.2) if kind == "hp" else Color(0.25, 0.45, 0.95)
		tex = Art.solid(Vector2i(16, 16), col)
	add_child(Art.make_sprite(tex, 0.38))
	body_entered.connect(_on_body)


func _physics_process(delta: float) -> void:
	life -= delta
	if life <= 0.0:
		queue_free()
		return
	var player := get_tree().get_first_node_in_group("player") as Node2D
	if player == null:
		return
	var to: Vector2 = player.global_position - global_position
	if to.length() < 90.0:
		pulled = true
	if pulled:
		global_position += to.normalized() * 220.0 * delta


func _on_body(body: Node) -> void:
	if not (body is Player):
		return
	if kind == "hp":
		Game.heal_player(amount)
	elif kind == "mana":
		Game.restore_mana(amount)
	Sfx.play("pickup")
	queue_free()
