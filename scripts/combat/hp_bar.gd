extends Node3D

const SHOW_SEC := 2.6
const WIDTH := 64
const HEIGHT := 8
const PIXEL := 0.014

var _spr: Sprite3D
var _lv: Label3D
var _fill_w := WIDTH - 4
var _left := 2
var _t := 0.0
var _combat_lv := 0


static func pulse(host: Node3D, hp: float, max_hp: float, combat_lv: int = -1) -> void:
	if host == null or not is_instance_valid(host):
		return
	var bar: Node = host.get_node_or_null("HpBar")
	if bar == null:
		bar = (load("res://scripts/combat/hp_bar.gd") as GDScript).new()
		bar.name = "HpBar"
		host.add_child(bar)
	var lv := combat_lv
	if lv < 0:
		var raw: Variant = host.get("combat_lv")
		lv = int(raw) if raw != null else 0
	if bar.has_method("show_hp"):
		bar.show_hp(hp, max_hp, lv)


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
	_lv = Label3D.new()
	_lv.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_lv.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_lv.font_size = 22
	_lv.outline_size = 8
	_lv.outline_modulate = Color(0, 0, 0)
	_lv.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_lv.no_depth_test = true
	_lv.pixel_size = 0.010
	_lv.visible = false
	add_child(_lv)


func show_hp(hp: float, max_hp: float, combat_lv: int = 0) -> void:
	_combat_lv = combat_lv
	_t = SHOW_SEC
	if hp <= 0.0:
		_t = 0.0
		_hide()
		return
	_spr.position.y = _lift()
	_spr.texture = _paint(hp, max_hp)
	_spr.visible = true
	_spr.modulate.a = 1.0
	_place_lv(1.0)


func _process(delta: float) -> void:
	if _t <= 0.0:
		return
	_t -= delta
	if _t <= 0.0:
		_hide()
		return
	var a := 1.0
	if _t < 0.35:
		a = clampf(_t / 0.35, 0.0, 1.0)
	if _spr:
		_spr.modulate.a = a
	_place_lv(a)


func _hide() -> void:
	if _spr:
		_spr.visible = false
	if _lv:
		_lv.visible = false


func _place_lv(alpha: float) -> void:
	if _lv == null:
		return
	var y := _lift()
	var half := float(WIDTH) * PIXEL * 0.5
	_lv.position = Vector3(- (half + 0.10), y, 0.0)
	if _combat_lv <= 0:
		_lv.visible = false
		return
	_lv.text = "Lv %d" % _combat_lv
	var col := _lv_color()
	col.a = alpha
	_lv.modulate = col
	_lv.visible = _spr != null and _spr.visible


func _lv_color() -> Color:
	var ply := 1
	if App.prog:
		ply = int(App.prog.combat_lv())
	var d := _combat_lv - ply
	if d >= 8:
		return Color(0.92, 0.28, 0.22)
	if d >= 3:
		return Color(0.95, 0.62, 0.22)
	if d <= -8:
		return Color(0.55, 0.72, 0.48)
	if d <= -3:
		return Color(0.72, 0.82, 0.62)
	return Color(0.92, 0.86, 0.72)


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
