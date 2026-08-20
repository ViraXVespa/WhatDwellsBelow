class_name ArtifactChest
extends Interactable

var opened := false
var rng := RandomNumberGenerator.new()


func _ready() -> void:
	super._ready()
	rng.randomize()
	prompt = "Open chest"
	var tex := Art.load_tex("res://assets/sprites/props/chest.png")
	if tex == null:
		tex = Art.chest(Vector2i(48, 40))
	var spr := Art.make_sprite(tex, 0.82)
	spr.modulate = Color(0.95, 0.78, 0.35)
	add_child(spr)


func get_prompt() -> String:
	return "Empty chest" if opened else "Open chest"


func interact(_player: Node) -> void:
	if opened or Game.run == null:
		return
	opened = true
	prompt = "Empty chest"
	modulate = Color(0.5, 0.5, 0.52)
	var art_s = load("res://scripts/data/artifacts.gd")
	var art: Dictionary = art_s.pick(rng, Game.run.artifact_ids)
	var gold_amt := rng.randi_range(8, 22)
	Game.add_run_gold(gold_amt)
	if Game.give_artifact(str(art.id)):
		Game.toast("%s  (+%dg)" % [str(art.get("name", "Relic")), gold_amt], Color(0.92, 0.78, 0.45))
	else:
		Game.toast("Coin, and a relic you already carry. (+%dg)" % gold_amt, Color(0.92, 0.78, 0.45))
