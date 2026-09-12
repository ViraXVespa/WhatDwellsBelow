extends Object

## Enemy physics tick presentation.

const Depth := preload("res://scripts/world/depth.gd")
const Facing := preload("res://scripts/world/facing.gd")
const EnemyAI := preload("res://scripts/combat/enemy_ai.gd")
const Hit := preload("res://scripts/combat/enemy_hit.gd")


static func physics(host: CharacterBody3D, delta: float) -> void:
	if host.dead:
		return
	if host.post == Vector3.ZERO:
		mark_post(host)
	host.bob_t += delta
	host.reaggro_t = maxf(0.0, host.reaggro_t - delta)
	if host.stagger > 0.0:
		host.stagger -= delta
		host.velocity = Vector3.ZERO
		host.move_and_slide()
		Present.present(host, delta)
		return
	if host.knock_t > 0.0:
		host.knock_t -= delta
		host.velocity = host.knock
		host.move_and_slide()
		Present.present(host, delta)
		return
	EnemyAI.tick(host, delta)
	host.move_and_slide()
	host.global_position.y = 0.0
	EnemyAI.stuck(host, delta)
	Present.present(host, delta)

static func present(host: CharacterBody3D, delta: float) -> void:
	if host.spr == null:
		return
	var lift := 0.0
	if host.move_kind == "fly":
		lift = App.bal.fly_height + sin(host.bob_t * 5.0) * 0.08
	elif host.move_kind == "hop" and host.hop_t > 0.18:
		lift = App.bal.hop_height * (host.hop_t / 0.42)
	host.spr.position.y = host.size_u * 0.48 + lift
	var fk := Facing.from_aim(host.aim)
	host.spr.flip_h = fk == "left" or fk == "up_left" or fk == "down_left"
	Depth.apply(host.spr, host.global_position)
	if host.flash > 0.0:
		host.flash -= delta
		host.spr.modulate = Color(1.7, 1.7, 1.7)
	elif host.state == host.ST_WIND:
		host.spr.modulate = host.base_mod * Color(1.15, 0.85, 0.55)
	else:
		host.spr.modulate = host.base_mod
	if host.bang.visible and host.state != host.ST_FLEE:
		host.bang.visible = false