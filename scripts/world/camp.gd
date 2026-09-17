extends Node3D

const Build := preload("res://scripts/world/camp_build.gd")
const View := preload("res://scripts/world/camp_view.gd")
const LoadTiming := preload("res://scripts/debug/load_timing.gd")
const Warm := preload("res://scripts/world/camp_warm.gd")

var player: CharacterBody3D
var dummy: CharacterBody3D
var ui: CanvasLayer
var hint: Label
var prompt: Label


func _ready() -> void:
	App.in_dungeon = false
	LoadTiming.mark("camp_enter")
	Build.world(self)
	LoadTiming.mark("camp_world")
	Build.ground(self)
	LoadTiming.mark("camp_ground")
	Build.buildings(self)
	LoadTiming.mark("camp_buildings")
	View.fence(self)
	LoadTiming.mark("camp_fence")
	var PlayerS: GDScript = load("res://scripts/world/player.gd") as GDScript
	player = PlayerS.new() as CharacterBody3D
	player.position = Vector3(Build.PATH_X, 0.0, 16.0)
	add_child(player)
	if player.body:
		player.body.render_priority = 18
	LoadTiming.mark("camp_player")
	_spots()
	LoadTiming.mark("camp_spots")
	if bool(App.get("_menu_loading")) or App.wake_pending:
		LoadTiming.note("camp_dummy", "deferred")
	else:
		ensure_dummy()
	_hud()
	_music()
	if App.wake_pending:
		App.wake_pending = false
		if App.recap:
			App.recap.visible = false
			App.recap.open = false
		App.ui_open = false
		if App.present and App.present.has_method("release_wake"):
			App.present.release_wake()
		elif App.present and App.present.has_method("play_wake"):
			App.present.play_wake()
		call_deferred("ensure_dummy")
		App.prog.roll_quests(true)
		var r := App.prog.restock()
		if r != "":
			App.toast(r)
	var Smoke: GDScript = load("res://scripts/debug/smoke.gd") as GDScript
	if (
		not Smoke.phase(8)
		and not (App.playtest and bool(App.playtest.get("live_running")))
		and not bool(App.get("_menu_loading"))
	):
		App.save_now()
	if Smoke.phase(6):
		ensure_ui()
	Smoke.attach_camp(self)


func world_ui() -> Node:
	ensure_ui()
	return ui


func ensure_ui() -> void:
	if ui != null:
		return
	LoadTiming.mark("camp_ui_begin")
	var UiS: GDScript = load("res://scripts/ui/progress_ui.gd") as GDScript
	ui = UiS.new()
	add_child(ui)
	LoadTiming.mark("camp_ui")


func warmup() -> void:
	Warm.frame(self)
	if dummy:
		var stored: Vector3 = dummy.velocity
		dummy.velocity = Vector3(0.12, 0.0, 0.0)
		dummy.move_and_slide()
		dummy.velocity = stored
		dummy.global_position.y = 0.0


func warmup_restore() -> void:
	Warm.restore(self)


func _process(_delta: float) -> void:
	if App.pause_just() if App.has_method("pause_just") else (Input.is_action_just_pressed("pause") or App.pad_just("pause")):
		if App.ui_open and ui and ui.visible:
			ui.close_ui()
			if App.has_method("swallow_close_pad"):
				App.swallow_close_pad()
		elif App.pause_menu and App.pause_menu.has_method("toggle"):
			App.pause_menu.toggle()
	if hint:
		var hot := ""
		if App.prog.food_t > 0.0:
			hot = "  ·  Food HoT %ds" % int(ceil(App.prog.food_t))
		hint.text = "Placeholdia  ·  bank %dg  %d ore  %d wood  ·  deepest F%d%s\nCrystal  ·  Anvil  ·  Vendor  ·  Guild  ·  Billboard  ·  Start pause" % [App.bank_gold, App.bank_ore, App.bank_wood, App.prog.deepest, hot]
	if prompt:
		prompt.text = App.interact_prompt


func _banner() -> void:
	var root := Node3D.new()
	root.position = Vector3(Build.PATH_X, 0.0, 22.0)
	add_child(root)
	_banner_pole(root, Vector3(-1.45, 1.1, 0.0))
	_banner_pole(root, Vector3(1.45, 1.1, 0.0))
	var spr := Sprite3D.new()
	var path := "res://assets/sprites/props/welcome_banner.png"
	if ResourceLoader.exists(path):
		spr.texture = load(path)
	elif ResourceLoader.exists("res://assets/sprites/props/banner.png"):
		spr.texture = load("res://assets/sprites/props/banner.png")
	spr.centered = true
	spr.shaded = false
	spr.billboard = BaseMaterial3D.BILLBOARD_FIXED_Y
	spr.alpha_cut = SpriteBase3D.ALPHA_CUT_OPAQUE_PREPASS
	spr.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	if spr.texture:
		spr.pixel_size = 4.4 / float(maxi(1, spr.texture.get_height()))
	spr.position = Vector3(0.0, 2.2, 0.0)
	root.add_child(spr)


