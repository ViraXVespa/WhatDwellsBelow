extends RefCounted

const T := preload("res://scripts/data/tunables.gd")
const Facing := preload("res://scripts/world/facing.gd")
const SpriteFilt := preload("res://scripts/world/sprite_filter.gd")
const LOC_IDLE := 0
const LOC_START := 1
const LOC_LOOP := 2
const LOC_STOP := 3

static func load_sprites(host: Node) -> void:
	var _fac = load("res://scripts/world/player_anim.gd")
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
		var frames := _fac._seq(base, "walk_%s" % k)
		if not frames.is_empty():
			host.walk[k] = frames
		frames = _fac._seq(base, "idle_to_walk_%s" % k)
		if not frames.is_empty():
			host.idle_to_walk[k] = frames
		frames = _fac._seq(base, "walk_to_idle_%s" % k)
		if not frames.is_empty():
			host.walk_to_idle[k] = frames
		var atk := _fac._seq(base, "atk_%s_%s" % [wpn, k])
		if not atk.is_empty():
			host.attack[k] = atk
		var spc := _fac._seq(base, "spc_%s_%s" % [wpn, k])
		if not spc.is_empty():
			host.special[k] = spc
		var gth := _fac._seq(base, "gather_%s" % k)
		if not gth.is_empty():
			host.gather[k] = gth
		var dth := _fac._seq(base, "death_%s" % k)
		if not dth.is_empty():
			host.death[k] = dth
		var dsp := _fac._seq(base, "dispel_%s" % k)
		if not dsp.is_empty():
			host.dispel[k] = dsp
