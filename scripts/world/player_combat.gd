extends Object

const PlayerHit := preload("res://scripts/combat/player_hit.gd")


static func try_dash(p: CharacterBody3D, move: Vector2) -> void:
	if App.ui_open or p.interact_lock > 0.0:
		return
	if p.dash_t > 0.0:
		return
	if not (p._ai_just("dash") or App.pad_just("dash")):
		return
	if p.dash_cd > 0.0:
		return
	if move.length() > 0.2:
		p.dash_dir = move.normalized()
	elif p.aim_dir.length() > 0.2:
		p.dash_dir = p.aim_dir
	p.dash_t = App.bal.dash_duration
	p.dash_cd = App.bal.dash_cooldown
	p.iframe = App.bal.dash_duration
	App.sfx("dash")
	if App.tel:
		App.tel.note_dash()


static func try_special(p: CharacterBody3D) -> void:
	if App.ui_open:
		p.special_held = p._ai_held("special") or App.pad_held("special")
		return
	var held: bool = p._ai_held("special") or App.pad_held("special")
	var pressed: bool = held and not p.special_held
	p.special_held = held
	if not pressed:
		return
	if p.atk_state != p.ATK_NONE or p.dash_t > 0.0:
		return
	p.atk_state = p.ATK_WIND
	p.atk_t = 0.0
	p.hit_done = false
	p.spec_point = p._special_point()
	p._draw_special_tele(false)
	if App.tel:
		App.tel.note_special(false)


static func try_basic(p: CharacterBody3D) -> void:
	if App.ui_open:
		return
	if p.atk_state != p.ATK_NONE or p.dash_t > 0.0:
		return
	if not (p._ai_held("attack") or App.pad_held("attack")):
		return
	p.atk_state = p.ATK_BASIC
	p.atk_t = 0.0
	p.hit_done = false
	p._draw_basic_tele(false)


static func advance_attack(p: CharacterBody3D, delta: float) -> void:
	if p.atk_state == p.ATK_NONE:
		if p.telegraph:
			p.telegraph.hide_now()
		return
	p.atk_t += delta
	if p.atk_state == p.ATK_BASIC:
		var dur: float = p._basic_duration()
		var hit_at: float = dur * p._hit_norm()
		if not p.hit_done and p.atk_t >= hit_at:
			p.hit_done = true
			p._draw_basic_tele(true)
			p._apply_basic()
		if p.atk_t >= dur:
			p.atk_state = p.ATK_NONE
			if p.telegraph:
				p.telegraph.hide_now()
		return
	if p.atk_state == p.ATK_WIND:
		p._draw_special_tele(false)
		if p.atk_t >= App.bal.special_windup:
			p.atk_state = p.ATK_ACT
			p.atk_t = 0.0
			p._draw_special_tele(true)
			p._apply_special()
		return
	if p.atk_state == p.ATK_ACT:
		if p.atk_t >= 0.16:
			p.atk_state = p.ATK_REC
			p.atk_t = 0.0
			if p.telegraph:
				p.telegraph.hide_now()
		return
	if p.atk_state == p.ATK_REC:
		if p.atk_t >= App.bal.special_recovery:
			p.atk_state = p.ATK_NONE


static func basic_duration() -> float:
	var rate: float = App.bal.axe_rate
	if App.weapon == "staff":
		rate = App.bal.staff_rate
	elif App.weapon == "longbow":
		rate = App.bal.bow_rate
	return 1.0 / maxf(0.2, rate)


static func hit_norm() -> float:
	if App.weapon == "staff":
		return App.bal.staff_hit_norm
	if App.weapon == "longbow":
		return App.bal.bow_hit_norm
	return App.bal.axe_hit_norm


static func update_aim_line(p: CharacterBody3D) -> void:
	if p.aim_line == null:
		return
	var bow_spec: bool = App.weapon == "longbow" and (p.atk_state == p.ATK_WIND or p.atk_state == p.ATK_ACT)
	var on: bool = bool(App.bal.aim_line_on) and not bow_spec
	var length: float = App.bal.aim_line_length
	if App.bal.aim_line_use_weapon_range:
		length = p._weapon_reach()
	if App.weapon == "longbow":
		length = App.bal.bow_range
	p.aim_line.update_line(p.global_position, p.aim_dir, length, App.bal.aim_line_width, App.bal.aim_line_opacity, on)


static func weapon_reach() -> float:
	if App.weapon == "great_axe":
		return maxf(App.bal.axe_range, App.bal.slam_radius)
	if App.weapon == "staff":
		return maxf(App.bal.staff_range, App.bal.staff_special_radius)
	return maxf(App.bal.bow_range, App.bal.bow_special_range)


static func update_aura(p: CharacterBody3D, delta: float) -> void:
	if p.aura == null:
		return
	var a: float = 0.55 if App.adrenaline else 0.0
	p.aura.modulate.a = move_toward(p.aura.modulate.a, a, delta * 3.0)
	p.aura.visible = p.aura.modulate.a > 0.02
	if p.aura.visible:
		p.aura.rotate_y(delta * 2.4)
		if p.body:
			p.aura.texture = p.body.texture
			p.aura.pixel_size = p.body.pixel_size * 1.15
			p.aura.position.y = p.body.position.y
