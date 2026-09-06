extends Node3D

const Combat := preload("res://scripts/combat/combat.gd")
const Cover := preload("res://scripts/combat/cover.gd")
const Depth := preload("res://scripts/world/depth.gd")

var dir := Vector2.DOWN
var speed := 14.0
var max_range := 8.0
var damage := 14.0
var live_dmg := 14.0
var traveled := 0.0
var los_flag := true
var crit := false
var hurt_player := false
var grant_xp := false
var source := ""
var spr: Sprite3D
var seen: Dictionary = {}
var body_hits: Dictionary = {}
var glanced := false
var lock_e: Node = null
var lock_cov := 0.0
var lock_t := 0.0
const EMBED := 0.05
const SHOULDER := 1.08


func setup(from: Vector3, aim: Vector2, spd: float, rng: float, dmg: float, need_los: bool, is_crit := false, from_enemy := false, tex_path := "", player_xp := false) -> void:
	dir = aim.normalized() if aim.length_squared() > 0.0001 else Vector2.DOWN
	speed = spd
	max_range = rng
	damage = dmg
	live_dmg = dmg
	los_flag = need_los
	crit = is_crit
	hurt_player = from_enemy
	grant_xp = player_xp and not from_enemy
	global_position = Vector3(from.x, SHOULDER, from.z)
	spr = Sprite3D.new()
	spr.centered = true
	spr.offset = Vector2.ZERO
	spr.shaded = false
	spr.billboard = BaseMaterial3D.BILLBOARD_DISABLED
	spr.no_depth_test = true
	spr.render_priority = 32
	spr.alpha_cut = SpriteBase3D.ALPHA_CUT_DISABLED
	spr.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	var path := tex_path if tex_path != "" else "res://assets/fx/arrow.png"
	if ResourceLoader.exists(path):
		spr.texture = load(path)
		spr.pixel_size = 0.7 / float(maxi(1, spr.texture.get_width()))
	else:
		spr.modulate = Color(0.85, 0.7, 0.4)
		spr.pixel_size = 0.01
	if hurt_player:
		spr.modulate = Color(1.15, 0.45, 0.35)
	add_child(spr)
	_face()


func _face() -> void:
	var fwd := Vector3(dir.x, 0.0, dir.y)
	if fwd.length_squared() <= 0.0001:
		fwd = Vector3.FORWARD
	else:
		fwd = fwd.normalized()
	var right := Vector3.UP.cross(fwd)
	if right.length_squared() <= 0.0001:
		right = Vector3.RIGHT
	else:
		right = right.normalized()
	transform.basis = Basis(fwd, right, Vector3.UP)
	global_position = Vector3(global_position.x, SHOULDER, global_position.z)
	if spr:
		spr.rotation = Vector3.ZERO
		var thick := 0.0
		if spr.texture:
			thick = float(spr.texture.get_height()) * spr.pixel_size
		spr.position = Vector3(0.0, thick * 0.3, 0.0)


func _tip() -> Vector3:
	var extra := 0.18
	if spr and spr.texture:
		extra = maxf(0.12, float(spr.texture.get_width()) * spr.pixel_size * 0.45)
	return global_position + Vector3(dir.x, 0.0, dir.y) * extra


func _tip_r() -> float:
	var r := 0.16
	if App.bal:
		r = float(App.bal.arrow_tip_radius)
	return maxf(0.08, r)


func _physics_process(delta: float) -> void:
	var step := speed * delta
	var from := global_position
	var to := from + Vector3(dir.x, 0.0, dir.y) * step
	var space := get_world_3d().direct_space_state
	var q := PhysicsRayQueryParameters3D.create(from, to)
	q.collision_mask = 1
	var wall := space.intersect_ray(q)
	if not wall.is_empty():
		_flush()
		queue_free()
		return
	global_position = to
	traveled += step
	_face()
	if _strike(delta):
		return
	if traveled >= max_range:
		_flush()
		queue_free()


func _cov_at(host: Node3D) -> float:
	return Cover.hit_shot(_tip(), dir, _tip_r(), host)


func _strike(delta: float) -> bool:
	var tip := _tip()
	var rad := _tip_r()
	if hurt_player:
		var tree := get_tree()
		if tree:
			var pnode := tree.get_first_node_in_group("player")
			if pnode is Node3D and pnode.has_method("take_hit"):
				var cov := _cov_at(pnode)
				if Cover.connected(cov):
					pnode.take_hit(live_dmg * Cover.dmg_mult(cov), dir, crit and Cover.crit_ok(cov), source)
					queue_free()
					return true
		return false
	_smash_breakables(tip, rad)
	var best: Node = null
	var best_cov := 0.0
	for e in Combat.enemies():
		if e == null or not is_instance_valid(e):
			continue
		if e.has_method("is_alive") and not e.is_alive():
			continue
		if body_hits.has(e.get_instance_id()):
			continue
		var cov := _cov_at(e as Node3D)
		if Cover.connected(cov) and cov >= best_cov:
			best_cov = cov
			best = e
	if best != null:
		if lock_e != null and lock_e != best:
			if _resolve(lock_e, lock_cov):
				return true
		lock_e = best
		lock_cov = maxf(lock_cov, best_cov)
		lock_t += delta
		if lock_cov >= 0.999 or lock_t >= EMBED:
			return _resolve(lock_e, lock_cov)
		return false
	if lock_e != null:
		return _resolve(lock_e, lock_cov)
	return false


func _resolve(e: Node, cov: float) -> bool:
	if e == null or not is_instance_valid(e):
		_clear_lock()
		return false
	var id := e.get_instance_id()
	if body_hits.has(id):
		_clear_lock()
		return false
	body_hits[id] = true
	_hit(e, cov)
	_clear_lock()
	if Cover.stops_arrow(cov) or glanced:
		queue_free()
		return true
	glanced = true
	live_dmg *= maxf(0.05, 1.0 - cov)
	return false


func _flush() -> void:
	if lock_e != null:
		_resolve(lock_e, lock_cov)


func _clear_lock() -> void:
	lock_e = null
	lock_cov = 0.0
	lock_t = 0.0


func _smash_breakables(tip: Vector3, rad: float) -> void:
	if hurt_player:
		return
	var tree := get_tree()
	if tree == null:
		return
	for b in tree.get_nodes_in_group("breakables"):
		if b == null or not is_instance_valid(b) or not (b is Node3D):
			continue
		var id := b.get_instance_id()
		if seen.has(id):
			continue
		var cov := Cover.hit_shot(tip, dir, rad, b as Node3D)
		if not Cover.connected(cov):
			continue
		seen[id] = true
		if b.has_method("take_hit"):
			b.take_hit(damage, dir, false)


func _hit(e: Node, cov: float) -> void:
	if "last_glance" in e:
		e.last_glance = not Cover.stops_arrow(cov)
	if grant_xp:
		App.prog.skill_grant_hit(false)
	var dealt: float = live_dmg * Cover.dmg_mult(cov)
	if e.has_method("take_hit"):
		e.take_hit(dealt, dir, crit and Cover.crit_ok(cov))
	if grant_xp and App.tel:
		App.tel.note_damage_dealt(dealt if not (crit and Cover.crit_ok(cov)) else dealt * App.bal.crit_mult, crit and Cover.crit_ok(cov))
