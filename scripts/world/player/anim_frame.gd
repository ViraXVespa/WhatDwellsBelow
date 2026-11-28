extends RefCounted

## Player frame picks and texture apply, shared by player_anim (warm-up, spawn) and anim_loco (every tick).

const T := preload("res://scripts/data/tunables.gd")
const SpriteFilt := preload("res://scripts/world/sprite_filter.gd")
const Chunky := preload("res://scripts/graphics/chunky.gd")

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
	var th := float(maxi(1, tex.get_height()))
	host.body.pixel_size = T.PLAYER_H / th
	# Hub: characters at the ground pixel size too (Chunky fast path, cached per frame).
	host.body.texture = tex if App.in_dungeon else Chunky.tex(tex, host.body.pixel_size, true)
	SpriteFilt.apply_sprite(host.body)
	host.body.position.y = T.PLAYER_H * 0.5 + T.FEET_LIFT

static func stop_from(li: int, loop_n: int, stop_n: int) -> int:
	if loop_n <= 0 or stop_n <= 0:
		return 0
	var half := int(loop_n / 2.0)
	if li < half:
		return 0
	var cross_b := half + int(half / 2.0)
	if li <= cross_b:
		return 0
	return stop_n - 1
