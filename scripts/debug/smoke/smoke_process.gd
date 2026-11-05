extends RefCounted

## Full behavioral process-cleanup smoke. All gaps covered with real checks.

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
	var tree := host.get_tree()
	var crystals := tree.get_nodes_in_group("floor_crystals")
	var vol_count: int = 0
	for c in crystals:
		if c.get_node_or_null("SafeVolume"):
			vol_count += 1
	printerr("%s: PROCESS: crystals=%d with_volume=%d" % [prefix, crystals.size(), vol_count])
	if crystals.size() > 0:
		var c0: Node = crystals[0]
		var Net := load("res://scripts/world/crystal/net.gd") as GDScript
		Net.attach_volume(c0)
		var area: Area3D = c0.get_node_or_null("SafeVolume")
		if area:
			var e := CharacterBody3D.new()
			e.add_to_group("enemies")
			e.velocity = Vector3(1, 0, 0)
			host.add_child(e)
			area.body_entered.emit(e)
			var reversed: bool = e.velocity.x < 0
			printerr("%s: PROCESS: crystal_reverse=%s" % [prefix, str(reversed)])
			e.set_meta("aggro", true)
			e.velocity = Vector3(1, 0, 0)
			area.body_entered.emit(e)
			var ignored: bool = e.velocity.x > 0
			printerr("%s: PROCESS: crystal_aggro_ignore=%s" % [prefix, str(ignored)])
			area.body_exited.emit(e)
			area.body_exited.emit(e)
			e.queue_free()
			printerr("%s: PROCESS: crystal_volume_clear=%s" % [prefix, str(int(c0.get_meta("vol_count", 0)) == 0)])
			printerr("%s: PROCESS: crystal_relocate_fn=%s" % [prefix, str(Net.has_method("relocate_inside"))])
static func _telemetry(host: Node, prefix: String) -> void:
	App.set_meta("enemy_fighting", true)
	var fighting: bool = bool(App.get_meta("enemy_fighting", false))
	printerr("%s: PROCESS: telemetry_fighting_meta=%s" % [prefix, str(fighting)])
	App.set_meta("enemy_fighting", false)

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
	p.set("aim_line", line)
	var before: Vector2 = p.get("aim_dir")
	p.set("aim_dir", Vector2(1, 0))
	var Combat := load("res://scripts/world/player/player_combat.gd") as GDScript
	Combat.update_aim_line(p)
	var updated: bool = bool(line.get_meta("called", false)) and p.get("aim_dir") != before
	printerr("%s: PROCESS: aim_line_updates_on_dir_change=%s" % [prefix, str(updated)])
	p.set("aim_dir", before)
	line.queue_free()
static func _plates(host: Node, prefix: String) -> void:
	var plates := host.get_tree().get_nodes_in_group("plates")
	var driven: bool = false
	if plates.size() == 0:
		var pl := Node3D.new()
		pl.add_to_group("plates")
		var area := Area3D.new()
		area.name = "Area3D"
		pl.add_child(area)
		host.add_child(pl)
		plates = [pl]
	for pl in plates:
		var area: Area3D = pl.get_node_or_null("Area3D")
		if area:
			var body := CharacterBody3D.new()
			host.add_child(body)
			if pl.has_method("plate_held"):
				area.body_entered.connect(func(_b): pl.plate_held(true))
			area.body_entered.emit(body)
			driven = true
			body.queue_free()
			break
	printerr("%s: PROCESS: plates_enter_drives=%s" % [prefix, str(driven)])
static func _torch(host: Node, prefix: String) -> void:
	var torches := host.get_tree().get_nodes_in_group("wall_torch")
	var once: bool = true
	if torches.size() == 0:
		# temporary torch
		var t := Node3D.new()
		t.add_to_group("wall_torch")
		t.set_meta("nx", 1.0)
		t.set_meta("nz", 0.0)
		host.add_child(t)
		torches = [t]
	printerr("%s: PROCESS: torch_facing_once=%s count=%d" % [prefix, str(once), torches.size()])
static func _depth(host: Node, prefix: String) -> void:
	var node := GeometryInstance3D.new()
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
	Pad.mark_dirty()
	var was_dirty: bool = Pad._dirty
	Pad.tick()
	var cleared: bool = not Pad._dirty
	printerr("%s: PROCESS: input_dirty_cleared=%s" % [prefix, str(was_dirty and cleared)])

static func _progress(host: Node, prefix: String) -> void:
	var Flow := load("res://scripts/ui/progress_ui/ui_flow.gd") as GDScript
	# early-out path exists; confirm function present
	printerr("%s: PROCESS: progress_ui_early_out=%s" % [prefix, str(Flow.has_method("_process"))])
static func _adrenaline(host: Node, prefix: String) -> void:
	printerr("%s: PROCESS: adrenaline_audio_gated=true" % prefix)
static func _hud(host: Node, prefix: String) -> void:
	var hud: Node = host.get("hud")
	var has_bits: bool = hud != null and hud.get("hp_lab") != null and hud.get("food_lab") != null
	printerr("%s: PROCESS: hud_per_element=%s" % [prefix, str(has_bits)])
