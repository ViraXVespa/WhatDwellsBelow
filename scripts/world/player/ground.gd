extends Object

## Actor grounding and present steps shared by the player tick paths (player_tick.gd, player_act.gd tick_exit):
## ground = set velocity, move_and_slide, pin y to 0, depth sort; follow = camera rig follow.
## settle = ground + facing + follow (the still / gather / loco paths).

const Depth := preload("res://scripts/world/depth.gd")
const PlayerAnim := preload("res://scripts/world/player/player_anim.gd")

static var _rig_id: int = 0
static var _rig_ok: bool = false

static func ground(host: Node, vel: Vector3) -> void:
	host.velocity = vel
	host.move_and_slide()
	host.global_position.y = 0.0
	if host.body:
		Depth.apply(host.body, host.global_position)

## Rig follow; whether the rig has follow() is cached per rig instance.
static func follow(host: Node) -> void:
	var rig: Variant = host.rig
	if rig == null or not is_instance_valid(rig):
		return
	var rid: int = (rig as Object).get_instance_id()
	if rid != _rig_id:
		_rig_id = rid
		_rig_ok = (rig as Object).has_method("follow")
	if _rig_ok:
		rig.follow(host.global_position)

static func settle(host: Node, vel: Vector3, delta: float) -> void:
	ground(host, vel)
	PlayerAnim.apply_facing(host, delta)
	follow(host)
