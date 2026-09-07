extends Node

const Smoke := preload("res://scripts/debug/smoke.gd")
const Disp := preload("res://scripts/display_mode.gd")


func _ready() -> void:
	if Smoke.route_boot():
		return
	var next: String = "res://scenes/splash.tscn"
	if Disp.wants_gate():
		next = "res://scenes/fs_gate.tscn"
	get_tree().call_deferred("change_scene_to_file", next)
