extends Node

const Smoke := preload("res://scripts/debug/smoke.gd")


func _ready() -> void:
	if Smoke.route_boot():
		return
	get_tree().call_deferred("change_scene_to_file", "res://scenes/splash.tscn")