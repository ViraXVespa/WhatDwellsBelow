extends CanvasLayer

## Full Animation Browser. Secret debug page, gamepad-first.

const ThemeS := preload("res://scripts/ui/theme.gd")
const T := preload("res://scripts/data/tunables.gd")
const AnimScan := preload("res://scripts/debug/anim_scan.gd")
const Review := preload("res://scripts/debug/anim_browser_review.gd")
const Nav := preload("res://scripts/debug/anim_browser_nav.gd")

const SPEEDS: Array[float] = [0.25, 0.5, 1.0, 1.5, 2.0]

var open := false
var models: Array = []
var model_i := 0
var facing := "down"
var anim_name := ""
var playing := true
var frame_i := 0
var frame_t := 0.0
var play_speed: float = 1.0
var stick_cool: float = 0.0
var clips: Dictionary = {}
var anim_scroll := 0
var nav_col: String = "dir"
var name_lab: Label
var play_btn: Button
var preview: TextureRect
var empty_lab: Label
var back_btn: Button
var dir_box: VBoxContainer
var anim_box: VBoxContainer
var review_btn: Button
var note_edit: LineEdit
var note_lock := false


func _ready() -> void:
	layer = 86
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false
	models = catalog_models()
	_build()


static func catalog_models() -> Array:
	return AnimScan.catalog_models()


static func model_count() -> int:
	return AnimScan.model_count()


func _build() -> void:
	var dim := ColorRect.new()
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.color = Color(0.03, 0.03, 0.04, 0.94)
	add_child(dim)
	var prev := ThemeS.btn("Previous (LB)", func(): _shift_model(-1))
	prev.position = Vector2(48, 28)
	prev.size = Vector2(360, 56)
	add_child(prev)
	name_lab = ThemeS.lab("Model", 32, Color(0.95, 0.86, 0.55))
	name_lab.position = Vector2(440, 32)
	name_lab.size = Vector2(720, 52)
	name_lab.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(name_lab)
	var nxt := ThemeS.btn("Next (RB)", func(): _shift_model(1))
	nxt.position = Vector2(1510, 28)
	nxt.size = Vector2(360, 56)
	add_child(nxt)
	var well := ColorRect.new()
	well.color = Color(0.08, 0.07, 0.06, 1)
	well.position = Vector2(48, 110)
	well.size = Vector2(900, 720)
	add_child(well)
	var edge := ColorRect.new()
	edge.color = Color(0.55, 0.42, 0.22, 1)
	edge.position = Vector2(48, 110)
	edge.size = Vector2(900, 6)
	add_child(edge)
	preview = TextureRect.new()
	preview.position = Vector2(98, 150)
	preview.size = Vector2(800, 620)
	preview.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	preview.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	preview.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	add_child(preview)
	empty_lab = ThemeS.lab("No clips for this facing.", 24, Color(0.85, 0.7, 0.55))
	empty_lab.position = Vector2(120, 430)
	empty_lab.size = Vector2(760, 80)
	empty_lab.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	empty_lab.visible = false
	add_child(empty_lab)
	play_btn = ThemeS.btn("Playing 1.0x - X to pause", func(): _toggle_play())
	play_btn.position = Vector2(48, 850)
	play_btn.size = Vector2(900, 56)
	add_child(play_btn)
	var dlab := ThemeS.lab("Facing", 22, Color(0.92, 0.82, 0.5))
	dlab.position = Vector2(980, 110)
	dlab.size = Vector2(420, 36)
	add_child(dlab)
	dir_box = VBoxContainer.new()
	dir_box.position = Vector2(980, 150)
	dir_box.size = Vector2(420, 700)
	dir_box.add_theme_constant_override("separation", 4)
	add_child(dir_box)
	var alab := ThemeS.lab("Animation (LT / RT)", 22, Color(0.92, 0.82, 0.5))
	alab.position = Vector2(1420, 110)
	alab.size = Vector2(460, 36)
	add_child(alab)
	anim_box = VBoxContainer.new()
	anim_box.position = Vector2(1420, 150)
	anim_box.size = Vector2(460, 700)
	anim_box.add_theme_constant_override("separation", 4)
	add_child(anim_box)
	Review.build(self)
	back_btn = ThemeS.btn("Back (B)", func(): close_browser())
	back_btn.position = Vector2(48, 980)
	back_btn.size = Vector2(1824, 60)
	add_child(back_btn)


func open_browser() -> void:
	open = true
	visible = true
	App.ui_open = true
	nav_col = "dir"
	if App.debug and App.debug.has_method("release_for_anim"):
		App.debug.release_for_anim()
	if models.is_empty():
		models = catalog_models()
	Review.open(self)
	_load_model()
	call_deferred("_focus_dir")


func close_browser() -> void:
	Review.close(self)
	open = false
	visible = false
	if App.debug and bool(App.debug.get("open")):
		App.ui_open = true
		if App.debug.has_method("restore_from_anim"):
			App.debug.restore_from_anim()
		elif App.debug.has_method("_focus"):
			App.debug._focus()
	else:
		App.ui_open = false


func _focus_dir() -> void:
	Nav.focus_dir(self)


func _focus_anim() -> void:
	Nav.focus_anim(self)


func _shift_model(d: int) -> void:
	if models.is_empty():
		return
	model_i = (model_i + d + models.size()) % models.size()
	_load_model()
	if nav_col == "anim":
		call_deferred("_focus_anim")
	else:
		call_deferred("_focus_dir")


