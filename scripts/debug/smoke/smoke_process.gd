extends RefCounted

## Process-migration callback/lifecycle assertions; real physics and visual checks are separate.

static func run_p1(host: Node) -> void:
	_aim(host, "P1")
	_depth(host, "P1")
	_adrenaline(host, "P1")
	printerr("P1: PROCESS: done")

static func run_p3(host: Node) -> void:
	_crystal(host, "P3")
	_plates(host, "P3")
	_torch(host, "P3")
	_telemetry(host, "P3")
	printerr("P3: PROCESS: done")

static func run_p7(host: Node) -> void:
	_crystal(host, "P7")
	_telemetry(host, "P7")
	_camp(host, "P7")
	_gem(host, "P7")
	_aim(host, "P7")
	_plates(host, "P7")
	_torch(host, "P7")
	_input(host, "P7")
	_progress(host, "P7")
	_hud(host, "P7")
	printerr("P7: PROCESS: done")

static func _crystal(host: Node, prefix: String) -> void:
	var crystals := host.get_tree().get_nodes_in_group("floor_crystals")
	if crystals.is_empty():
		printerr("%s: PROCESS: crystal_callbacks=SKIP no_crystal" % prefix)
		return
	var c: Node = crystals[0]
	var Net := load("res://scripts/world/crystal/net.gd") as GDScript
	Net.attach_volume(c)
	var area: Area3D = c.get_node_or_null("SafeVolume")
	assert(area != null and area.collision_mask == 4)
	var previous: Dictionary = c.get_meta("vol_bodies", {}).duplicate()
	var was_on: bool = c.crystal_on
	var script := GDScript.new()
	script.source_code = "extends CharacterBody3D
const ST_RETURN = 3
var state = 0
var aim = Vector2.DOWN
var reaggro_t = 0.0
"
	assert(script.reload() == OK)
	var e: CharacterBody3D = script.new()
	host.add_child(e)
	e.add_to_group("enemies")
	c.crystal_on = true
	e.velocity = Vector3.RIGHT
	area.body_entered.emit(e)
	assert(e.velocity.x < 0.0)
	e.state = 1
	e.velocity = Vector3.RIGHT
	area.body_entered.emit(e)
	assert(e.velocity.x > 0.0)
	assert(int(c.get_meta("vol_count", 0)) <= previous.size() + 1)
	area.body_exited.emit(e)
	area.body_exited.emit(e)
	c.crystal_on = was_on
	c.set_meta("vol_bodies", previous)
	c.refresh()
	e.queue_free()
	printerr("%s: PROCESS: crystal_callbacks=PASS (not a physics-overlap proof)" % prefix)

static func _telemetry(_host: Node, prefix: String) -> void:
	var previous: Dictionary = App.get_meta("enemy_fighters", {}).duplicate()
	var a := Node.new()
	var b := Node.new()
	App.AppRun.note_enemy_fighting(a, true)
	App.AppRun.note_enemy_fighting(a, true)
	App.AppRun.note_enemy_fighting(b, true)
	App.AppRun.note_enemy_fighting(a, false)
	assert(bool(App.get_meta("enemy_fighting", false)))
	App.AppRun.note_enemy_fighting(b, false)
	App.set_meta("enemy_fighters", previous)
	App.set_meta("enemy_fighting", not previous.is_empty())
	a.free()
	b.free()
	printerr("%s: PROCESS: concurrent_fighters=PASS" % prefix)

static func _camp(host: Node, prefix: String) -> void:
	var bank: bool = App.has_signal("bank_changed")
	var prompt: bool = App.has_signal("prompt_changed")
	printerr("%s: PROCESS: camp_signals bank=%s prompt=%s" % [prefix, str(bank), str(prompt)])

static func _gem(host: Node, prefix: String) -> void:
	var hud: Node = host.get("hud")
	if hud == null:
		printerr("%s: PROCESS: gem_tween=no_hud" % prefix)
		return
	App.set("danger_gem", true)
	var Act := load("res://scripts/ui/hud/hud_act.gd") as GDScript
	if Act.has_method("paint_gem"):
		Act.paint_gem(hud, host)
	var gem: Node = hud.get("gem")
	var has_tween: bool = gem != null and gem.has_meta("pulse_tween") and gem.get_meta("pulse_tween") != null
	printerr("%s: PROCESS: gem_tween=%s" % [prefix, str(has_tween)])
	App.set("danger_gem", false)

