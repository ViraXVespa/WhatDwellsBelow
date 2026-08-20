extends Node

func _ready() -> void:
	var args := OS.get_cmdline_user_args()
	if "--smoke-boss" in args:
		Game.begin_run({"weapon": ItemData.make_starter_axe(), "tool": ItemData.make_starter_pickaxe()}, 3)
		return
	if "--smoke-dungeon" in args:
		Game.begin_run({"weapon": ItemData.make_starter_axe(), "tool": ItemData.make_starter_pickaxe()}, 1)
		return
	get_tree().call_deferred("change_scene_to_file", "res://scenes/splash.tscn")
