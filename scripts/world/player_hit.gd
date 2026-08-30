extends RefCounted

const Combat := preload("res://scripts/combat/combat.gd")
const ProjS := preload("res://scripts/combat/projectile.gd")


static func draw_basic_tele(host: Node, active: bool) -> void:
	if host.telegraph == null:
		return
	var col := Color(1.0, 0.25, 0.18, 0.55) if active else Color(1.0, 0.82, 0.28, 0.4)
	if App.weapon == "longbow":
		host.telegraph.show_arc(host.global_position, host.aim_dir, App.bal.bow_range, 12.0, col)
		return
	if App.weapon == "staff":
		host.telegraph.show_arc(host.global_position, host.aim_dir, App.bal.staff_range, App.bal.staff_arc_deg, col)
		return
	host.telegraph.show_arc(host.global_position, host.aim_dir, App.bal.axe_range, App.bal.axe_arc_deg, col)


static func draw_special_tele(host: Node, active: bool) -> void:
	if host.telegraph == null:
		return
	var col := Color(0.45, 0.85, 1.0, 0.55) if active else Color(1.0, 0.82, 0.28, 0.42)
	if App.weapon == "great_axe":
		host.telegraph.show_circle(host.global_position, App.bal.slam_radius, col)
	elif App.weapon == "staff":
		host.telegraph.show_circle(host.spec_point, App.bal.staff_special_radius, col)
	else:
		host.telegraph.show_cone(host.global_position, host.aim_dir, App.bal.bow_special_range, App.bal.bow_special_cone, col)


static func special_point(host: Node) -> Vector3:
	if host._valid_lock(host.lock_target):
		return (host.lock_target as Node3D).global_position
	var reach: float = App.bal.staff_special_radius + 1.5
	return host.global_position + Vector3(host.aim_dir.x, 0.0, host.aim_dir.y) * reach


static func apply_basic(host: Node) -> void:
	if App.weapon == "longbow":
		spawn_arrow(host, host.aim_dir, scaled_dmg(App.bal.bow_damage, false), App.bal.bow_range, App.bal.bow_proj_speed, App.bal.bow_los)
		App.sfx("bow")
		return
	var rng: float = App.bal.axe_range
	var arc: float = App.bal.axe_arc_deg
	var dmg: float = App.bal.axe_damage
	var need_los: bool = App.bal.axe_los
	if App.weapon == "staff":
		rng = App.bal.staff_range
		arc = App.bal.staff_arc_deg
		dmg = App.bal.staff_damage
		need_los = App.bal.staff_los
		App.sfx("hit")
	else:
		App.sfx("hit")
	hit_arc(host, rng, arc, dmg, need_los, false)


static func apply_special(host: Node) -> void:
	if App.weapon == "great_axe":
		App.sfx("slam")
		hit_circle(host, host.global_position, App.bal.slam_radius, App.bal.axe_damage * App.bal.axe_slam_mult, false, true, "auto", true)
		fx(host, "res://assets/fx/crack.png", host.global_position, 2.4, false)
		return
	if App.weapon == "staff":
		App.sfx("bolt")
		hit_circle(host, host.spec_point, App.bal.staff_special_radius, App.bal.staff_special_damage, false, false, "magic", true)
		fx(host, "res://assets/fx/lightning.png", host.spec_point, 2.6, true)
		return
	App.sfx("bow")
	var n := int(App.bal.bow_special_count)
	var cone := deg_to_rad(App.bal.bow_special_cone)
	var base := atan2(host.aim_dir.y, host.aim_dir.x)
	for i in n:
		var t := 0.0 if n <= 1 else (float(i) / float(n - 1)) - 0.5
		var a := base + t * cone
		var d := Vector2(cos(a), sin(a))
		spawn_arrow(host, d, scaled_dmg(App.bal.bow_special_damage, true), App.bal.bow_special_range, App.bal.bow_proj_speed, App.bal.bow_los)


static func hit_arc(host: Node, rng: float, arc: float, dmg: float, need_los: bool, stagger: bool) -> void:
	for e in Combat.enemies():
		if e == null or not is_instance_valid(e):
			continue
		if e.has_method("is_alive") and not e.is_alive():
			continue
		var p: Vector3 = (e as Node3D).global_position
		if not Combat.in_arc(host.global_position, host.aim_dir, rng, arc, p):
			continue
		if need_los and not Combat.los(host.global_position, p, host.get_world_3d()):
			continue
		damage_enemy(host, e, dmg, stagger, "auto", false)
	hit_breakables_arc(host, rng, arc, dmg, need_los)


