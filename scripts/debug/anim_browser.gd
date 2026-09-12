extends CanvasLayer

## Full Animation Browser. Secret debug page, gamepad-first.

const AnimScan := preload("res://scripts/debug/anim_scan.gd")
const Review := preload("res://scripts/debug/anim_browser_review.gd")
const Nav := preload("res://scripts/debug/anim_browser_nav.gd")
const Play := preload("res://scripts/debug/anim_browser_play.gd")

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
	Play.build(self)


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
	Play.toggle_play(self)


func _refresh_play() -> void:
	Play.refresh_play(self)


func _frames() -> Array:
	return Play.frames(self)


func _show_clip() -> void:
	Play.show_clip(self)


func _nudge_speed(delta_i: int) -> void:
	Play.nudge_speed(self, delta_i)


func _step_frame(delta_i: int) -> void:
	Play.step_frame(self, delta_i)


func _stick_play() -> void:
	Play.stick_play(self)


func _process(delta: float) -> void:
	Play.tick(self, delta)


func _pad_list_event(event: InputEvent) -> bool:
	return Play.pad_list_event(event)


func _input(event: InputEvent) -> void:
	Play.handle_input(self, event)
