extends RefCounted

const Combat := preload("res://scripts/combat/combat.gd")
const Fx := preload("res://scripts/combat/player_hit/hit_fx.gd")
const Core := preload("res://scripts/combat/player_hit/hit_core.gd")

static func apply_special(host: Node) -> void:
	var extra: float = App.gear("atk_range")
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
		Core.spawn_arrow(host, Vector2(cos(a), sin(a)), Core.scaled_dmg(App.bal.bow_special_damage, true), App.bal.bow_special_range + extra, App.bal.bow_proj_speed, App.bal.bow_los)

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

static func fx(host: Node, path: String, pos: Vector3, h: float, ybill: bool) -> void:
	var s: Sprite3D = _spawn_fx(host, path, pos, h, ybill)
	if s == null:
		return
	var tw: Tween = s.create_tween()
	tw.tween_property(s, "modulate:a", 0.0, 0.45)
	tw.finished.connect(s.queue_free)

static func warm_shown(host: Node) -> void:
	if host == null or not is_instance_valid(host) or not host.is_inside_tree():
		return
	var crack: Sprite3D = _spawn_fx(host, "res://assets/fx/crack.png", host.global_position, 2.4, false)
	var bolt: Sprite3D = _spawn_fx(host, "res://assets/fx/lightning.png", host.global_position, 2.6, true)
	var rad: float = 2.2
	if App.bal:
		rad = float(App.bal.slam_radius)
	if host.telegraph != null and host.telegraph.has_method("show_circle"):
		host.telegraph.show_circle(host.global_position, rad, Color(1.0, 0.92, 0.35, 0.42))
	RenderingServer.force_draw()
	if host.telegraph != null and host.telegraph.has_method("hide_now"):
		host.telegraph.hide_now()
	if crack != null:
		crack.visible = false
		crack.queue_free()
	if bolt != null:
		bolt.visible = false
		bolt.queue_free()
	RenderingServer.force_draw()

static func _spawn_fx(host: Node, path: String, pos: Vector3, h: float, ybill: bool) -> Sprite3D:
	if not ResourceLoader.exists(path):
		return null
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
	var world: Node = host.get_parent()
	if world:
		world.add_child(s)
	return s
