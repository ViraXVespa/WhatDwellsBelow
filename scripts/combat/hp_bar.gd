extends Node3D

const SHOW_SEC := 2.6
const WIDTH := 64
const HEIGHT := 8
const PIXEL := 0.014

var _spr: Sprite3D
var _fill_w := WIDTH - 4
var _left := 2
var _t := 0.0

static func pulse(host: Node3D, hp: float, max_hp: float) -> void:
	if host == null or not is_instance_valid(host):
		return
	var bar: Node = host.get_node_or_null("HpBar")
	if bar == null:
		bar = (load("res://scripts/combat/hp_bar.gd") as GDScript).new()
		bar.name = "HpBar"
		host.add_child(bar)
	if bar.has_method("show_hp"):
		bar.show_hp(hp, max_hp)

func _ready() -> void:
	_spr = Sprite3D.new()
	_spr.centered = true
	_spr.shaded = false
	_spr.double_sided = true
	_spr.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_spr.no_depth_test = true
	_spr.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	_spr.pixel_size = PIXEL
	_spr.position = Vector3(0.0, _lift(), 0.0)
	_spr.visible = false
	add_child(_spr)

func show_hp(hp: float, max_hp: float) -> void:
	_t = SHOW_SEC
	if hp <= 0.0:
		_t = 0.0
		if _spr:
			_spr.visible = false
		return
	_spr.position.y = _lift()
	_spr.texture = _paint(hp, max_hp)
	_spr.visible = true

func _process(delta: float) -> void:
	if _t <= 0.0:
		return
	_t -= delta
	if _t <= 0.0:
		if _spr:
			_spr.visible = false
		return
	if _t < 0.35 and _spr:
		_spr.modulate.a = clampf(_t / 0.35, 0.0, 1.0)
	elif _spr:
		_spr.modulate.a = 1.0

func _lift() -> float:
	var host := get_parent()
	if host != null and bool(host.get("is_boss")):
		return 2.05
	return 1.52

func _paint(hp: float, max_hp: float) -> ImageTexture:
	var frac := 0.0 if max_hp <= 0.0 else clampf(hp / max_hp, 0.0, 1.0)
	var img := Image.create(WIDTH, HEIGHT, false, Image.FORMAT_RGBA8)
	img.fill(Color(0.06, 0.04, 0.03, 0.92))
	var border := Color(0.18, 0.12, 0.08, 1.0)
	for x in WIDTH:
		img.set_pixel(x, 0, border)
		img.set_pixel(x, HEIGHT - 1, border)
	for y in HEIGHT:
		img.set_pixel(0, y, border)
		img.set_pixel(WIDTH - 1, y, border)
	var col := Color(0.34, 0.82, 0.30, 1.0)
	if frac <= 0.28:
		col = Color(0.88, 0.22, 0.18, 1.0)
	elif frac <= 0.55:
		col = Color(0.92, 0.74, 0.20, 1.0)
	var inner := maxi(0, int(round(float(_fill_w) * frac)))
	for y in range(2, HEIGHT - 2):
		for x in range(_left, _left + inner):
			img.set_pixel(x, y, col)
	return ImageTexture.create_from_image(img)