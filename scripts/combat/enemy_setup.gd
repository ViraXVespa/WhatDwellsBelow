extends Object

const Roster := preload("res://scripts/combat/roster.gd")
const Threat := preload("res://scripts/combat/threat.gd")
const HpBarS := preload("res://scripts/combat/hp_bar.gd")


static func setup(host: Node, id: String, floor_n: int, named := false, given_name := "") -> void:
	host.type_id = id
	var d: Dictionary = Roster.def(id)
	host.role = str(d.role)
	host.move_kind = str(d.move)
	var cycle := int((maxi(1, floor_n) - 1) / 5)
	host.combat_lv = resolve_cl(host, floor_n, false)
	var scaled: Dictionary = Threat.apply(float(d.hp) * App.bal.enemy_hp_mult, float(d.dmg) * App.bal.enemy_dmg_mult, float(d.def), host.combat_lv)
	host.hp = float(scaled.hp)
	host.damage = float(scaled.dmg)
	host.defense = float(scaled.def)
	host.move_spd = float(d.spd) * App.bal.enemy_speed_mult
	host.atk_range = float(d.range)
	host.arc_deg = float(d.arc)
	host.size_u = float(d.size)
	host.base_mod = Roster.cycle_tint(cycle)
	if named:
		make_named(host, given_name, floor_n)
	host.max_hp = host.hp
	paint_rank(host)
	load_tex(host)
	HpBarS.ensure(host)
	host.call_deferred("_mark_post")


static func setup_boss(host: Node, title: String, floor_n: int) -> void:
	host.is_boss = true
	host.add_to_group("boss")
	var id := "orc"
	host.role = "melee"
	host.move_kind = "walk"
	if title == "Gate Master":
		id = "shaman"
		host.role = "mage"
		host.move_kind = "walk"
	host.type_id = id
	var d: Dictionary = Roster.def(id)
	host.combat_lv = resolve_cl(host, floor_n, true)
	var scaled: Dictionary = Threat.apply(float(d.hp) * App.bal.enemy_hp_mult, float(d.dmg) * App.bal.enemy_dmg_mult * 1.8, float(d.def) + 10.0, host.combat_lv)
	var mult: float = App.bal.boss_hp_mult
	if title == "Gate Master":
		mult *= 1.35
	host.hp = float(scaled.hp) * mult
	host.max_hp = host.hp
	host.damage = float(scaled.dmg)
	host.defense = float(scaled.def)
	host.move_spd = float(d.spd) * 0.85 * App.bal.enemy_speed_mult
	host.atk_range = 2.4 if title != "Gate Master" else 4.6
	host.arc_deg = 140.0 if title != "Gate Master" else 360.0
	host.size_u = float(d.size) * 1.55
	host.base_mod = Color(1.15, 0.72, 0.55) if title != "Gate Master" else Color(0.72, 0.58, 1.18)
	host.tag.text = "%s  ·  Lv %d" % [title, host.combat_lv]
	host.tag.visible = true
	host.tag.modulate = Color(1.0, 0.82, 0.35)
	host.tag.outline_modulate = Color(0, 0, 0)
	load_tex(host, title)
	HpBarS.ensure(host)
	host.call_deferred("_mark_post")


static func resolve_cl(host: Node, floor_n: int, at_end: bool) -> int:
	if at_end:
		return Threat.floor_hi(floor_n)
	var parent := host.get_parent()
	if parent and parent.has_method("enemy_combat_lv"):
		return int(parent.enemy_combat_lv(host.global_position))
	return Threat.floor_lo(floor_n)


static func paint_rank(host: Node) -> void:
	if host.tag == null:
		return
	if host.is_boss or host.is_named:
		return
	host.tag.visible = false


static func make_named(host: Node, given: String, _floor_n: int) -> void:
	host.is_named = true
	host.add_to_group("named")
	host.named_name = given
	host.hp *= App.bal.named_hp
	host.damage *= App.bal.named_dmg
	host.size_u *= App.bal.named_scale
	host.atk_range *= 1.12
	host.tag.text = "%s  ·  Lv %d" % [host.named_name, host.combat_lv]
	host.tag.visible = true
	host.tag.position = Vector3(0.0, 0.08, 0.0)
	host.tag.modulate = Color(1.0, 0.92, 0.18)
	host.tag.outline_modulate = Color(0, 0, 0)
	host.tag.outline_size = 12
	host.base_mod *= Color(1.08, 1.05, 0.9)


static func load_tex(host: Node, boss_title := "") -> void:
	if host.spr == null:
		return
	var path := "res://assets/sprites/enemies/%s/idle_down.png" % host.type_id
	if boss_title == "Floor Guardian":
		var g := "res://assets/sprites/enemies/guardian/idle_down.png"
		if ResourceLoader.exists(g):
			path = g
	elif boss_title == "Gate Master":
		var m := "res://assets/sprites/enemies/gate_master/idle_down.png"
		if ResourceLoader.exists(m):
			path = m
	if not ResourceLoader.exists(path):
		path = "res://assets/fx/dummy.png"
	if ResourceLoader.exists(path):
		host.spr.texture = load(path)
		var th := float(maxi(1, host.spr.texture.get_height()))
		host.spr.pixel_size = host.size_u / th
	host.spr.position.y = host.size_u * 0.48
	host.spr.modulate = host.base_mod
	if host.is_named:
		host.tag.position.y = 0.08
	else:
		host.tag.position.y = host.size_u * 0.95 + 0.35
	host.bang.position.y = host.size_u * 0.95 + 0.65
