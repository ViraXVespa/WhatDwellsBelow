extends CanvasLayer

## Full Animation Browser. Secret debug page, gamepad-first.

const Facing := preload("res://scripts/world/facing.gd")
const ThemeS := preload("res://scripts/ui/theme.gd")
const T := preload("res://scripts/data/tunables.gd")
const AnimScan := preload("res://scripts/debug/anim_scan.gd")

const DIR_ORDER := ["idle_none", "up", "up_right", "right", "down_right", "down", "down_left", "left", "up_left"]
const DIR_LABEL := {
	"idle_none": "Idle / None",
	"up": "Up",
	"up_right": "Up-Right",
	"right": "Right",
	"down_right": "Down-Right",
	"down": "Down",
	"down_left": "Down-Left",
	"left": "Left",
	"up_left": "Up-Left",
}

var open := false
var models: Array = []
var model_i := 0
var facing := "down"
var anim_name := ""
var playing := true
var frame_i := 0
var frame_t := 0.0
var clips: Dictionary = {}
var dir_btns: Dictionary = {}
var anim_btns: Array = []
var anim_scroll := 0
var name_lab: Label
var play_btn: Button
var preview: TextureRect
var empty_lab: Label
var back_btn: Button
var dir_box: VBoxContainer
var anim_box: VBoxContainer
var focus_kind := "back"


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
	var prev := ThemeS.btn("◀  Previous  (LB)", func(): _shift_model(-1))
	prev.position = Vector2(48, 28)
	prev.size = Vector2(360, 56)
	add_child(prev)
	name_lab = ThemeS.lab("Model", 32, Color(0.95, 0.86, 0.55))
	name_lab.position = Vector2(440, 32)
	name_lab.size = Vector2(720, 52)
	name_lab.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(name_lab)
	var nxt := ThemeS.btn("Next  (RB)  ▶", func(): _shift_model(1))
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
	play_btn = ThemeS.btn("Playing — A to pause", func(): _toggle_play())
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
	var alab := ThemeS.lab("Animation  (LT / RT)", 22, Color(0.92, 0.82, 0.5))
	alab.position = Vector2(1420, 110)
	alab.size = Vector2(460, 36)
	add_child(alab)
	anim_box = VBoxContainer.new()
	anim_box.position = Vector2(1420, 150)
	anim_box.size = Vector2(460, 700)
	anim_box.add_theme_constant_override("separation", 4)
	add_child(anim_box)
	back_btn = ThemeS.btn("Back  (B)", func(): close_browser())
	back_btn.position = Vector2(48, 980)
	back_btn.size = Vector2(1824, 60)
	add_child(back_btn)


func open_browser() -> void:
	open = true
	visible = true
	App.ui_open = true
	if models.is_empty():
		models = catalog_models()
	_load_model()
	call_deferred("_focus_back")


func close_browser() -> void:
	open = false
	visible = false
	if App.debug and bool(App.debug.get("open")):
		App.ui_open = true
		if App.debug.has_method("_focus"):
			App.debug._focus()
	else:
		App.ui_open = false


func _focus_back() -> void:
	if back_btn:
		back_btn.grab_focus()


func _shift_model(d: int) -> void:
	if models.is_empty():
		return
	model_i = (model_i + d + models.size()) % models.size()
	_load_model()


func _load_model() -> void:
	var m: Dictionary = models[model_i]
	name_lab.text = str(m.label)
	clips = AnimScan.scan(str(m.dir))
	if not clips.has(facing) or (clips[facing] as Dictionary).is_empty():
		if clips.has("down") and not (clips["down"] as Dictionary).is_empty():
			facing = "down"
		elif clips.has("idle_none") and not (clips["idle_none"] as Dictionary).is_empty():
			facing = "idle_none"
	_rebuild_dirs()
	_rebuild_anims()
	_show_clip()


func _rebuild_dirs() -> void:
	for c in dir_box.get_children():
		c.queue_free()
	dir_btns.clear()
	for k in DIR_ORDER:
		var key: String = str(k)
		var n: int = 0
		if clips.has(key):
			n = (clips[key] as Dictionary).size()
		var cap := "%s%s" % [str(DIR_LABEL.get(key, key)), "" if n > 0 else "  (empty)"]
		var kk: String = key
		var b := ThemeS.btn(cap, func(): _set_facing(kk))
		if k == facing:
			b.add_theme_color_override("font_color", Color(1, 0.92, 0.45))
		dir_box.add_child(b)
		dir_btns[k] = b