static func _aim(host: Node, prefix: String) -> void:
	var p: Node = host.get_tree().get_first_node_in_group("player")
	if p == null:
		printerr("%s: PROCESS: aim_line=no_player" % prefix)
		return
	var line := Node3D.new()
	line.set_script(null)
	# inject a method so update_aim_line can call it
	line.set_meta("called", false)
	var dummy_script := GDScript.new()
	dummy_script.source_code = """
extends Node3D
func update_line(pos, dir, length, width, opacity, on):
	set_meta('called', true)
"""
	dummy_script.reload()
	line.set_script(dummy_script)
	p.add_child(line)
	var saved_line: Node = p.get("aim_line")
	p.set("aim_line", line)
	var before: Vector2 = p.get("aim_dir")
	p.set("aim_dir", Vector2.RIGHT if before == Vector2.ZERO else Vector2(-before.y, before.x))
	var Combat := load("res://scripts/world/player/player_combat.gd") as GDScript
	Combat.update_aim_line(p)
	var updated: bool = bool(line.get_meta("called", false)) and p.get("aim_dir") != before
	printerr("%s: PROCESS: aim_line_updates_on_dir_change=%s" % [prefix, str(updated)])
	p.set("aim_dir", before)
	p.set("aim_line", saved_line)
	assert(updated)
	line.queue_free()
static func _plates(host: Node, prefix: String) -> void:
	var body: Node = host.get_tree().get_first_node_in_group("player")
	if body == null:
		printerr("%s: PROCESS: plate_callbacks=SKIP no_player" % prefix)
		return
	var Spot := load("res://scripts/world/interact.gd") as GDScript
	var pl: Node = Spot.new()
	pl.pair = "process_smoke_isolated"
	pl.setup("plate", Vector3.ZERO)
	host.add_child(pl)
	var area: Area3D = pl.get_node_or_null("PlateArea")
	assert(area != null and area.collision_mask == 2)
	area.body_entered.emit(body)
	assert(pl.pressed)
	area.body_exited.emit(body)
	assert(not pl.pressed)
	pl.queue_free()
	printerr("%s: PROCESS: plate_callbacks=PASS (not a physics-overlap proof)" % prefix)

static func _torch(host: Node, prefix: String) -> void:
	var torches := host.get_tree().get_nodes_in_group("wall_torch")
	if torches.is_empty():
		printerr("%s: PROCESS: torch_facing=SKIP no_torch" % prefix)
		return
	for t in torches:
		var flame: Node3D = t.get("_flame")
		assert(flame != null)
		var before: Transform3D = flame.global_transform
		t._set_facing_once()
		assert(flame.global_transform.is_equal_approx(before))
	printerr("%s: PROCESS: torch_facing_idempotent=PASS" % prefix)

static func _depth(host: Node, prefix: String) -> void:
	var node := MeshInstance3D.new()
	node.sorting_offset = 0.0
	var Depth := load("res://scripts/world/depth.gd") as GDScript
	Depth.apply(node, Vector3(1, 0, 2))
	var changed: bool = absf(node.sorting_offset) > 0.01
	Depth.apply(node, Vector3(1, 0, 2))
	var unchanged: bool = absf(node.sorting_offset - (2.0 * 6.0 + 1.0 * 0.04)) < 0.01
	printerr("%s: PROCESS: depth_on_change=%s" % [prefix, str(changed and unchanged)])
	node.free()

static func _input(host: Node, prefix: String) -> void:
	var Pad := load("res://scripts/input/pad.gd") as GDScript
	var count := [0]
	var note: Callable = func(): count[0] += 1
	App.input_changed.connect(note)
	Pad.note_event(InputEventKey.new())
	App.input_changed.disconnect(note)
	assert(count[0] == 1, "input event must invalidate touch drawing")
	printerr("%s: PROCESS: input_event_invalidates=true" % prefix)

static func _progress(host: Node, prefix: String) -> void:
	var ui: Node = host.get("ui")
	if ui == null:
		printerr("%s: PROCESS: progress_processing=SKIP no_ui" % prefix)
		return
	var was_open: bool = ui.open
	var was_time: float = ui.forge_t
	ui.open = false
	ui.forge_t = 0.0
	assert(not ui.is_processing())
	ui.forge_t = 0.1
	assert(ui.is_processing())
	ui.forge_t = was_time
	ui.open = was_open
	printerr("%s: PROCESS: progress_idle_and_forge=PASS" % prefix)

static func _adrenaline(_host: Node, prefix: String) -> void:
	var audio: Node = App.sfx_node
	assert(audio != null and audio.loop_player.finished.is_connected(Callable(audio, "_restart_adrenaline")))
	printerr("%s: PROCESS: adrenaline_finished_connected=PASS" % prefix)

static func _hud(host: Node, prefix: String) -> void:
	var hud: Node = host.get("hud")
	var has_bits: bool = hud != null and hud.get("hp_lab") != null and hud.get("food_lab") != null
	printerr("%s: PROCESS: hud_layout_present=%s" % [prefix, str(has_bits)])
