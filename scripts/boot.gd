extends Node


func _ready() -> void:
	if App.Smoke.route_boot():
		return
	var next: String = "res://scenes/splash.tscn"
	if App.Disp.wants_gate():
		next = "res://scenes/fs_gate.tscn"
	get_tree().call_deferred("change_scene_to_file", next)
