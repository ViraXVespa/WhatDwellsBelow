extends SceneTree

var frames := 0
var path := "user://full_3d_pass/smoke.txt"


func _log(msg: String) -> void:
	printerr(msg)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("user://full_3d_pass"))
	var f := FileAccess.open(path, FileAccess.READ_WRITE)
	if f == null:
		f = FileAccess.open(path, FileAccess.WRITE)
	else:
		f.seek_end()
	if f:
		f.store_line(msg)


func _game() -> Node:
	return root.get_node_or_null("/root/Game")


func _initialize() -> void:
	_log("SMOKE: init")
	_log("ISO: resource_path=" + ProjectSettings.globalize_path("res://"))
	_log("ISO: game_script=" + str(root.get_node_or_null("/root/Game").get_script().resource_path if root.get_node_or_null("/root/Game") else "missing"))
	_log("ISO: sfx_script=" + str(root.get_node_or_null("/root/Sfx").get_script().resource_path if root.get_node_or_null("/root/Sfx") else "missing"))
	_log("ISO: plaza3d=" + str(ResourceLoader.exists("res://scenes/plaza_3d.tscn")))
	_log("ISO: live_parent_probe_should_fail_outside_archive")
	_test_gen()
	_test_skills()
	var game := _game()
	if game == null:
		_log("SMOKE: Game is null")
		quit()
		return
	_log("SMOKE: plaza3d=%s dungeon3d=%s" % [
		str(ResourceLoader.exists("res://scenes/plaza_3d.tscn")),
		str(ResourceLoader.exists("res://scenes/dungeon_3d.tscn")),
	])
	for sp in ["res://scripts/view3d/v3.gd", "res://scripts/view3d/player_3d.gd", "res://scripts/view3d/enemy_3d.gd", "res://scripts/view3d/plaza_3d.gd", "res://scripts/view3d/dungeon_3d.gd"]:
		if load(sp) == null:
			_log("SMOKE: FAIL load " + sp)
	if game.save:
		game.save.presentation = "live"
	game.begin_run({"weapon": ItemData.make_starter_axe(), "tool": ItemData.make_starter_pickaxe()}, 1)
	_log("SMOKE: begin_run 3d called")


func _test_gen() -> void:
	var data := DungeonGen.generate(1, 42)
	var spawn: Vector2i = data.spawn
	var crystal: Vector2i = data.crystal
	var d: int = absi(spawn.x - crystal.x) + absi(spawn.y - crystal.y)
	_log("SMOKE: crystal_manhattan=%d spawn=%s crystal=%s" % [d, str(spawn), str(crystal)])
	if d != 1:
		_log("SMOKE: FAIL crystal not adjacent to spawn")
	var grid := PackedByteArray()
	grid.resize(DungeonGen.W * DungeonGen.H)
	grid.fill(DungeonGen.FLOOR)
	grid[DungeonGen.idx(5, 4)] = DungeonGen.WALL
	var clear := DungeonGen.has_grid_los(grid, Vector2i(4, 4), Vector2i(4, 6))
	var blocked := DungeonGen.has_grid_los(grid, Vector2i(4, 4), Vector2i(6, 4))
	_log("SMOKE: los_open=%s (expect true) los_through_wall=%s (expect false)" % [str(clear), str(blocked)])
	var t_clear := DungeonGen.tile_has_los(grid, Vector2(4.4, 4.4), Vector2(4.4, 6.2))
	var t_block := DungeonGen.tile_has_los(grid, Vector2(4.4, 4.4), Vector2(6.2, 4.4))
	_log("SMOKE: tile_los_open=%s (expect true) tile_los_wall=%s (expect false)" % [str(t_clear), str(t_block)])
	var br: Array = data.get("breakables", [])
	_log("SMOKE: breakables=%d" % br.size())


func _test_skills() -> void:
	_log("SMOKE: level0=%d level90=%d" % [Skills.level_from_xp(0.0), Skills.level_from_xp(90.0)])
	var face := Art.facing_from_dir(Vector2(1, 1).normalized())
	_log("SMOKE: facing_down_right=%s" % face)


func _process(_delta: float) -> bool:
	frames += 1
	if frames == 20:
		var game := _game()
		var run = game.get("run") if game else null
		_log("SMOKE: floor=%s" % str(run.current_floor if run else -1))
		_log("SMOKE: enemies=%d" % get_nodes_in_group("enemies").size())
		_log("SMOKE: interact=%d" % get_nodes_in_group("interactable").size())
		_log("SMOKE: player=%s" % str(get_first_node_in_group("player") != null))
		quit()
	return false
