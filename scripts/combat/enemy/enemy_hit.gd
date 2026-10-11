extends Object

## Enemy hit / stagger / death / loot.

const Threat := preload("res://scripts/combat/threat.gd")
const Affix := preload("res://scripts/data/affixes.gd")
const HpBarS := preload("res://scripts/combat/hp_bar.gd")
const FloatS := preload("res://scripts/combat/float_num.gd")

static func take_hit(host: CharacterBody3D, raw: float, from_dir: Vector2, crit: bool) -> void:
	if host.dead:
		return
	var dmg: float = App.bal.apply_defense(raw, host.defense)
	dmg *= Threat.received_mult(host.combat_lv)
	if crit:
		dmg *= App.bal.crit_mult + App.gear("crit_dmg")
		host.flash = 0.16
	else:
		host.flash = 0.08
	host.hp = maxf(0.0, host.hp - dmg)
	HpBarS.pulse(host, host.hp, host.max_hp, host.combat_lv)
	host.knock = Vector3(from_dir.x, 0.0, from_dir.y) * App.bal.knockback
	host.knock_t = 0.12
	float_num(host, int(round(dmg)), crit)
	App.hitstop(App.bal.hitstop)
	App.sfx("hit" if not crit else "crit")
	var parent := host.get_parent()
	if parent and parent.has_method("note_enemy_hit"):
		parent.note_enemy_hit(host, dmg)
	if host.hp <= 0.0:
		die(host)

static func apply_stagger(host: CharacterBody3D, sec: float) -> void:
	if host.is_boss:
		host.stagger = maxf(host.stagger, App.bal.slam_stagger_boss)
	else:
		host.stagger = maxf(host.stagger, sec)

static func float_num(host: CharacterBody3D, amount: int, crit: bool) -> void:
	var glance: bool = host.last_glance and not crit
	host.last_glance = false
	FloatS.spawn(host, amount, crit, glance, host.size_u * 0.7)

static func die(host: CharacterBody3D) -> void:
	if host.dead:
		return
	host.dead = true
	App.on_kill()
	App.prog.note_kill(host.type_id, host.named_name)
	host.collision_layer = 0
	HpBarS.pulse(host, 0.0, host.max_hp, host.combat_lv)
	if host.telegraph:
		host.telegraph.hide_now()
	if host.is_boss:
		App.notify_boss_dead()
	drop_loot(host)
	host.state = host.ST_REC
	var tw := host.create_tween()
	tw.tween_property(host.spr, "modulate:a", 0.0, 0.42)
	if host.spr:
		tw.parallel().tween_property(host.spr, "pixel_size", host.spr.pixel_size * 0.86, 0.42)
	tw.finished.connect(host.queue_free)

static func drop_loot(host: CharacterBody3D) -> void:
	var parent := host.get_parent()
	if parent == null:
		return
	var gold_n := gold_amount(host.is_boss)
	var PickupS := load("res://scripts/world/pickup.gd")
	for k: String in roll_drops(host.is_boss):
		var g: Node3D = PickupS.new()
		parent.add_child(g)
		g.setup(k, host.global_position + Vector3(randf_range(-0.3, 0.3), 0.0, randf_range(-0.3, 0.3)), gold_n if k == "gold" else 0)
	if host.is_boss:
		return
	if randf() < App.bal.enemy_gear_chance + App.bal.enemy_gear_floor * float(App.floor_n):
		var rarity := "white"
		if randf() < App.bal.enemy_gear_green:
			rarity = "green"
		var item := App.prog.make_armor(Affix.ARMOR_SLOTS[randi() % Affix.ARMOR_SLOTS.size()], rarity)
		if not App.prog.add_item(item):
			App.spawn_floor_item(item, host.global_position)
		else:
			App.toast(str(item.name))
			App.sfx("pickup")

## Coins in one gold drop. Normal kills scale the old roll by 1 / enemy_gold_chance so expected gold per kill matches
## the old always-drop; bosses (always drop) keep the old roll plus boss_gold_extra.
static func gold_amount(boss: bool) -> int:
	var n := int(App.bal.enemy_gold_base) + randi() % maxi(1, int(App.bal.enemy_gold_span) + mini(4, App.floor_n))
	if boss:
		return n + int(App.bal.boss_gold_extra)
	return maxi(1, roundi(float(n) / maxf(0.01, App.bal.enemy_gold_chance)))

## Walk-over pickups for one kill: "gold" / "hp" / "mana", each its own roll (any mix, or nothing).
static func roll_drops(boss: bool) -> PackedStringArray:
	var out := PackedStringArray()
	if boss or randf() < App.bal.enemy_gold_chance:
		out.append("gold")
	if randf() < App.bal.enemy_orb_chance:
		out.append("hp")
	if randf() < App.bal.enemy_mana_chance:
		out.append("mana")
	return out

static func mark_post(host: CharacterBody3D) -> void:
	host.post = host.global_position
	host.last_seen = host.global_position
	host.last_pos = host.global_position
