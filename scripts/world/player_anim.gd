extends RefCounted

const T := preload("res://scripts/data/tunables.gd")
const Facing := preload("res://scripts/world/facing.gd")
const SpriteFilt := preload("res://scripts/world/sprite_filter.gd")
const LOC_IDLE := 0
const LOC_START := 1
const LOC_LOOP := 2
const LOC_STOP := 3


static func _seq(base: String, prefix: String) -> Array:
	var frames: Array = []
	var i := 0
	while ResourceLoader.exists(base + "%s_%d.png" % [prefix, i]):
		frames.append(SpriteFilt.ensure_mips(load(base + "%s_%d.png" % [prefix, i])))
		i += 1
	return frames


static func load_sprites(host: Node) -> void:
	host.idle.clear()
	host.walk.clear()
	host.idle_to_walk.clear()
	host.walk_to_idle.clear()
	host.equip.clear()
	host.attack.clear()
	host.special.clear()
	host.gather.clear()
	host.death.clear()
	host.dispel.clear()
	host.loc_state = LOC_IDLE
	host.loc_t = 0.0
	host.walk_t = 0.0
	host.loc_foot = 0
	host.loc_rev = false
	host.loc_from = 0
	var kind: String = App.character_type
	var base := "res://assets/sprites/player/%s/" % kind
	var wpn: String = App.weapon
	for k in Facing.KEYS:
		var ip := base + "idle_%s.png" % k
		if ResourceLoader.exists(ip):
			host.idle[k] = SpriteFilt.ensure_mips(load(ip))
		var ep := base + "equip_%s_%s.png" % [wpn, k]
		if ResourceLoader.exists(ep):
			host.equip[k] = SpriteFilt.ensure_mips(load(ep))
		var frames := _seq(base, "walk_%s" % k)
		if not frames.is_empty():
			host.walk[k] = frames
		frames = _seq(base, "idle_to_walk_%s" % k)
		if not frames.is_empty():
			host.idle_to_walk[k] = frames
		frames = _seq(base, "walk_to_idle_%s" % k)
		if not frames.is_empty():
			host.walk_to_idle[k] = frames
		var atk := _seq(base, "atk_%s_%s" % [wpn, k])
		if not atk.is_empty():
			host.attack[k] = atk
		var spc := _seq(base, "spc_%s_%s" % [wpn, k])
		if not spc.is_empty():
			host.special[k] = spc
		var gth := _seq(base, "gather_%s" % k)
		if not gth.is_empty():
			host.gather[k] = gth
		var dth := _seq(base, "death_%s" % k)
		if not dth.is_empty():
			host.death[k] = dth
		var dsp := _seq(base, "dispel_%s" % k)
		if not dsp.is_empty():
			host.dispel[k] = dsp


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
	var moving: bool = planar.length() > T.MOVE_EPS and host.dash_t <= 0.0 and host.atk_state == host.ATK_NONE and host.gathering == null
	if tex == null:
		tex = _locomotion(host, key, moving, delta)
	if tex:
		apply_tex(host, tex)


static func _stop_from(li: int, loop_n: int, stop_n: int) -> int:
	# 8 sequential walk frames: 0–3 first foot, 4–7 opposite foot.
	# Opposite foot uses walk_to_idle forward. Early in that half → full clip.
	# Late (past the second-half crossover) → tail only.
	if loop_n <= 0 or stop_n <= 0:
		return 0
	var half := loop_n / 2
	if li < half:
		return 0
	var cross_b := half + half / 2
	if li <= cross_b:
		return 0
	return stop_n - 1


static func _locomotion(host: Node, key: String, moving: bool, delta: float) -> Texture2D:
	var start_f := clip(host.idle_to_walk, key)
	var loop_f := clip(host.walk, key)
	var stop_f := clip(host.walk_to_idle, key)
	if moving:
		if host.loc_state == LOC_IDLE or host.loc_state == LOC_STOP:
			host.loc_state = LOC_START if not start_f.is_empty() else LOC_LOOP
			host.loc_t = 0.0
			host.walk_t = 0.0
			host.loc_foot = 0
			host.loc_rev = false
			host.loc_from = 0
		if host.loc_state == LOC_START:
			host.loc_t += delta
			var idx := int(host.loc_t * T.WALK_FPS)
			if idx >= start_f.size():
				host.loc_state = LOC_LOOP
				host.walk_t = 0.0
				host.loc_foot = 0
				host.loc_from = 0
			else:
				host.loc_from = idx
				return start_f[idx]
		if host.loc_state == LOC_LOOP and not loop_f.is_empty():
			host.walk_t += delta
			var li := int(host.walk_t * T.WALK_FPS) % loop_f.size()
			host.loc_from = li
			host.loc_foot = 0 if li * 2 < loop_f.size() else 1
			return loop_f[li]
	else:
		if host.loc_state == LOC_START:
			# Same foot as the start clip. Play the already-shown idle_to_walk segment backward.
			host.loc_rev = true
			host.loc_state = LOC_STOP
			host.loc_t = 0.0
		elif host.loc_state == LOC_LOOP:
			# First foot → idle_to_walk backward. Opposite foot → walk_to_idle forward.
			# If that clip is missing, use the other clip in the direction that ends on idle.
			host.loc_rev = host.loc_foot == 0
			if host.loc_rev:
				if start_f.is_empty() and not stop_f.is_empty():
					host.loc_rev = false
					host.loc_from = _stop_from(host.loc_from, loop_f.size(), stop_f.size())
				else:
					host.loc_from = maxi(0, start_f.size() - 1)
			else:
				if stop_f.is_empty() and not start_f.is_empty():
					host.loc_rev = true
					host.loc_from = maxi(0, start_f.size() - 1)
				else:
					host.loc_from = _stop_from(host.loc_from, loop_f.size(), stop_f.size())
			host.loc_state = LOC_STOP
			host.loc_t = 0.0
			host.walk_t = 0.0
		if host.loc_state == LOC_STOP:
			host.loc_t += delta
			var idx2 := int(host.loc_t * T.WALK_FPS)
			if host.loc_rev and not start_f.is_empty():
				var span := maxi(1, host.loc_from + 1)
				if idx2 >= span:
					host.loc_state = LOC_IDLE
				else:
					return start_f[mini(start_f.size() - 1, span - 1 - idx2)]
			elif not stop_f.is_empty():
				var si := clampi(host.loc_from, 0, stop_f.size() - 1)
				if idx2 >= stop_f.size() - si:
					host.loc_state = LOC_IDLE
				else:
					return stop_f[si + idx2]
			else:
				host.loc_state = LOC_IDLE
		host.walk_t = 0.0
	return pose_tex(host, key)
