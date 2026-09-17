extends RefCounted

const Facing := preload("res://scripts/world/facing.gd")
const SpriteFilt := preload("res://scripts/world/sprite_filter.gd")
const LOC_IDLE := 0
const LOC_START := 1
const LOC_LOOP := 2
const LOC_STOP := 3
const WALK_N := 8
const START_N := 3
const STOP_N := 3
const ATK_N := 6
const SPC_N := 6


static func _load_n(base: String, prefix: String, n: int) -> Array:
	var frames: Array = []
	var i: int = 0
	while i < n:
		var path: String = base + "%s_%d.png" % [prefix, i]
		frames.append(SpriteFilt.ensure_mips(load(path)))
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
	var base: String = "res://assets/sprites/player/%s/" % kind
	var wpn: String = App.weapon
	for k in Facing.KEYS:
		host.idle[k] = SpriteFilt.ensure_mips(load(base + "idle_%s.png" % k))
		var ep: String = base + "equip_%s_%s.png" % [wpn, k]
		if ResourceLoader.exists(ep):
			host.equip[k] = SpriteFilt.ensure_mips(load(ep))


static func _player_base() -> String:
	return "res://assets/sprites/player/%s/" % App.character_type


static func ensure_loco(host: Node, key: String) -> void:
	if host.walk.has(key):
		return
	var base: String = _player_base()
	if not ResourceLoader.exists(base + "walk_%s_0.png" % key):
		if key != "down":
			ensure_loco(host, "down")
		return
	host.walk[key] = _load_n(base, "walk_%s" % key, WALK_N)
	host.idle_to_walk[key] = _load_n(base, "idle_to_walk_%s" % key, START_N)
	host.walk_to_idle[key] = _load_n(base, "walk_to_idle_%s" % key, STOP_N)


static func ensure_attack(host: Node, key: String) -> void:
	if host.attack.has(key) or host.attack.has("down"):
		return
	var base: String = _player_base()
	var wpn: String = App.weapon
	var k: String = key
	if not ResourceLoader.exists(base + "atk_%s_%s_0.png" % [wpn, k]):
		k = "down"
	if host.attack.has(k):
		return
	if not ResourceLoader.exists(base + "atk_%s_%s_0.png" % [wpn, k]):
		return
	host.attack[k] = _load_n(base, "atk_%s_%s" % [wpn, k], ATK_N)
	if ResourceLoader.exists(base + "spc_%s_%s_0.png" % [wpn, k]):
		host.special[k] = _load_n(base, "spc_%s_%s" % [wpn, k], SPC_N)
