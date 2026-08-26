extends StaticBody3D

const SkillMath := preload("res://scripts/data/skills.gd")
const V3 := preload("res://scripts/view3d/v3.gd")

var kind := "sign"
var prompt := "Interact"
var tex_path := ""
var title := ""
var body := ""
var clerk_kind := "gather"
var clerk_id := "miner"
var spent_normal := false
var spent_gold := false
var locked := false
var remaining := 4
var used := false
var opened := false
var flipped := false
var lever_id := 0
var spr: Sprite3D
var rng := RandomNumberGenerator.new()
var _layer: CanvasLayer
var _built := false


func configure(p_kind: String, p_tex := "", extra: Dictionary = {}) -> void:
	kind = p_kind
	tex_path = p_tex
	title = str(extra.get("title", ""))
	body = str(extra.get("body", ""))
	clerk_kind = str(extra.get("clerk_kind", clerk_kind))
	clerk_id = str(extra.get("clerk_id", clerk_id))
	locked = bool(extra.get("locked", false))
	lever_id = int(extra.get("lever_id", 0))
	if title != "":
		prompt = title


func _ready() -> void:
	collision_layer = 1
	collision_mask = 0
	add_to_group("interactable")
	rng.randomize()
	_build()


func _build() -> void:
	if _built:
		return
	_built = true
	_build_kind()


func _build_kind() -> void:
	prompt = "Interact"
	V3.add_cyl(self, 0.2, 0.5, Vector3(0, 0.25, 0))


func interact(_player: Node) -> void:
	pass


func get_prompt() -> String:
	return prompt


func _spr_from(path: String, h: float, billboard: bool, fallback: Texture2D = null) -> void:
	var tex := Art.load_tex(path) if path != "" else fallback
	if tex == null:
		tex = fallback if fallback else Art.solid(Vector2i(40, 48), Color(0.55, 0.45, 0.3))
	spr = V3.sprite(tex, h, billboard)
	add_child(spr)
	V3.depth_sort(spr, global_position)


func _close_layer() -> void:
	get_tree().paused = false
	if _layer:
		_layer.queue_free()
		_layer = null


func _unhandled_input(event: InputEvent) -> void:
	if _layer == null:
		return
	if event.is_action_pressed("ui_cancel") or event.is_action_pressed("pause"):
		_close_layer()
		get_viewport().set_input_as_handled()


func _btn(text: String, cb: Callable) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(0, 48)
	b.pressed.connect(cb)
	return b


func _long_toast(text: String) -> void:
	for c in get_tree().root.get_children():
		if c.name == "ToastLayer":
			c.queue_free()
	var layer := CanvasLayer.new()
	layer.name = "ToastLayer"
	layer.layer = 80
	var lab := Label.new()
	lab.text = text
	lab.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	lab.position = Vector2(480, 80)
	lab.size = Vector2(960, 100)
	lab.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lab.add_theme_font_size_override("font_size", 22)
	lab.add_theme_color_override("font_color", Color(0.95, 0.9, 0.75))
	lab.add_theme_color_override("font_outline_color", Color(0.05, 0.05, 0.08))
	lab.add_theme_constant_override("outline_size", 6)
	layer.add_child(lab)
	get_tree().root.add_child(layer)
	get_tree().create_timer(3.6).timeout.connect(layer.queue_free)
