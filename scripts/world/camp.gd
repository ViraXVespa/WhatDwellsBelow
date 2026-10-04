@tool
extends Node3D

const Build := preload("res://scripts/world/camp_build.gd")
const LightRt := preload("res://scripts/graphics/light_rt.gd")
const View := preload("res://scripts/world/camp/camp_view.gd")
const LoadTiming := preload("res://scripts/debug/load_timing.gd")
const Warm := preload("res://scripts/world/camp/warm.gd")
const LayoutS := preload("res://scripts/world/camp/layout.gd")

const Banner := preload("res://scripts/world/camp/banner.gd")
const Prompts := preload("res://scripts/input/prompts.gd")
var player: CharacterBody3D
var dummy: CharacterBody3D
var ui: CanvasLayer
var hud: CanvasLayer
var hint: Label
var prompt: Label
var _layout: Node3D
var _editor_hooked: bool = false

func _ready() -> void:
	_layout = LayoutS.on_camp(self)
	_layout.ensure_tree()
	if Engine.is_editor_hint():
		_hook_editor()
		Build.realize_editor(self, _layout)
		return
	App.in_dungeon = false
	LoadTiming.mark("camp_enter")
	Build.world(self)
	LoadTiming.mark("camp_world")
	LightRt.prepare_hub(
		int(_layout.aabb_x0()),
		int(_layout.aabb_z0()),
		int(_layout.aabb_x1()),
		int(_layout.aabb_z1()),
		Vector2(_layout.spot_pos("Crystal").x, _layout.spot_pos("Crystal").z),
		_layout
	)
	LightRt.hub_crystal = Vector2(_layout.spot_pos("Crystal").x, _layout.spot_pos("Crystal").z)
	LightRt.rebind_tree(self)
	LoadTiming.mark("camp_light")
	var gen: Node3D = Build.generated(self)
	if gen.get_child_count() > 0:
		Build.clear_generated(self)
		gen = Build.generated(self)
	LoadTiming.note("camp_geo", "build")
	Build.ground(gen)
	LoadTiming.mark("camp_ground")
	Build.buildings(gen)
	Build.strip_building_cubes(gen)
	Build.quiet_shadows(gen)
	LoadTiming.mark("camp_buildings")
	View.fence(gen)
	LoadTiming.mark("camp_fence")
	var PlayerS: GDScript = load("res://scripts/world/player.gd") as GDScript
	player = PlayerS.new() as CharacterBody3D
	player.position = _layout.spot_pos("Spawn")
	add_child(player)
	if player.body:
		player.body.render_priority = 18
	LoadTiming.mark("camp_player")
	_spots()
	LoadTiming.mark("camp_spots")
	Build.stamp_actor_blobs(self)
	if bool(App.get("_menu_loading")) or App.wake_pending:
		LoadTiming.note("camp_dummy", "deferred")
	else:
		ensure_dummy()
	_hud()
	_music()
	var hold_wake: bool = (
		App.present != null
		and bool(App.present.visible)
		and App.present.has_method("release_wake")
	)
	if App.wake_pending or hold_wake:
		App.wake_pending = false
		if App.recap:
			App.recap.visible = false
			App.recap.open = false
		App.ui_open = false
		if App.get_tree():
			App.get_tree().paused = false
		if hold_wake:
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
func _hook_editor() -> void:
	if _editor_hooked:
		return
	_editor_hooked = true
	if not _layout.editor_redraw.is_connected(_on_layout_redraw):
		_layout.editor_redraw.connect(_on_layout_redraw)

func _on_layout_redraw() -> void:
	if Engine.is_editor_hint():
		Build.realize_editor(self, _layout)

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
	if Engine.is_editor_hint():
		return
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
		hint.text = Prompts.fmt(tr("camp.placeholdia_bank_g_ore_wood")) % [App.bank_gold, App.bank_ore, App.bank_wood, App.prog.deepest, hot]
	if prompt:
		prompt.text = App.interact_prompt

func ensure_dummy() -> void:
	if dummy != null:
		return
	var DummyS: GDScript = load("res://scripts/combat/dummy.gd") as GDScript
	var n: CharacterBody3D = DummyS.new() as CharacterBody3D
	n.position = _layout.spot_pos("Dummy")
	dummy = n
	add_child(n)
	Build.stamp_actor_blobs(self)

func _tune_label(host: Node3D) -> void:
	if host == null or not ("label" in host) or host.label == null:
		return
	host.label.no_depth_test = true
	host.label.render_priority = 8
	host.label.outline_render_priority = 7
	host.label.sorting_offset = 0.0

func _spots() -> void:
	Banner._banner(self)
	var SpotS: GDScript = load("res://scripts/world/interact.gd") as GDScript
	var c: Node3D = SpotS.new()
	var crystal: Vector3 = _layout.spot_pos("Crystal")
	c.call("setup", "loadout_crystal", crystal)
	add_child(c)
	_tune_label(c)
	var a: Node3D = SpotS.new()
	a.call("setup", "anvil", _layout.spot_pos("Anvil"))
	add_child(a)
	_tune_label(a)
	var q: Node3D = SpotS.new()
	q.call("setup", "quest_board", _layout.spot_pos("Board"))
	add_child(q)
	_tune_label(q)
	var rec: Node3D = SpotS.new()
	rec.call("setup", "receptionist", _layout.reception_pos())
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
	v.call("setup", "vendor", _layout.spot_pos("Vendor"))
	add_child(v)
	var v_lab: Label3D = v.get("label") as Label3D
	if v_lab:
		v_lab.position.y = 2.25
	_tune_label(v)
	var d: Node3D = SpotS.new()
	d.call("setup", "dumpster", _layout.spot_pos("Dumpster"))
	add_child(d)
	_tune_label(d)
	var b: Node3D = SpotS.new()
	b.call("setup", "billboard", _layout.spot_pos("Billboard"))
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
	hud = layer
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

func _strip_baked_env(n: Node) -> void:
	if n == null:
		return
	var i: int = n.get_child_count() - 1
	while i >= 0:
		var c: Node = n.get_child(i)
		if c is WorldEnvironment or c is DirectionalLight3D:
			n.remove_child(c)
			c.free()
		else:
			_strip_baked_env(c)
		i -= 1
