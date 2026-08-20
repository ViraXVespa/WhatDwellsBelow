class_name FireTrap
extends Area2D

const SAFE := 2.0
const FLAME := 1.0
const DMG := 40.0

var on := false
var t := 0.0
var spr: Sprite2D
var burned := false


func _ready() -> void:
	collision_layer = 0
	collision_mask = 2
	monitoring = true
	var cs := CollisionShape2D.new()
	var sh := RectangleShape2D.new()
	sh.size = Vector2(56, 56)
	cs.shape = sh
	add_child(cs)
	spr = Art.make_sprite(Art.solid(Vector2i(48, 48), Color(0.35, 0.22, 0.12)), 0.7)
	add_child(spr)
	t = randf() * SAFE
	set_process(true)


func _process(delta: float) -> void:
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
		if a is Player:
			var p := a as Player
			if p.iframe > 0.0:
				continue
			p.take_damage(DMG)
			burned = true
			break
