extends RefCounted

const T := preload("res://scripts/data/tunables.gd")
const Facing := preload("res://scripts/world/facing.gd")
const SpriteFilt := preload("res://scripts/world/sprite_filter.gd")
const Load := preload("res://scripts/world/player_anim_load.gd")
const Loco := preload("res://scripts/world/player_anim_loco.gd")
const LOC_IDLE := 0
const LOC_START := 1
const LOC_LOOP := 2
const LOC_STOP := 3


static func load_sprites(host: Node) -> void:
	Load.load_sprites(host)


static func warmup_texs(host: Node) -> Array:
	var out: Array = []
	if host == null:
		return out
	var seen: Dictionary = {}
	for k in Facing.KEYS:
		_add_tex(out, seen, pose_tex(host, k))
		for tex in clip(host.idle_to_walk, k):
			_add_tex(out, seen, tex)
		for tex in clip(host.walk, k):
			_add_tex(out, seen, tex)
		for tex in clip(host.walk_to_idle, k):
			_add_tex(out, seen, tex)
	return out


static func _add_tex(out: Array, seen: Dictionary, tex: Texture2D) -> void:
	if tex == null:
		return
	var id: int = tex.get_instance_id()
	if seen.has(id):
		return
	seen[id] = true
	out.append(tex)


static func warmup_physics(host: Node) -> void:
	if host == null or not (host is CharacterBody3D):
		return
	var body: CharacterBody3D = host
	var stored: Vector3 = body.velocity
	body.velocity = Vector3(0.12, 0.0, 0.0)
	body.move_and_slide()
	body.velocity = stored
	body.global_position.y = 0.0


static func warmup(host: Node) -> void:
	if host == null:
		return
	if host.body:
		host.body.visible = true
	for tex in warmup_texs(host):
		apply_tex(host, tex)
	warmup_physics(host)
	var down: Texture2D = pose_tex(host, "down")
	if down:
		apply_tex(host, down)
	host.loc_state = LOC_IDLE
	host.loc_t = 0.0
	host.walk_t = 0.0


static func pose_tex(host: Node, key: String) -> Texture2D:
	if host.idle.has(key):
		return host.idle[key]
	if host.idle.has("down"):
		return host.idle["down"]
	if host.equip.has(key):
		return host.equip[key]
	return null


static func clip(store: Dictionary, key: String) -> Array:
	if store.has(key):
		return store[key]
	var card := key
	if key.begins_with("up"):
		card = "up"
	elif key.begins_with("down"):
		card = "down"
	elif key.find("left") >= 0:
		card = "left"
	elif key.find("right") >= 0:
		card = "right"
	if store.has(card):
		return store[card]
	if store.has("down"):
		return store["down"]
	return []


static func apply_tex(host: Node, tex: Texture2D) -> void:
	if host.body == null or tex == null:
		return
	host.body.texture = tex
	SpriteFilt.apply_sprite(host.body)
	var th := float(maxi(1, tex.get_height()))
	host.body.pixel_size = T.PLAYER_H / th
	host.body.position.y = T.PLAYER_H * 0.5 + T.FEET_LIFT


static func apply_facing(host: Node, delta: float) -> void:
	Loco.apply_facing(host, delta)


static func _stop_from(li: int, loop_n: int, stop_n: int) -> int:
	if loop_n <= 0 or stop_n <= 0:
		return 0
	var half := int(loop_n / 2.0)
	if li < half:
		return 0
	var cross_b := half + int(half / 2.0)
	if li <= cross_b:
		return 0
	return stop_n - 1


static func _locomotion(host: Node, key: String, moving: bool, delta: float) -> Texture2D:
	return Loco._locomotion(host, key, moving, delta)