func _banner_pole(root: Node3D, pos: Vector3) -> void:
	var pole := StaticBody3D.new()
	pole.collision_layer = 1
	pole.position = pos
	root.add_child(pole)
	var cs := CollisionShape3D.new()
	var sh := BoxShape3D.new()
	sh.size = Vector3(0.28, 2.2, 0.28)
	cs.shape = sh
	pole.add_child(cs)


func ensure_dummy() -> void:
	if dummy != null:
		return
	var DummyS: GDScript = load("res://scripts/combat/dummy.gd") as GDScript
	var n: CharacterBody3D = DummyS.new() as CharacterBody3D
	n.position = Vector3(8.5, 0.0, Build.PATH_Z + 0.5)
	dummy = n
	add_child(n)


func _tune_label(host: Node3D) -> void:
	if host == null or not ("label" in host) or host.label == null:
		return
	host.label.no_depth_test = true
	host.label.render_priority = 8
	host.label.outline_render_priority = 7
	host.label.sorting_offset = 0.0


func _spots() -> void:
	_banner()
	var SpotS: GDScript = load("res://scripts/world/interact.gd") as GDScript
	var c: Node3D = SpotS.new()
	c.call("setup", "loadout_crystal", Vector3(16.475, 0.0, 10.2))
	add_child(c)
	_tune_label(c)
	var a: Node3D = SpotS.new()
	a.call("setup", "anvil", Vector3(21.2, 0.0, 11.4))
	add_child(a)
	_tune_label(a)
	var q: Node3D = SpotS.new()
	q.call("setup", "quest_board", Vector3(16.1, 0.0, 6.2))
	add_child(q)
	_tune_label(q)
	var wp: Vector3 = Build.wing_pos()
	var face_z: float = wp.z + Build.WING_SIZE.z * 0.5
	var rec: Node3D = SpotS.new()
	rec.call("setup", "receptionist", Vector3(wp.x + 0.027, 0.785, face_z + 0.07))
	add_child(rec)
	var rec_spr: Sprite3D = rec.get("spr") as Sprite3D
	if rec_spr:
		if rec_spr.texture:
			rec_spr.pixel_size = 1.22 / float(maxi(1, rec_spr.texture.get_height()))
			rec_spr.material_override = _bust_mat(rec_spr.texture)
		rec_spr.position = Vector3(0.0, 0.0, 0.0)
		rec_spr.billboard = BaseMaterial3D.BILLBOARD_DISABLED
		rec_spr.render_priority = 1
	var rec_lab: Label3D = rec.get("label") as Label3D
	if rec_lab:
		rec_lab.position.y = 0.85
	_tune_label(rec)
	var v: Node3D = SpotS.new()
	v.call("setup", "vendor", Vector3(25.0, 0.0, 10.2))
	add_child(v)
	var v_lab: Label3D = v.get("label") as Label3D
	if v_lab:
		v_lab.position.y = 2.25
	_tune_label(v)
	var d: Node3D = SpotS.new()
	d.call("setup", "dumpster", Vector3(5.2, 0.0, 9.4))
	add_child(d)
	_tune_label(d)
	var b: Node3D = SpotS.new()
	b.call("setup", "billboard", Vector3(20.5, 0.0, 16.5))
	add_child(b)
	_tune_label(b)


func _bust_mat(tex: Texture2D) -> ShaderMaterial:
	var sh := Shader.new()
	sh.code = """
shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_always;
uniform sampler2D albedo_tex : source_color, filter_nearest;
void fragment() {
	vec4 c = texture(albedo_tex, UV);
	if (UV.y > 0.50 || c.a < 0.1) {
		discard;
	}
	ALBEDO = c.rgb;
	ALPHA = 1.0;
}
"""
	var mat := ShaderMaterial.new()
	mat.shader = sh
	mat.set_shader_parameter("albedo_tex", tex)
	return mat


func _music() -> void:
	if App.music and App.music.has_method("play_hub"):
		App.music.play_hub()


func _hud() -> void:
	var layer := CanvasLayer.new()
	add_child(layer)
	var panel := ColorRect.new()
	panel.color = Color(0.1, 0.08, 0.06, 0.82)
	panel.position = Vector2(32, 28)
	panel.size = Vector2(980, 150)
	layer.add_child(panel)
	hint = Label.new()
	hint.position = Vector2(48, 40)
	hint.size = Vector2(950, 80)
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	hint.add_theme_font_size_override("font_size", 20)
	hint.add_theme_color_override("font_color", Color(0.92, 0.86, 0.72))
	hint.add_theme_color_override("font_outline_color", Color(0.05, 0.04, 0.03))
	hint.add_theme_constant_override("outline_size", 6)
	layer.add_child(hint)
	prompt = Label.new()
	prompt.position = Vector2(48, 118)
	prompt.size = Vector2(900, 40)
	prompt.add_theme_font_size_override("font_size", 22)
	prompt.add_theme_color_override("font_color", Color(0.95, 0.82, 0.4))
	prompt.add_theme_color_override("font_outline_color", Color(0.05, 0.04, 0.03))
	prompt.add_theme_constant_override("outline_size", 6)
	layer.add_child(prompt)