func _rebuild_anims() -> void:
	for c in anim_box.get_children():
		c.queue_free()
	anim_btns.clear()
	var names := _anim_names()
	if anim_name == "" or names.find(anim_name) < 0:
		anim_name = names[0] if names.size() > 0 else ""
	if names.is_empty():
		anim_box.add_child(ThemeS.lab("No animations for this facing.", 18, Color(0.8, 0.7, 0.6)))
		return
	anim_scroll = clampi(anim_scroll, 0, maxi(0, names.size() - 1))
	var shown := 12
	var start := clampi(anim_scroll, 0, maxi(0, names.size() - shown))
	for i in range(start, mini(names.size(), start + shown)):
		var nm: String = names[i]
		var b := ThemeS.btn(nm.replace("_", " "), func(): _set_anim(nm))
		if nm == anim_name:
			b.add_theme_color_override("font_color", Color(1, 0.92, 0.45))
		anim_box.add_child(b)
		anim_btns.append(b)


func _anim_names() -> PackedStringArray:
	var out := PackedStringArray()
	if not clips.has(facing):
		return out
	var d: Dictionary = clips[facing]
	for k in d.keys():
		out.append(str(k))
	out.sort()
	return out


func _set_facing(k: String) -> void:
	facing = k
	_rebuild_dirs()
	_rebuild_anims()
	_show_clip()


func _set_anim(n: String) -> void:
	anim_name = n
	frame_i = 0
	frame_t = 0.0
	_rebuild_anims()
	_show_clip()


func _toggle_play() -> void:
	playing = not playing
	_refresh_play()


func _refresh_play() -> void:
	if playing:
		play_btn.text = "Playing — A to pause"
		play_btn.add_theme_color_override("font_color", Color(0.85, 1.0, 0.7))
	else:
		play_btn.text = "Paused — A to play"
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
		return
	frame_i = clampi(frame_i, 0, fr.size() - 1)
	if preview:
		preview.texture = fr[frame_i]
	_refresh_play()


func _process(delta: float) -> void:
	if not open:
		return
	_stick_facing()
	if not playing:
		return
	var fr := _frames()
	if fr.size() <= 1:
		return
	frame_t += delta
	var fps := T.WALK_FPS
	if anim_name.begins_with("attack") or anim_name.begins_with("special"):
		fps = App.bal.atk_fps
	if frame_t >= 1.0 / maxf(1.0, fps):
		frame_t = 0.0
		frame_i = (frame_i + 1) % fr.size()
		if preview:
			preview.texture = fr[frame_i]


func _stick_facing() -> void:
	var v := Input.get_vector("aim_left", "aim_right", "aim_up", "aim_down")
	if v.length() < 0.55:
		v = Input.get_vector("move_left", "move_right", "move_up", "move_down")
	if v.length() < 0.55:
		return
	var k := Facing.from_aim(v)
	if k != facing:
		_set_facing(k)


func _unhandled_input(event: InputEvent) -> void:
	if not open:
		return
	if event.is_action_pressed("ui_cancel") or event.is_action_pressed("pause") or event.is_action_pressed("anim_back"):
		close_browser()
		get_viewport().set_input_as_handled()
		return
	if event.is_action_pressed("tab_left") or event.is_action_pressed("anim_model_prev"):
		_shift_model(-1)
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("tab_right") or event.is_action_pressed("anim_model_next"):
		_shift_model(1)
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("target_lock") or event.is_action_pressed("anim_idle"):
		_set_facing("idle_none")
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("special") or event.is_action_pressed("anim_list_up"):
		_scroll_anim(-1)
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("attack") or event.is_action_pressed("anim_list_down"):
		_scroll_anim(1)
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("anim_play"):
		_toggle_play()
		get_viewport().set_input_as_handled()
	elif event is InputEventMouseButton and (event as InputEventMouseButton).pressed:
		var mb := event as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_WHEEL_UP:
			_scroll_anim(-1)
			get_viewport().set_input_as_handled()
		elif mb.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			_scroll_anim(1)
			get_viewport().set_input_as_handled()


func _scroll_anim(d: int) -> void:
	var names := _anim_names()
	if names.is_empty():
		return
	var i := names.find(anim_name)
	if i < 0:
		i = 0
	i = (i + d + names.size()) % names.size()
	anim_scroll = i
	_set_anim(names[i])
