@tool
extends Node3D

const Dbg := preload("res://scripts/app/dbg.gd")
const Build := preload("res://scripts/world/camp_build.gd")
const LightRt := preload("res://scripts/graphics/light_rt.gd")
const View := preload("res://scripts/world/camp/camp_view.gd")
const Warm := preload("res://scripts/world/camp/warm.gd")
const LayoutS := preload("res://scripts/world/camp/layout.gd")

const Banner := preload("res://scripts/world/camp/banner.gd")
const Prompts := preload("res://scripts/input/prompts.gd")
const Talk := preload("res://scripts/data/talk_lines.gd")
const Hud := preload("res://scripts/world/camp/camp_hud.gd")
const Spot := preload("res://scripts/world/camp/spot.gd")
var player: CharacterBody3D
var dummy: CharacterBody3D
var ui: CanvasLayer
var hud: CanvasLayer
var hint: Label
var prompt: Label
var _layout: Node3D
var _editor_hooked: bool = false
var build_done: bool = false

func _ready() -> void:
	Dbg.hitch("camp_enter")
	_layout = LayoutS.on_camp(self)
	_layout.ensure_tree()
	Dbg.hitch("camp_layout")
	if Engine.is_editor_hint():
		_hook_editor()
		Build.realize_editor(self, _layout)
		build_done = true
		return
	# Title -> Placeholdia keeps the loader up. Spread the build so one frame is not the whole camp.
	# A dungeon return does not set _menu_loading and still builds in this call.
	if bool(App.get("_menu_loading")):
		await _run_paced(_build_steps())
	else:
		for step: Callable in _build_steps():
			step.call()

func _build_steps() -> Array[Callable]:
	var steps: Array[Callable] = [
		_step_env,
		_step_light,
		_step_ground,
		_step_hall,
		_step_wing,
		_step_stall,
		_step_fence,
		_step_player,
		_step_spot_crystal,
		_step_spot_anvil,
		_step_spot_board,
		_step_spot_receptionist,
		_step_spot_vendor,
		_step_spot_dumpster,
		_step_spot_billboard,
		_step_rest,
	]
	return steps

func _run_paced(steps: Array[Callable]) -> void:
	var i: int = 0
	while i < steps.size():
		var step: Callable = steps[i]
		step.call()
		i += 1
		if i < steps.size():
			await get_tree().process_frame

func _step_env() -> void:
	App.in_dungeon = false
	Dbg.hitch("layout_tree")
	Talk.on_hub_entry()
	Dbg.lt_mark("camp_enter")
	Build.world(self)
	Dbg.lt_mark("camp_world")
	Dbg.hitch("hub_env")

func _step_light() -> void:
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
	Dbg.lt_mark("camp_light")
	Dbg.hitch("hub_light")

func _step_ground() -> void:
	var gen: Node3D = Build.generated(self)
	if gen.get_child_count() > 0:
		Build.clear_generated(self)
		gen = Build.generated(self)
	Dbg.lt_note("camp_geo", "build")
	Build.ground(gen)
	Dbg.lt_mark("camp_ground")
	Dbg.hitch("hub_ground")

func _step_hall() -> void:
	Build.hall(Build.generated(self))
	Dbg.hitch("hub_hall")

func _step_wing() -> void:
	Build.wing(Build.generated(self))
	Dbg.hitch("hub_wing")

func _step_stall() -> void:
	var gen: Node3D = Build.generated(self)
	Build.stall(gen)
	Build.strip_building_cubes(gen)
	Build.quiet_shadows(gen)
	Dbg.lt_mark("camp_buildings")
	Dbg.hitch("hub_stall")

func _step_fence() -> void:
	var gen: Node3D = Build.generated(self)
	View.fence(gen)
	Dbg.lt_mark("camp_fence")
	Dbg.hitch("hub_fence")

func _step_player() -> void:
	var PlayerS: GDScript = load("res://scripts/world/player.gd") as GDScript
	player = PlayerS.new() as CharacterBody3D
	player.position = _layout.spot_pos("Spawn")
	add_child(player)
	if player.body:
		player.body.render_priority = 18
	Dbg.lt_mark("camp_player")
	Dbg.hitch("hub_player")

func _step_spot_crystal() -> void:
	Spot._add_spot(self, "loadout_crystal", _layout.spot_pos("Crystal"))
	Dbg.hitch("hub_spot_crystal")

func _step_spot_anvil() -> void:
	Spot._add_spot(self, "anvil", _layout.spot_pos("Anvil"))
	Dbg.hitch("hub_spot_anvil")

func _step_spot_board() -> void:
	Spot._add_spot(self, "quest_board", _layout.spot_pos("Board"))
	Dbg.hitch("hub_spot_board")

func _step_spot_receptionist() -> void:
	Banner._banner(self)
	var rec: Node3D = Spot._new_spot(self, "receptionist", _layout.reception_pos())
	var rec_spr: Sprite3D = rec.get("spr") as Sprite3D
	if rec_spr:
		if rec_spr.texture:
			rec_spr.pixel_size = 1.22 / float(maxi(1, rec_spr.texture.get_height()))
			rec_spr.material_override = Spot._bust_mat(rec_spr.texture)
		rec_spr.position = Vector3(0.0, 0.0, 0.0)
		rec_spr.billboard = BaseMaterial3D.BILLBOARD_DISABLED
		rec_spr.render_priority = 1
	var rec_lab: Label3D = rec.get("label") as Label3D
	if rec_lab:
		rec_lab.position.y = 0.85
	Spot._tune_label(rec)
	Dbg.hitch("hub_spot_receptionist")

func _step_spot_vendor() -> void:
	var v: Node3D = Spot._new_spot(self, "vendor", _layout.spot_pos("Vendor"))
	var v_lab: Label3D = v.get("label") as Label3D
	if v_lab:
		v_lab.position.y = 2.25
	Spot._tune_label(v)
	Dbg.hitch("hub_spot_vendor")

func _step_spot_dumpster() -> void:
	Spot._add_spot(self, "dumpster", _layout.spot_pos("Dumpster"))
	Dbg.hitch("hub_spot_dumpster")

func _step_spot_billboard() -> void:
	Spot._add_spot(self, "billboard", _layout.spot_pos("Billboard"))
	Dbg.lt_mark("camp_spots")
	Dbg.hitch("hub_spot_billboard")

func _step_rest() -> void:
	Build.stamp_actor_blobs(self)
	Dbg.hitch("hub_blobs")
	if bool(App.get("_menu_loading")) or App.wake_pending:
		Dbg.lt_note("camp_dummy", "deferred")
	else:
		ensure_dummy()
	Hud._hud(self)
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
		var r: String = App.prog.restock()
		if r != "":
			App.toast(r)
	if (
		not Dbg.smoke_phase(8)
		and not (App.playtest and bool(App.playtest.get("live_running")))
		and not bool(App.get("_menu_loading"))
	):
		App.save_now()
	if Dbg.smoke_phase(6):
		ensure_ui()
	Dbg.smoke_attach("camp", self)
	build_done = true
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
	Dbg.lt_mark("camp_ui_begin")
	var UiS: GDScript = load("res://scripts/ui/progress_ui.gd") as GDScript
	ui = UiS.new()
	add_child(ui)
	Dbg.lt_mark("camp_ui")

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
	Dbg.hitch("hub_blobs")

func _music() -> void:
	if App.music and App.music.has_method("play_hub"):
		App.music.play_hub()

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
