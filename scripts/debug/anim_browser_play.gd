extends Object

## Clip playback, UI build, process tick, and input for Animation Browser.

const ThemeS := preload("res://scripts/ui/theme.gd")
const T := preload("res://scripts/data/tunables.gd")
const AnimScan := preload("res://scripts/debug/anim_scan.gd")
const Review := preload("res://scripts/debug/anim_browser_review.gd")
const Nav := preload("res://scripts/debug/anim_browser_nav.gd")

const SPEEDS: Array[float] = [0.25, 0.5, 1.0, 1.5, 2.0]


static func build(host: CanvasLayer) -> void:
	var dim := ColorRect.new()
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.color = Color(0.03, 0.03, 0.04, 0.94)
	host.add_child(dim)
	var prev := ThemeS.btn("Previous (LB)", func(): host._shift_model(-1))
	prev.position = Vector2(48, 28)
	prev.size = Vector2(360, 56)
	host.add_child(prev)
	host.name_lab = ThemeS.lab("Model", 32, Color(0.95, 0.86, 0.55))
	host.name_lab.position = Vector2(440, 32)
	host.name_lab.size = Vector2(720, 52)
	host.name_lab.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	host.add_child(host.name_lab)
	var nxt := ThemeS.btn("Next (RB)", func(): host._shift_model(1))
	nxt.position = Vector2(1510, 28)
	nxt.size = Vector2(360, 56)
	host.add_child(nxt)
	var well := ColorRect.new()
	well.color = Color(0.08, 0.07, 0.06, 1)
	well.position = Vector2(48, 110)
	well.size = Vector2(900, 720)
	host.add_child(well)
	var edge := ColorRect.new()
	edge.color = Color(0.55, 0.42, 0.22, 1)
	edge.position = Vector2(48, 110)
	edge.size = Vector2(900, 6)
	host.add_child(edge)
	host.preview = TextureRect.new()
	host.preview.position = Vector2(98, 150)
	host.preview.size = Vector2(800, 620)
	host.preview.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	host.preview.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	host.preview.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	host.add_child(host.preview)
	host.empty_lab = ThemeS.lab("No clips for this facing.", 24, Color(0.85, 0.7, 0.55))
	host.empty_lab.position = Vector2(120, 430)
	host.empty_lab.size = Vector2(760, 80)
	host.empty_lab.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	host.empty_lab.visible = false
	host.add_child(host.empty_lab)
	host.play_btn = ThemeS.btn("Playing 1.0x - X to pause", func(): host._toggle_play())
	host.play_btn.position = Vector2(48, 850)
	host.play_btn.size = Vector2(900, 56)
	host.add_child(host.play_btn)
	var dlab := ThemeS.lab("Facing", 22, Color(0.92, 0.82, 0.5))
	dlab.position = Vector2(980, 110)
	dlab.size = Vector2(420, 36)
	host.add_child(dlab)
	host.dir_box = VBoxContainer.new()
	host.dir_box.position = Vector2(980, 150)
	host.dir_box.size = Vector2(420, 700)
	host.dir_box.add_theme_constant_override("separation", 4)
	host.add_child(host.dir_box)
	var alab := ThemeS.lab("Animation (LT / RT)", 22, Color(0.92, 0.82, 0.5))
	alab.position = Vector2(1420, 110)
	alab.size = Vector2(460, 36)
	host.add_child(alab)
	host.anim_box = VBoxContainer.new()
	host.anim_box.position = Vector2(1420, 150)
	host.anim_box.size = Vector2(460, 700)
	host.anim_box.add_theme_constant_override("separation", 4)
	host.add_child(host.anim_box)
	Review.build(host)
	host.back_btn = ThemeS.btn("Back (B)", func(): host.close_browser())
	host.back_btn.position = Vector2(48, 980)
	host.back_btn.size = Vector2(1824, 60)
	host.add_child(host.back_btn)


static func toggle_play(host: CanvasLayer) -> void:
	host.playing = not host.playing
	refresh_play(host)


static func refresh_play(host: CanvasLayer) -> void:
	if host.playing:
		host.play_btn.text = "Playing %.2fx - X to pause" % host.play_speed
		host.play_btn.add_theme_color_override("font_color", Color(0.85, 1.0, 0.7))
	else:
		host.play_btn.text = "Paused %.2fx - X to play" % host.play_speed
		host.play_btn.add_theme_color_override("font_color", Color(1.0, 0.82, 0.45))


static func frames(host: CanvasLayer) -> Array:
	if not host.clips.has(host.facing):
		return []
	var d: Dictionary = host.clips[host.facing]
	if not d.has(host.anim_name):
		return []
	return d[host.anim_name]


static func show_clip(host: CanvasLayer) -> void:
	var fr := frames(host)
	host.empty_lab.visible = fr.is_empty()
	host.preview.visible = not fr.is_empty()
	if fr.is_empty():
		host.preview.texture = null
		Review.refresh(host)
		return
	host.frame_i = clampi(host.frame_i, 0, fr.size() - 1)
	if host.preview:
		host.preview.texture = fr[host.frame_i]
	refresh_play(host)
	Review.refresh(host)


