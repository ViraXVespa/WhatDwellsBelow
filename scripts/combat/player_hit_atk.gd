extends RefCounted

const Combat := preload("res://scripts/combat/combat.gd")
const Cover := preload("res://scripts/combat/cover.gd")
const ProjS := preload("res://scripts/combat/projectile.gd")
const PlayerLock := preload("res://scripts/world/player_lock.gd")
const Fx := preload("res://scripts/combat/player_hit_fx.gd")

static func apply_special(host: Node) -> void:
	var _fac = load("res://scripts/combat/player_hit.gd")
	var extra: float = _fac._gear("atk_range")
	if App.weapon == "great_axe":
		App.sfx("slam")
		Fx.hit_circle(host, host.global_position, App.bal.slam_radius + extra, App.bal.axe_damage * App.bal.axe_slam_mult, false, true, "auto", true)
		fx(host, "res://assets/fx/crack.png", host.global_position, 2.4, false)
		return
	if App.weapon == "staff":
		App.sfx("bolt")
		Fx.hit_circle(host, host.spec_point, App.bal.staff_special_radius + extra, App.bal.staff_special_damage, false, false, "magic", true)
		fx(host, "res://assets/fx/lightning.png", host.spec_point, 2.6, true)
		return
	App.sfx("bow")
	var n := int(App.bal.bow_special_count)
	var cone := deg_to_rad(App.bal.bow_special_cone)
	var base := atan2(host.aim_dir.y, host.aim_dir.x)
	for i in n:
		var t := 0.0 if n <= 1 else (float(i) / float(n - 1)) - 0.5
		var a := base + t * cone
		_fac.spawn_arrow(host, Vector2(cos(a), sin(a)), _fac.scaled_dmg(App.bal.bow_special_damage, true), App.bal.bow_special_range + extra, App.bal.bow_proj_speed, App.bal.bow_los)

static func trail(host: Node, delta: float) -> void:
	if not host.is_inside_tree():
		return
	if host.body == null or not is_instance_valid(host.body) or not host.body.is_inside_tree():
		return
	if host.body.texture == null:
		return
	host.trail_acc += delta
	if host.trail_acc < App.bal.trail_gap:
		return
	host.trail_acc = 0.0
	var world := host.get_parent()
	if world == null or not is_instance_valid(world) or not world.is_inside_tree():
		return
	var g := Sprite3D.new()
	g.texture = host.body.texture
	g.centered = true
	g.shaded = false
	g.billboard = BaseMaterial3D.BILLBOARD_FIXED_Y
	g.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	g.alpha_cut = SpriteBase3D.ALPHA_CUT_OPAQUE_PREPASS
	g.pixel_size = host.body.pixel_size
	g.modulate = Color(0.45, 0.85, 1.0, 0.55)
	world.add_child(g)
	g.global_position = host.body.global_position
	var tw := g.create_tween()
	tw.tween_property(g, "modulate:a", 0.0, App.bal.trail_life)
	tw.finished.connect(g.queue_free)

static func damage_enemy(host: Node, e: Node, dmg: float, stagger: bool, xp := "auto", _is_special := false, glance := false, can_crit := true) -> void:
	var _fac = load("res://scripts/combat/player_hit.gd")
	if xp == "magic":
		_is_special = true
	_fac.grant_hit_xp(xp)
	var chance: float = App.bal.crit_chance + _fac._gear("crit_chance")
	var crit := can_crit and Combat.roll_crit(chance)
	if "last_glance" in e:
		e.last_glance = glance and not crit
	if e.has_method("take_hit"):
		e.take_hit(dmg, host.aim_dir, crit)
	_fac._life_tap(host, e)
	if App.tel:
		var shown: float = dmg if not crit else dmg * (App.bal.crit_mult + _fac._gear("crit_dmg"))
		App.tel.note_damage_dealt(shown, crit)
		if host.atk_state == host.ATK_ACT or host.atk_state == host.ATK_WIND:
			App.tel.spec_hit += 1
			var key := App.weapon
			if App.tel.wpn.has(key):
				App.tel.wpn[key].spec_hit = int(App.tel.wpn[key].spec_hit) + 1
	if stagger and e.has_method("apply_stagger"):
		e.apply_stagger(App.bal.slam_stagger)

static func fx(host: Node, path: String, pos: Vector3, h: float, ybill: bool) -> void:
	if not ResourceLoader.exists(path):
		return
	var s := Sprite3D.new()
	s.texture = load(path)
	s.centered = true
	s.shaded = false
	s.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	s.alpha_cut = SpriteBase3D.ALPHA_CUT_OPAQUE_PREPASS
	s.billboard = BaseMaterial3D.BILLBOARD_FIXED_Y if ybill else BaseMaterial3D.BILLBOARD_DISABLED
	s.pixel_size = h / float(maxi(1, s.texture.get_height()))
	s.position = pos + Vector3(0.0, 0.02 if not ybill else h * 0.45, 0.0)
	if not ybill:
		s.rotation_degrees = Vector3(-90.0, 0.0, 0.0)
	var world := host.get_parent()
	if world:
		world.add_child(s)
	var tw := s.create_tween()
	tw.tween_property(s, "modulate:a", 0.0, 0.45)
	tw.finished.connect(s.queue_free)
