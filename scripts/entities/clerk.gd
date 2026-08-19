class_name Clerk
extends Interactable

var clerk_kind := "gather"
var clerk_id := "miner"
var spent_normal := false
var spent_gold := false
var ui: ExtractUI


func setup(kind: String, id: String) -> void:
	clerk_kind = kind
	clerk_id = id
	is_safe = true
	prompt = display_name()


func display_name() -> String:
	match clerk_id:
		"miner":
			return "Miner"
		"lumberjack":
			return "Lumberjack"
		"alchemist":
			return "Alchemist"
		"stonemason":
			return "Stonemason"
		"fishmonger":
			return "Fishmonger"
		"gopher":
			return "Gear Gopher"
		"runner":
			return "Guild Runner"
		"patty":
			return "Packmule Patty"
		_:
			return "Clerk"


func family_accepted() -> String:
	match clerk_id:
		"miner":
			return "ore"
		"lumberjack":
			return "wood"
		"alchemist":
			return "plants"
		"stonemason":
			return "stone"
		"fishmonger":
			return "fish"
		_:
			return ""


func _ready() -> void:
	super._ready()
	var path := "res://assets/sprites/npcs/%s.png" % clerk_id
	var tex := Art.load_tex(path)
	if tex == null:
		var col := Color(0.75, 0.62, 0.28)
		if clerk_id == "gopher":
			col = Color(0.55, 0.45, 0.75)
		elif clerk_id == "runner":
			col = Color(0.45, 0.6, 0.75)
		tex = Art.body(Vector2i(56, 56), col, Color(0.95, 0.9, 0.7))
	add_child(Art.make_sprite(tex, 0.82))
	prompt = display_name()


func get_prompt() -> String:
	if spent_gold:
		return "%s (done)" % display_name()
	return "Talk: %s" % display_name()


func interact(player: Node) -> void:
	if spent_gold:
		return
	var uis := get_tree().get_nodes_in_group("extract_ui")
	if uis.is_empty():
		return
	var extract: ExtractUI = uis[0]
	extract.open_for(self)
