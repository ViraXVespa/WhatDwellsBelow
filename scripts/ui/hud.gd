extends CanvasLayer

## Dungeon gauntlet cluster (top-left) + minimap (top-right).
## Custom ColorRects, no default ProgressBar.

const Prompts := preload("res://scripts/input/prompts.gd")
const PromptView := preload("res://scripts/ui/prompt_view.gd")

const STRIP_W := 540.0
const STRIP_H := 196.0
const MINI_W := 350.0
const MINI_H := 250.0
const MARGIN := 24.0

var strip: Control
var portrait: TextureRect
var hp_fill: ColorRect
var hp_lab: Label
var pot_icon: TextureRect
var pot_fill: ColorRect
var pot_lab: Label
var dash_fill: ColorRect
var spec_fill: ColorRect
var lvl: Label
var res: Label
var floor_lab: Label
var shrine_icon: TextureRect
var shrine_lab: Label
var food_icon: TextureRect
var food_lab: Label
var boss_wrap: Control
var boss_fill: ColorRect
var boss_lab: Label
var prompt_row: HBoxContainer
var toast: Label
var mini_wrap: Control
var mini: TextureRect
var fps_lab: Label
var portrait_path := ""
var _prompt_shown := ""
var _prompt_scheme := ""


func _ready() -> void:
	layer = 20
	strip = Control.new()
	add_child(strip)
	var bg := ColorRect.new()
	bg.color = Color(0.08, 0.06, 0.05, 0.88)
	bg.size = Vector2(STRIP_W, STRIP_H)
	strip.add_child(bg)
	var edge := ColorRect.new()
	edge.color = Color(0.55, 0.42, 0.22, 1)
	edge.size = Vector2(STRIP_W, 5)
	strip.add_child(edge)
	portrait = TextureRect.new()
	portrait.position = Vector2(10, 14)
	portrait.size = Vector2(90, 90)
	portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	portrait.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	strip.add_child(portrait)
	hp_fill = _meter(strip, Vector2(112, 18), Vector2(280, 22), Color(0.72, 0.18, 0.16))
	hp_lab = _lab(strip, Vector2(112, 16), Vector2(280, 26), 18)
	pot_icon = TextureRect.new()
	pot_icon.position = Vector2(112, 44)
	pot_icon.size = Vector2(22, 22)
	pot_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	pot_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	pot_icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	if ResourceLoader.exists("res://assets/ui/icon_potion.png"):
		pot_icon.texture = load("res://assets/ui/icon_potion.png")
	strip.add_child(pot_icon)
	pot_fill = _meter(strip, Vector2(136, 48), Vector2(120, 16), Color(0.45, 0.2, 0.7))
	pot_lab = _lab(strip, Vector2(136, 44), Vector2(160, 22), 14)
	dash_fill = _meter(strip, Vector2(280, 48), Vector2(112, 16), Color(0.3, 0.7, 0.85))
	spec_fill = _meter(strip, Vector2(400, 48), Vector2(112, 16), Color(0.9, 0.55, 0.2))
	_lab(strip, Vector2(280, 64), Vector2(112, 18), 13).text = "Dash"
	_lab(strip, Vector2(400, 64), Vector2(112, 18), 13).text = "Special"
	lvl = _lab(strip, Vector2(112, 86), Vector2(280, 28), 22)
	floor_lab = _lab(strip, Vector2(400, 86), Vector2(120, 28), 28)
	res = _lab(strip, Vector2(112, 114), Vector2(410, 24), 18)
	shrine_icon = TextureRect.new()
	shrine_icon.position = Vector2(10, 140)
	shrine_icon.size = Vector2(28, 28)
	shrine_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	shrine_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	shrine_icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	if ResourceLoader.exists("res://assets/sprites/props/shrine.png"):
		shrine_icon.texture = load("res://assets/sprites/props/shrine.png")
	shrine_icon.visible = false
	strip.add_child(shrine_icon)
	shrine_lab = _lab(strip, Vector2(42, 142), Vector2(220, 28), 18)
	shrine_lab.add_theme_color_override("font_color", Color(1.0, 0.72, 0.35))
	food_icon = TextureRect.new()
	food_icon.position = Vector2(270, 140)
	food_icon.size = Vector2(28, 28)
	food_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	food_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	food_icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	if ResourceLoader.exists("res://assets/sprites/props/hp_orb.png"):
		food_icon.texture = load("res://assets/sprites/props/hp_orb.png")
	food_icon.visible = false
	strip.add_child(food_icon)
	food_lab = _lab(strip, Vector2(302, 142), Vector2(220, 28), 18)
	food_lab.add_theme_color_override("font_color", Color(0.7, 0.92, 0.5))
	prompt_row = HBoxContainer.new()
	prompt_row.position = Vector2(10, 168)
	prompt_row.size = Vector2(520, 24)
	prompt_row.add_theme_constant_override("separation", 8)
	prompt_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	strip.add_child(prompt_row)
	toast = _lab(self, Vector2(24, 16 + STRIP_H + 8), Vector2(540, 28), 20)
	toast.add_theme_color_override("font_color", Color(1.0, 0.88, 0.45))
	boss_wrap = Control.new()
	boss_wrap.size = Vector2(520, 50)
	add_child(boss_wrap)
	boss_fill = _meter(boss_wrap, Vector2(0, 18), Vector2(360, 18), Color(0.75, 0.15, 0.2))
	boss_lab = _lab(boss_wrap, Vector2(0, 0), Vector2(360, 20), 16)
	mini_wrap = Control.new()
	add_child(mini_wrap)
	mini = TextureRect.new()
	mini.position = Vector2(0, 0)
	mini.size = Vector2(MINI_W, MINI_H)
	mini.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	mini.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	mini.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	mini_wrap.add_child(mini)
	fps_lab = _lab(self, Vector2(0, 0), Vector2(140, 28), 16)
	_layout()
	_load_portrait()