func _load_model() -> void:
	var m: Dictionary = models[model_i]
	name_lab.text = str(m.label)
	clips = AnimScan.scan(str(m.dir))
	Nav.pick_facing(self)
	Nav.rebuild_dirs(self)
	Nav.rebuild_anims(self)
	_show_clip()


func _set_facing(k: String) -> void:
	Nav.set_facing(self, k)


func _set_anim(n: String) -> void:
	Nav.set_anim(self, n)


func _toggle_play() -> void:
	playing = not playing
	_refresh_play()


func _refresh_play() -> void:
	if playing:
		play_btn.text = "Playing %.2fx - X to pause" % play_speed
		play_btn.add_theme_color_override("font_color", Color(0.85, 1.0, 0.7))
	else:
		play_btn.text = "Paused %.2fx - X to play" % play_speed
		play_btn.add_theme_color_override("font_color", Color(1.0, 0.82, 0.45))


func _frames() -> Array:
	if not clips.has(facing):
		return []
	var d: Dictionary = clips[facing]
	if not d.has(anim_name):
		return []
	return d[anim_name]


func _show_clip() -> void:
	var fr := _frames()
	empty_lab.visible = fr.is_empty()
	preview.visible = not fr.is_empty()
	if fr.is_empty():
		preview.texture = null
		Review.refresh(self)
		return
	frame_i = clampi(frame_i, 0, fr.size() - 1)
	if preview:
		preview.texture = fr[frame_i]
	_refresh_play()
	Review.refresh(self)


func _nudge_speed(delta_i: int) -> void:
	var idx: int = 2
	var best: float = absf(play_speed - SPEEDS[2])
	for i in SPEEDS.size():
		var dist: float = absf(play_speed - SPEEDS[i])
		if dist < best:
			best = dist
			idx = i
	idx = clampi(idx + delta_i, 0, SPEEDS.size() - 1)
	play_speed = SPEEDS[idx]
	_refresh_play()


func _step_frame(delta_i: int) -> void:
	var fr: Array = _frames()
	if fr.size() <= 1:
		return
	frame_i = (frame_i + delta_i + fr.size()) % fr.size()
	frame_t = 0.0
	if preview:
		preview.texture = fr[frame_i]


func _stick_play() -> void:
	var v := Input.get_vector("move_left", "move_right", "move_up", "move_down")
	if v.length() < 0.55:
		return
	var delta_i: int = 0
	if absf(v.y) >= absf(v.x):
		delta_i = -1 if v.y < 0.0 else 1
	else:
		delta_i = -1 if v.x < 0.0 else 1
	if playing:
		_nudge_speed(delta_i)
	else:
		_step_frame(delta_i)
	stick_cool = 0.18


func _process(delta: float) -> void:
	if not open:
		return
	Nav.stick_facing(self)
	stick_cool = maxf(0.0, stick_cool - delta)
	if stick_cool <= 0.0:
		_stick_play()
	if not playing:
		return
	var fr := _frames()
	if fr.size() <= 1:
		return
	frame_t += delta * play_speed
	var fps := T.WALK_FPS
	if anim_name.begins_with("attack") or anim_name.begins_with("special"):
		fps = App.bal.atk_fps
	if frame_t >= 1.0 / maxf(1.0, fps):
		frame_t = 0.0
		frame_i = (frame_i + 1) % fr.size()
		if preview:
			preview.texture = fr[frame_i]


func _pad_list_event(event: InputEvent) -> bool:
	if event is InputEventMouse:
		return false
	return event is InputEventJoypadButton or event is InputEventJoypadMotion


func _input(event: InputEvent) -> void:
	if not open:
		return
	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_RIGHT:
			get_viewport().set_input_as_handled()
			return
		if mb.pressed and mb.button_index == MOUSE_BUTTON_WHEEL_UP:
			Nav.scroll_anim(self, -1)
			get_viewport().set_input_as_handled()
		elif mb.pressed and mb.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			Nav.scroll_anim(self, 1)
			get_viewport().set_input_as_handled()
		return
	if event is InputEventJoypadMotion:
		var axis: int = (event as InputEventJoypadMotion).axis
		if axis == JOY_AXIS_LEFT_X or axis == JOY_AXIS_LEFT_Y or axis == JOY_AXIS_RIGHT_X or axis == JOY_AXIS_RIGHT_Y:
			get_viewport().set_input_as_handled()
			return
	if event.is_action_pressed("ui_cancel") or event.is_action_pressed("pause") or event.is_action_pressed("anim_back"):
		close_browser()
		get_viewport().set_input_as_handled()
		return
	if Nav.ui_nav(self, event):
		get_viewport().set_input_as_handled()
		return
	if Review.handle_tip(self, event):
		get_viewport().set_input_as_handled()
		return
	if event.is_action_pressed("tab_left") or event.is_action_pressed("anim_model_prev"):
		_shift_model(-1)
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("tab_right") or event.is_action_pressed("anim_model_next"):
		_shift_model(1)
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("target_lock") or event.is_action_pressed("anim_idle"):
		Nav.set_facing(self, "down")
		get_viewport().set_input_as_handled()
	elif _pad_list_event(event) and (event.is_action_pressed("special") or event.is_action_pressed("anim_list_up")):
		Nav.scroll_anim(self, -1)
		get_viewport().set_input_as_handled()
	elif _pad_list_event(event) and (event.is_action_pressed("attack") or event.is_action_pressed("anim_list_down")):
		Nav.scroll_anim(self, 1)
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("anim_play") or event.is_action_pressed("gear_drop"):
		_toggle_play()
		get_viewport().set_input_as_handled()
