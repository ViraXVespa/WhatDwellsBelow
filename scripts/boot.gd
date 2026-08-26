extends Node


func _ready() -> void:
	var args := OS.get_cmdline_user_args()
	if "--wdb-phase1-smoke" in args or "--wdb-phase2-smoke" in args:
		App.go_foundation()
		return
	if "--wdb-phase3-smoke" in args or "--wdb-phase4-smoke" in args or "--wdb-phase5-smoke" in args:
		App.begin_run()
		return
	if "--wdb-phase6-smoke" in args:
		App.go_camp()
		return
	if "--wdb-phase7-smoke" in args:
		App.begin_run()
		return
	if "--wdb-phase8-smoke" in args:
		App.go_camp()
		return
	if "--wdb-phase9-smoke" in args:
		App.begin_run()
		return
	get_tree().call_deferred("change_scene_to_file", "res://scenes/splash.tscn")