func _meter(host: Control, pos: Vector2, sz: Vector2, col: Color) -> ColorRect:
	var back := ColorRect.new()
	back.color = Color(0.12, 0.1, 0.09, 1)
	back.position = pos
	back.size = sz
	host.add_child(back)
	var fill := ColorRect.new()
	fill.color = col
	fill.position = pos
	fill.size = sz
	host.add_child(fill)
	return fill


func _lab(host: Node, pos: Vector2, sz: Vector2, fs: int) -> Label:
	var l := Label.new()
	l.position = pos
	l.size = sz
	l.add_theme_font_size_override("font_size", fs)
	l.add_theme_color_override("font_color", Color(0.92, 0.86, 0.72))
	l.add_theme_color_override("font_outline_color", Color(0.05, 0.03, 0.02))
	l.add_theme_constant_override("outline_size", 5)
	host.add_child(l)
	return l


func _layout() -> void:
	var sc: float = App.hud_scale
	var vp := get_viewport().get_visible_rect().size
	strip.scale = Vector2(sc, sc)
	strip.position = Vector2(MARGIN, 16)
	mini_wrap.scale = Vector2(sc, sc)
	mini_wrap.position = Vector2(vp.x - MARGIN - MINI_W * sc, 16)
	toast.scale = Vector2(sc, sc)
	toast.position = Vector2(MARGIN, 16 + STRIP_H * sc + 8)
	boss_wrap.scale = Vector2(sc, sc)
	boss_wrap.position = Vector2(MARGIN, toast.position.y + 32 * sc)
	fps_lab.position = Vector2(mini_wrap.position.x, mini_wrap.position.y + MINI_H * sc + 4)


func _load_portrait() -> void:
	var p := "res://assets/sprites/player/%s/idle_down.png" % App.character_type
	if p == portrait_path:
		return
	portrait_path = p
	if ResourceLoader.exists(p):
		portrait.texture = load(p)


func bind_map(tex: Texture2D) -> void:
	mini.texture = tex


