extends Object


static func begin_run(host: Node) -> void:
	host.floor_n = maxi(1, host.prog.start_floor)
	host.run_seed = randi()
	if host.run_seed == 0:
		host.run_seed = 1
	host.boss_dead = false
	host.saw_stairs = false
	host.boss_low = false
	host.run_xp = 0.0
	host.adrenaline = false
	host.last_style = "str"
	host.floors_since_named = 0
	host.shrine_t = 0.0
	host.extracted = false
	host.run_hp = -1.0
	host.clerk_t = -1.0
	host.mine_hits_landed = 0
	host.mine_success = 0
	host.wood_hits_landed = 0
	host.wood_success = 0
	host.shop_buys = 0
	host.shop_spent = 0
	host.ui_open = false
	host.prog.begin_run_loadout()
	host.weapon = str(host.prog.slots.weapon.get("weapon", "great_axe")) if not host.prog.slots.weapon.is_empty() else "great_axe"
	if host.playtest == null or not bool(host.playtest.get("live_running")):
		host.tel.reset("human", false)
	host.go_dungeon()


static func go_dungeon(host: Node) -> void:
	host.in_dungeon = true
	host.interact_prompt = ""
	host.get_tree().paused = false
	if host.playtest == null or not bool(host.playtest.get("live_running")):
		Engine.time_scale = 1.0
	if host.music and host.music.has_method("play_dungeon") and str(host.music.get("kind")) != "dungeon":
		host.music.play_dungeon()
	host.get_tree().call_deferred("change_scene_to_file", host.DUNGEON_SCENE)
	host.call_deferred("wake_web_pad")


static func next_floor(host: Node) -> void:
	var p := host.get_tree().get_first_node_in_group("player")
	if p:
		host.run_hp = float(p.get("hp"))
	host.floor_n += 1
	host.prog.deepest = maxi(host.prog.deepest, host.floor_n)
	host.boss_dead = false
	host.interact_prompt = ""
	host.shrine_t = 0.0
	host.ui_open = false
	host.go_dungeon()


static func notify_boss_dead(host: Node) -> void:
	host.boss_dead = true
	var s := host.get_tree().current_scene
	if s and s.has_method("_on_boss_dead"):
		s._on_boss_dead()


static func end_run(host: Node, cond: String, killer := "") -> void:
	if host.recap and bool(host.recap.get("open")):
		return
	if not host.in_dungeon:
		host.toast("Already on the surface.")
		return
	if host.playtest and bool(host.playtest.get("live_running")):
		host.finish_end(cond, killer)
		return
	var p := host.get_tree().get_first_node_in_group("player")
	if p and p.has_method("play_exit") and not bool(p.get("exiting")):
		p.play_exit(cond, killer)
		return
	host.finish_end(cond, killer)


static func finish_end(host: Node, cond: String, killer := "") -> void:
	if host.recap and bool(host.recap.get("open")):
		return
	if cond == "dispel":
		host.sfx("thud")
	elif cond == "death":
		host.sfx("hurk")
	if host.tel:
		host.tel.note_end(cond, killer)
	host.get_tree().paused = false
	if host.recap and host.recap.has_method("play"):
		host.recap.play(cond)
	else:
		host.go_camp()


static func on_kill(host: Node) -> void:
	host.last_kill = host.clock
	host.kill_times.append(host.clock)
	while host.kill_times.size() > 0 and host.clock - host.kill_times[0] > host.bal.adrenaline_window:
		host.kill_times.remove_at(0)
	if host.adrenaline:
		host.adrenaline_xp += host.bal.adrenaline_xp_stack
	elif host.kill_times.size() >= int(host.bal.adrenaline_kills):
		start_adrenaline(host)
	var mult: float = host.adrenaline_xp if host.adrenaline else 1.0
	host.run_xp += host.bal.xp_per_kill * mult
	if host.prog:
		var half: float = host.bal.xp_per_kill * 0.5 * (mult if host.adrenaline else 1.0)
		if host.weapon == "staff":
			host.prog.add_run_xp("staff", half)
			host.prog.add_run_xp(host.last_style if host.last_style == "mag" else "str", half)
		elif host.weapon == "longbow":
			host.prog.add_run_xp("bow", half)
			host.prog.add_run_xp("rng", half)
		else:
			host.prog.add_run_xp("axe", half)
			host.prog.add_run_xp("str", half)
		host.prog.add_run_xp("hp", host.bal.xp_kill_hp * mult)
		host.prog.add_run_xp("def", host.bal.xp_kill_def * mult)
	if host.tel:
		host.tel.note_kill()


