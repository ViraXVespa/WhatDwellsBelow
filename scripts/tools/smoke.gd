extends SceneTree

var frames := 0
var path := "user://smoke.txt"


func _log(msg: String) -> void:
	printerr(msg)
	var f := FileAccess.open(path, FileAccess.READ_WRITE)
	if f == null:
		f = FileAccess.open(path, FileAccess.WRITE)
	else:
		f.seek_end()
	if f:
		f.store_line(msg)


func _initialize() -> void:
	_log("SMOKE: init")
	if Game == null:
		_log("SMOKE: Game is null")
		quit()
		return
	Game.begin_run(ItemData.make_starter_axe(), ItemData.make_starter_pickaxe(), 1)
	_log("SMOKE: begin_run called")


func _process(_delta: float) -> bool:
	frames += 1
	if frames == 20:
		_log("SMOKE: floor=%s" % str(Game.run.current_floor if Game.run else -1))
		_log("SMOKE: enemies=%d" % get_nodes_in_group("enemies").size())
		_log("SMOKE: interact=%d" % get_nodes_in_group("interactable").size())
		_log("SMOKE: player=%s" % str(get_first_node_in_group("player") != null))
		quit()
	return false