func refresh(player: Node, dungeon: Node) -> void:
	_layout()
	_load_portrait()
	var hp := 1.0
	var maxh := 1.0
	var dash := 0.0
	var spec := 0.0
	if player:
		hp = float(player.get("hp"))
		maxh = maxf(1.0, float(player.get("max_hp")))
		var dcd := float(player.get("dash_cd"))
		dash = 1.0 - clampf(dcd / maxf(0.05, App.bal.dash_cooldown), 0.0, 1.0)
		var atk := int(player.get("atk_state"))
		if atk == 2 or atk == 3:
			spec = 0.0
		elif atk == 4:
			spec = clampf(float(player.get("atk_t")) / maxf(0.05, App.bal.special_recovery), 0.0, 1.0)
		else:
			spec = 1.0
	_fill(hp_fill, 280.0, hp / maxh)
	hp_lab.text = "%d / %d" % [int(hp), int(maxh)]
	var pot: Dictionary = App.prog.slots.get("potion", {})
	var pn := int(pot.get("stack", 0))
	var pcd: float = App.prog.potion_cd
	var pmax: float = maxf(0.05, App.bal.potion_cooldown)
	_fill(pot_fill, 120.0, 1.0 if pcd <= 0.0 and pn > 0 else 1.0 - clampf(pcd / pmax, 0.0, 1.0))
	if pcd > 0.0:
		pot_lab.text = "Potion x%d  %.1fs" % [pn, pcd]
	else:
		pot_lab.text = "Potion x%d" % pn
	_fill(dash_fill, 112.0, dash)
	_fill(spec_fill, 112.0, spec)
	var clv := App.prog.combat_lv()
	var slv := App.prog.style_lv()
	if slv < clv:
		lvl.text = "Level %d (%s %d)" % [clv, _style_name(), slv]
	else:
		lvl.text = "Level %d" % clv
	res.text = "%dg   %d ore   %d wood" % [App.gold, App.ore, App.wood]
	floor_lab.text = "F%d" % App.floor_n
	if App.shrine_t > 0.0:
		shrine_icon.visible = true
		shrine_lab.visible = true
		shrine_lab.text = "Shrine +%d%%  %ds" % [int(App.bal.shrine_dmg * 100.0), int(ceil(App.shrine_t))]
	else:
		shrine_icon.visible = false
		shrine_lab.visible = false
	if App.prog.food_t > 0.0:
		food_icon.visible = true
		food_lab.visible = true
		food_lab.text = "Food HoT  %ds" % int(ceil(App.prog.food_t))
	else:
		food_icon.visible = false
		food_lab.visible = false
	_paint_prompt()
	toast.text = App.toast_msg if App.toast_t > 0.0 else ""
	_boss(dungeon, player)
	if fps_lab:
		fps_lab.text = ""


func _paint_prompt() -> void:
	var text := str(App.interact_prompt)
	var scheme: String = Prompts.scheme() if false else ""
	var Prompts = load("res://scripts/input/prompts.gd")
	scheme = Prompts.scheme()
	if text == _prompt_shown and scheme == _prompt_scheme:
		return
	_prompt_shown = text
	_prompt_scheme = scheme
	if text == "":
		PromptView.fill(prompt_row, [])
		return
	var locked := text.begins_with("Locked") or text.begins_with("Already") or text.begins_with("The fire") or text.begins_with("Spent") or text.begins_with("Empty")
	if locked:
		PromptView.fill(prompt_row, [{"text": text}], 16, Color(0.95, 0.82, 0.4))
	else:
		PromptView.fill(prompt_row, [{"action": "interact", "verb": text}], 16, Color(0.95, 0.82, 0.4))


func _style_name() -> String:
	if App.weapon == "staff":
		return "Magic"
	if App.weapon == "longbow":
		return "Ranged"
	return "Melee"


func _fill(r: ColorRect, w: float, t: float) -> void:
	r.size.x = w * clampf(t, 0.0, 1.0)


func _boss(dungeon: Node, player: Node) -> void:
	var b: Node = null
	if dungeon:
		var arr := dungeon.get_tree().get_nodes_in_group("boss")
		if arr.size() > 0:
			b = arr[0]
	if b == null or not is_instance_valid(b) or (b.has_method("is_alive") and not b.is_alive()):
		boss_wrap.visible = false
		return
	var dist := 99.0
	if player and b is Node3D:
		dist = Vector2((b as Node3D).global_position.x - player.global_position.x, (b as Node3D).global_position.z - player.global_position.z).length()
	if dist > 14.0:
		boss_wrap.visible = false
		return
	boss_wrap.visible = true
	var bh := float(b.get("hp"))
	var bm := maxf(1.0, float(b.get("max_hp")))
	_fill(boss_fill, 360.0, bh / bm)
	var title := "Guardian"
	if b.get("tag") != null and str(b.tag.text) != "":
		title = str(b.tag.text)
	boss_lab.text = "%s  %d / %d" % [title, int(bh), int(bm)]