static func start_adrenaline(host: Node) -> void:
	host.adrenaline = true
	host.adrenaline_xp = 1.0 + host.bal.adrenaline_xp_stack
	if host.tel:
		host.tel.note_adrenaline()
	host.sfx("warcry")
	if host.sfx_node and host.sfx_node.has_method("set_adrenaline"):
		host.sfx_node.set_adrenaline(true)


static func end_adrenaline(host: Node) -> void:
	host.adrenaline = false
	host.adrenaline_xp = 1.0
	if host.sfx_node and host.sfx_node.has_method("set_adrenaline"):
		host.sfx_node.set_adrenaline(false)


static func spawn_floor_item(host: Node, it: Dictionary, pos := Vector3.INF) -> void:
	if it.is_empty():
		return
	var at := pos
	if not at.is_finite():
		var p := host.get_tree().get_first_node_in_group("player")
		if p is Node3D:
			at = (p as Node3D).global_position + Vector3(randf_range(-0.35, 0.35), 0.0, randf_range(-0.35, 0.35))
		else:
			at = Vector3.ZERO
	var PickupS := load("res://scripts/world/pickup.gd")
	PickupS.drop_item(it, at)


static func tick(host: Node, delta: float) -> void:
	host.Pad.tick()
	if host.pad_just("interact"):
		var f := host.get_viewport().gui_get_focus_owner()
		if f is BaseButton and not (f as BaseButton).disabled:
			(f as BaseButton).pressed.emit()
	host.clock += delta
	if host.shrine_t > 0.0:
		host.shrine_t = maxf(0.0, host.shrine_t - delta)
	if host.toast_t > 0.0:
		host.toast_t = maxf(0.0, host.toast_t - delta)
	if host.tel and host.in_dungeon:
		var fighting := false
		var p := host.get_tree().get_first_node_in_group("player")
		if p:
			fighting = int(p.get("atk_state")) != 0 or p.get("lock_target") != null
			if not fighting:
				for e in host.get_tree().get_nodes_in_group("enemies"):
					if e != null and is_instance_valid(e) and int(e.get("state")) >= 1 and int(e.get("state")) <= 6:
						fighting = true
						break
		host.tel.tick(delta, fighting)
	if host.prog:
		host.prog.tick_food(delta)
	if host.adrenaline and host.clock - host.last_kill > host.bal.adrenaline_timeout:
		end_adrenaline(host)
	debug_sequence(host, delta)


static func debug_sequence(host: Node, delta: float) -> void:
	var down := shoulders_down()
	var up := shoulders_up()
	if host._seq == 2 or host._seq == 3:
		host._seq_timer -= delta
		if host._seq_timer <= 0.0:
			host._seq = 0
	if host._seq == 0 and down:
		host._seq = 1
		host._seq_down = true
	elif host._seq == 1 and up:
		host._seq = 2
		host._seq_timer = 1.5
	elif host._seq == 2 and down:
		host._seq = 3
		host._seq_timer = 1.5
	elif host._seq == 3 and up:
		host._seq = 0
		if host.debug and host.debug.has_method("toggle"):
			host.debug.toggle()


static func shoulders_down() -> bool:
	var pads := Input.get_connected_joypads()
	if pads.is_empty():
		return false
	var d: int = pads[0]
	return (
		Input.get_joy_axis(d, JOY_AXIS_TRIGGER_LEFT) > 0.55
		and Input.get_joy_axis(d, JOY_AXIS_TRIGGER_RIGHT) > 0.55
		and Input.is_joy_button_pressed(d, JOY_BUTTON_LEFT_SHOULDER)
		and Input.is_joy_button_pressed(d, JOY_BUTTON_RIGHT_SHOULDER)
	)


static func shoulders_up() -> bool:
	var pads := Input.get_connected_joypads()
	if pads.is_empty():
		return true
	var d: int = pads[0]
	return (
		Input.get_joy_axis(d, JOY_AXIS_TRIGGER_LEFT) < 0.25
		and Input.get_joy_axis(d, JOY_AXIS_TRIGGER_RIGHT) < 0.25
		and not Input.is_joy_button_pressed(d, JOY_BUTTON_LEFT_SHOULDER)
		and not Input.is_joy_button_pressed(d, JOY_BUTTON_RIGHT_SHOULDER)
	)
