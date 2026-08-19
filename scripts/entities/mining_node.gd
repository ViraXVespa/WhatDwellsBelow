class_name MiningNode
extends Interactable

var remaining := 4
var rng := RandomNumberGenerator.new()


func _ready() -> void:
	monitoring = true
	monitorable = true
	collision_layer = 16
	collision_mask = 0
	add_to_group("interactable")
	rng.randomize()
	prompt = "Mine ore"
	remaining = rng.randi_range(3, 5)

	var area_cs := CollisionShape2D.new()
	var area_sh := CircleShape2D.new()
	area_sh.radius = 52
	area_cs.shape = area_sh
	add_child(area_cs)

	var body := StaticBody2D.new()
	body.collision_layer = 1
	body.collision_mask = 0
	var body_cs := CollisionShape2D.new()
	var body_sh := RectangleShape2D.new()
	body_sh.size = Vector2(52, 52)
	body_cs.shape = body_sh
	body.add_child(body_cs)
	add_child(body)

	var spr := Sprite2D.new()
	spr.texture = Art.ore_vein(Vector2i(56, 56))
	add_child(spr)


func get_prompt() -> String:
	if remaining <= 0:
		return "Depleted vein"
	return "Mine ore (%d)" % remaining


func interact(player: Node) -> void:
	if remaining <= 0:
		return
	if player is Player:
		(player as Player).start_channel(self, channel_time(player))


func can_channel() -> bool:
	return remaining > 0


func channel_time(_player: Node) -> float:
	var mult := 1.0
	if Game.run and Game.run.tool:
		mult = Game.run.tool.gather_mult
	return maxf(0.85, 1.85 / maxf(0.5, mult))


func complete_channel(player: Node) -> void:
	if remaining <= 0:
		return
	var amt := rng.randi_range(1, 2)
	if not Game.add_to_bag(ItemData.make_ore(amt)):
		if player is Player:
			(player as Player).interrupt_channel()
		return
	remaining -= 1
	if Game.run:
		Game.run.mining_xp_run += 12.0 * amt
	if remaining <= 0:
		modulate = Color(0.45, 0.45, 0.48)
		prompt = "Depleted vein"
