extends RefCounted

const T := preload("res://scripts/data/tunables.gd")
const Facing := preload("res://scripts/world/facing.gd")


static func load_sprites(host: Node) -> void:
	host.idle.clear()
	host.walk.clear()
	host.equip.clear()
	host.attack.clear()
	host.special.clear()
	host.gather.clear()
	host.death.clear()
	host.dispel.clear()
	var kind: String = App.character_type
	var base := "res://assets/sprites/player/%s/" % kind
	var wpn: String = App.weapon
	for k in Facing.KEYS:
		var ip := base + "idle_%s.png" % k
		if ResourceLoader.exists(ip):
			host.idle[k] = load(ip)
		var ep := base + "equip_%s_%s.png" % [wpn, k]
		if ResourceLoader.exists(ep):
			host.equip[k] = load(ep)
		var frames: Array = []
		var i := 0
		while ResourceLoader.exists(base + "walk_%s_%d.png" % [k, i]):
			frames.append(load(base + "walk_%s_%d.png" % [k, i]))
			i += 1
		if not frames.is_empty():
			host.walk[k] = frames
		var atk: Array = []
		i = 0
		while ResourceLoader.exists(base + "atk_%s_%s_%d.png" % [wpn, k, i]):
			atk.append(load(base + "atk_%s_%s_%d.png" % [wpn, k, i]))
			i += 1
		if not atk.is_empty():
			host.attack[k] = atk
		var spc: Array = []
		i = 0
		while ResourceLoader.exists(base + "spc_%s_%s_%d.png" % [wpn, k, i]):
			spc.append(load(base + "spc_%s_%s_%d.png" % [wpn, k, i]))
			i += 1
		if not spc.is_empty():
			host.special[k] = spc
		var gth: Array = []
		i = 0
		while ResourceLoader.exists(base + "gather_%s_%d.png" % [k, i]):
			gth.append(load(base + "gather_%s_%d.png" % [k, i]))
			i += 1
		if not gth.is_empty():
			host.gather[k] = gth
		var dth: Array = []
		i = 0
		while ResourceLoader.exists(base + "death_%s_%d.png" % [k, i]):
			dth.append(load(base + "death_%s_%d.png" % [k, i]))
			i += 1
		if not dth.is_empty():
			host.death[k] = dth
		var dsp: Array = []
		i = 0
		while ResourceLoader.exists(base + "dispel_%s_%d.png" % [k, i]):
			dsp.append(load(base + "dispel_%s_%d.png" % [k, i]))
			i += 1
		if not dsp.is_empty():
			host.dispel[k] = dsp


static func pose_tex(host: Node, key: String) -> Texture2D:
	if host.equip.has(key):
		return host.equip[key]
	if host.idle.has(key):
		return host.idle[key]
	if host.idle.has("down"):
		return host.idle["down"]
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
	var th := float(maxi(1, tex.get_height()))
	host.body.pixel_size = T.PLAYER_H / th
	host.body.position.y = T.PLAYER_H * 0.5 + T.FEET_LIFT


static func apply_facing(host: Node, delta: float) -> void:
	var key := Facing.from_aim(host.aim_dir)
	host.facing_key = key
	var tex: Texture2D = null
	if host.exiting:
		var frames := clip(host.death if host.exit_cond == "death" else host.dispel, key)
		if not frames.is_empty():
			tex = frames[mini(frames.size() - 1, int(host.exit_t * 8.0))]
		elif host.idle.has(key):
			tex = host.idle[key]
		if tex:
			apply_tex(host, tex)
		return
	if host.atk_state == host.ATK_WIND or host.atk_state == host.ATK_ACT or host.atk_state == host.ATK_REC:
		var frames := clip(host.special, key)
		if frames.is_empty():
			frames = clip(host.attack, key)
		if not frames.is_empty():
			var idx := mini(frames.size() - 1, int(host.atk_t * App.bal.atk_fps))
			tex = frames[idx]
	elif host.gathering != null:
		var frames := clip(host.gather, key)
		if frames.is_empty():
			frames = clip(host.attack, key)
		if not frames.is_empty():
			var idx := mini(frames.size() - 1, int(host.gather_t * 6.0) % frames.size())
			tex = frames[idx]
	elif host.atk_state == host.ATK_BASIC:
		var frames := clip(host.attack, key)
		if not frames.is_empty():
			var idx := mini(frames.size() - 1, int(host.atk_t * App.bal.atk_fps))
			tex = frames[idx]
			host.atk_i = idx
	var planar := Vector2(host.velocity.x, host.velocity.z)
	var moving: bool = planar.length() > T.MOVE_EPS and host.dash_t <= 0.0 and host.atk_state == host.ATK_NONE
	if tex == null and moving and host.walk.has(key):
		var frames: Array = host.walk[key]
		host.walk_t += delta
		tex = frames[int(host.walk_t * T.WALK_FPS) % frames.size()]
	if tex == null:
		host.walk_t = 0.0
		tex = pose_tex(host, key)
	if tex:
		apply_tex(host, tex)