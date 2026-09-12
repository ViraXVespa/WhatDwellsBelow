extends RefCounted

const T := preload("res://scripts/data/tunables.gd")
const Facing := preload("res://scripts/world/facing.gd")
const SpriteFilt := preload("res://scripts/world/sprite_filter.gd")
const LOC_IDLE := 0
const LOC_START := 1
const LOC_LOOP := 2
const LOC_STOP := 3

static func _locomotion(host: Node, key: String, moving: bool, delta: float) -> Texture2D:
	var _fac = load("res://scripts/world/player_anim.gd")
	var start_f: Array = _fac.clip(host.idle_to_walk, key)
	var loop_f: Array = _fac.clip(host.walk, key)
	var stop_f: Array = _fac.clip(host.walk_to_idle, key)
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
			var li: int = int(host.walk_t * T.WALK_FPS) % loop_f.size()
			host.loc_from = li
			host.loc_foot = 0 if li * 2 < loop_f.size() else 1
			return loop_f[li]
	else:
		if host.loc_state == LOC_START:
			# Same foot as the start _fac.clip. Play the already-shown idle_to_walk segment backward.
			host.loc_rev = true
			host.loc_state = LOC_STOP
			host.loc_t = 0.0
		elif host.loc_state == LOC_LOOP:
			# First foot -> idle_to_walk backward. Opposite foot -> walk_to_idle forward.
			# If that _fac.clip is missing, use the other _fac.clip in the direction that ends on idle.
			host.loc_rev = host.loc_foot == 0
			if host.loc_rev:
				if start_f.is_empty() and not stop_f.is_empty():
					host.loc_rev = false
					host.loc_from = _fac._stop_from(host.loc_from, loop_f.size(), stop_f.size())
				else:
					host.loc_from = maxi(0, start_f.size() - 1)
			else:
				if stop_f.is_empty() and not start_f.is_empty():
					host.loc_rev = true
					host.loc_from = maxi(0, start_f.size() - 1)
				else:
					host.loc_from = _fac._stop_from(host.loc_from, loop_f.size(), stop_f.size())
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
	return _fac.pose_tex(host, key)

static func apply_facing(host: Node, delta: float) -> void:
	var _fac = load("res://scripts/world/player_anim.gd")
	var key := Facing.from_aim(host.aim_dir)
	host.facing_key = key
	var tex: Texture2D = null
	if host.exiting:
		var frames: Array = _fac.clip(host.death if host.exit_cond == "death" else host.dispel, key)
		if not frames.is_empty():
			tex = frames[mini(frames.size() - 1, int(host.exit_t * 8.0))]
		elif host.idle.has(key):
			tex = host.idle[key]
		if tex:
			_fac.apply_tex(host, tex)
		return
	if host.atk_state == host.ATK_WIND or host.atk_state == host.ATK_ACT or host.atk_state == host.ATK_REC:
		var frames: Array = _fac.clip(host.special, key)
		if frames.is_empty():
			frames = _fac.clip(host.attack, key)
		if not frames.is_empty():
			var idx := mini(frames.size() - 1, int(host.atk_t * App.bal.atk_fps))
			tex = frames[idx]
	elif host.gathering != null:
		var frames: Array = _fac.clip(host.gather, key)
		if frames.is_empty():
			frames = _fac.clip(host.attack, key)
		if not frames.is_empty():
			var idx := mini(frames.size() - 1, int(host.gather_t * 6.0) % frames.size())
			tex = frames[idx]
	elif host.atk_state == host.ATK_BASIC:
		var frames: Array = _fac.clip(host.attack, key)
		if not frames.is_empty():
			var n: int = frames.size()
			var dur: float = host._basic_duration()
			var idx: int = 0
			if n > 1 and dur > 0.0:
				idx = clampi(int(host.atk_t / dur * float(n - 1)), 0, n - 1)
			tex = frames[idx]
			host.atk_i = idx
	var planar := Vector2(host.velocity.x, host.velocity.z)
	var moving: bool = planar.length() > T.MOVE_EPS and host.dash_t <= 0.0 and host.atk_state == host.ATK_NONE and host.gathering == null
	if tex == null:
		tex = _locomotion(host, key, moving, delta)
	if tex:
		_fac.apply_tex(host, tex)