static func nudge_speed(host: CanvasLayer, delta_i: int) -> void:
	var idx: int = 2
	var best: float = absf(host.play_speed - SPEEDS[2])
	for i in SPEEDS.size():
		var dist: float = absf(host.play_speed - SPEEDS[i])
		if dist < best:
			best = dist
			idx = i
	idx = clampi(idx + delta_i, 0, SPEEDS.size() - 1)
	host.play_speed = SPEEDS[idx]
	refresh_play(host)


static func step_frame(host: CanvasLayer, delta_i: int) -> void:
	var fr: Array = frames(host)
	if fr.size() <= 1:
		return
	host.frame_i = (host.frame_i + delta_i + fr.size()) % fr.size()
	host.frame_t = 0.0
	if host.preview:
		host.preview.texture = fr[host.frame_i]


static func stick_play(host: CanvasLayer) -> void:
	var v := Input.get_vector("move_left", "move_right", "move_up", "move_down")
	if v.length() < 0.55:
		return
	var delta_i: int = 0
	if absf(v.y) >= absf(v.x):
		delta_i = -1 if v.y < 0.0 else 1
	else:
		delta_i = -1 if v.x < 0.0 else 1
	if host.playing:
		nudge_speed(host, delta_i)
	else:
		step_frame(host, delta_i)
	host.stick_cool = 0.18


static func tick(host: CanvasLayer, delta: float) -> void:
	if not host.open:
		return
	Nav.stick_facing(host)
	host.stick_cool = maxf(0.0, host.stick_cool - delta)
	if host.stick_cool <= 0.0:
		stick_play(host)
	if not host.playing:
		return
	var fr := frames(host)
	if fr.size() <= 1:
		return
	host.frame_t += delta * host.play_speed
	var fps := T.WALK_FPS
	if host.anim_name.begins_with("attack") or host.anim_name.begins_with("special"):
		fps = App.bal.atk_fps
	if host.frame_t >= 1.0 / maxf(1.0, fps):
		host.frame_t = 0.0
		host.frame_i = (host.frame_i + 1) % fr.size()
		if host.preview:
			host.preview.texture = fr[host.frame_i]


static func pad_list_event(event: InputEvent) -> bool:
	if event is InputEventMouse:
		return false
	return event is InputEventJoypadButton or event is InputEventJoypadMotion


static func handle_input(host: CanvasLayer, event: InputEvent) -> void:
	if not host.open:
		return
	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_RIGHT:
			host.get_viewport().set_input_as_handled()
			return
		if mb.pressed and mb.button_index == MOUSE_BUTTON_WHEEL_UP:
			Nav.scroll_anim(host, -1)
			host.get_viewport().set_input_as_handled()
		elif mb.pressed and mb.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			Nav.scroll_anim(host, 1)
			host.get_viewport().set_input_as_handled()
		return
	if event is InputEventJoypadMotion:
		var axis: int = (event as InputEventJoypadMotion).axis
		if axis == JOY_AXIS_LEFT_X or axis == JOY_AXIS_LEFT_Y or axis == JOY_AXIS_RIGHT_X or axis == JOY_AXIS_RIGHT_Y:
			host.get_viewport().set_input_as_handled()
			return
	if event.is_action_pressed("ui_cancel") or event.is_action_pressed("pause") or event.is_action_pressed("anim_back"):
		host.close_browser()
		host.get_viewport().set_input_as_handled()
		return
	if Nav.ui_nav(host, event):
		host.get_viewport().set_input_as_handled()
		return
	if Review.handle_tip(host, event):
		host.get_viewport().set_input_as_handled()
		return
	if event.is_action_pressed("tab_left") or event.is_action_pressed("anim_model_prev"):
		host._shift_model(-1)
		host.get_viewport().set_input_as_handled()
	elif event.is_action_pressed("tab_right") or event.is_action_pressed("anim_model_next"):
		host._shift_model(1)
		host.get_viewport().set_input_as_handled()
	elif event.is_action_pressed("target_lock") or event.is_action_pressed("anim_idle"):
		Nav.set_facing(host, "down")
		host.get_viewport().set_input_as_handled()
	elif pad_list_event(event) and (event.is_action_pressed("special") or event.is_action_pressed("anim_list_up")):
		Nav.scroll_anim(host, -1)
		host.get_viewport().set_input_as_handled()
	elif pad_list_event(event) and (event.is_action_pressed("attack") or event.is_action_pressed("anim_list_down")):
		Nav.scroll_anim(host, 1)
		host.get_viewport().set_input_as_handled()
	elif event.is_action_pressed("anim_play") or event.is_action_pressed("gear_drop"):
		toggle_play(host)
		host.get_viewport().set_input_as_handled()