static func hit_circle(host: Node, origin: Vector3, radius: float, dmg: float, need_los: bool, stagger: bool, xp := "auto", is_special := false) -> void:
	for e in Combat.enemies():
		if e == null or not is_instance_valid(e):
			continue
		if e.has_method("is_alive") and not e.is_alive():
			continue
		var p: Vector3 = (e as Node3D).global_position
		if not Combat.in_circle(origin, radius, p):
			continue
		if need_los and not Combat.los(origin, p, host.get_world_3d()):
			continue
		damage_enemy(host, e, dmg, stagger, xp, is_special)
	hit_breakables_circle(host, origin, radius, dmg, need_los)


static func scaled_dmg(base: float, is_special: bool) -> float:
	var d: float = base * App.prog.skill_dmg_mult(is_special) + App.prog.gear_dmg()
	if App.shrine_t > 0.0:
		d *= 1.0 + App.bal.shrine_dmg
	return d


static func damage_enemy(host: Node, e: Node, dmg: float, stagger: bool, xp := "auto", is_special := false) -> void:
	if xp == "magic":
		is_special = true
	dmg = dmg * App.prog.skill_dmg_mult(is_special) + App.prog.gear_dmg()
	if App.shrine_t > 0.0:
		dmg *= 1.0 + App.bal.shrine_dmg
	grant_hit_xp(xp)
	var crit := Combat.roll_crit(App.bal.crit_chance + float(App.prog.set_stats().crit))
	if e.has_method("take_hit"):
		e.take_hit(dmg, host.aim_dir, crit)
	if App.tel:
		App.tel.note_damage_dealt(dmg if not crit else dmg * App.bal.crit_mult, crit)
		if host.atk_state == host.ATK_ACT or host.atk_state == host.ATK_WIND:
			App.tel.spec_hit += 1
			var key := App.weapon
			if App.tel.wpn.has(key):
				App.tel.wpn[key].spec_hit = int(App.tel.wpn[key].spec_hit) + 1
	if stagger and e.has_method("apply_stagger"):
		e.apply_stagger(App.bal.slam_stagger)


static func grant_hit_xp(xp: String) -> void:
	var mode := xp
	if mode == "none":
		return
	if mode == "auto":
		if App.weapon == "staff":
			mode = "melee_staff"
		elif App.weapon == "longbow":
			mode = "ranged"
		else:
			mode = "melee_axe"
	if mode == "magic":
		App.prog.skill_grant_hit(true)
	elif mode == "ranged":
		App.prog.skill_grant_hit(false)
	elif mode == "melee_staff":
		App.prog.skill_grant_hit(false)
	else:
		App.prog.skill_grant_hit(false)


static func hit_breakables_arc(host: Node, rng: float, arc: float, dmg: float, need_los: bool) -> void:
	for b in host.get_tree().get_nodes_in_group("breakables"):
		if b == null or not is_instance_valid(b):
			continue
		var p: Vector3 = (b as Node3D).global_position
		if not Combat.in_arc(host.global_position, host.aim_dir, rng + 0.35, arc, p):
			continue
		if need_los and not Combat.los(host.global_position, p, host.get_world_3d()):
			continue
		if b.has_method("take_hit"):
			b.take_hit(dmg, host.aim_dir, false)


static func hit_breakables_circle(host: Node, origin: Vector3, radius: float, dmg: float, need_los: bool) -> void:
	for b in host.get_tree().get_nodes_in_group("breakables"):
		if b == null or not is_instance_valid(b):
			continue
		var p: Vector3 = (b as Node3D).global_position
		if not Combat.in_circle(origin, radius + 0.25, p):
			continue
		if need_los and not Combat.los(origin, p, host.get_world_3d()):
			continue
		if b.has_method("take_hit"):
			b.take_hit(dmg, host.aim_dir, false)


static func spawn_arrow(host: Node, dir: Vector2, dmg: float, rng: float, spd: float, need_los: bool) -> void:
	var p: Node3D = ProjS.new()
	var world := host.get_parent()
	if world:
		world.add_child(p)
	else:
		host.add_child(p)
	var crit := Combat.roll_crit(App.bal.crit_chance + float(App.prog.set_stats().crit))
	p.setup(host.global_position, dir, spd, rng, dmg, need_los, crit, false, "", true)


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