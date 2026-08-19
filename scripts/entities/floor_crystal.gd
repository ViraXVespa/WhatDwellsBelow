class_name FloorCrystal
extends Interactable

var destinations: Array = []


func _ready() -> void:
	super._ready()
	prompt = "Floor crystal"
	var spr := Sprite2D.new()
	spr.texture = Art.solid(Vector2i(44, 64), Color(0.35, 0.85, 0.9))
	add_child(spr)


func get_prompt() -> String:
	if Game.run == null:
		return "Crystal"
	var deeper := []
	for f in range(Game.run.current_floor + 1, Game.save.deepest_floor + 1):
		deeper.append(f)
	if deeper.is_empty():
		return "Crystal (no deeper memory)"
	return "Crystal: skip to floor %d" % deeper[0]


func interact(_player: Node) -> void:
	if Game.run == null:
		return
	var dest := Game.run.current_floor + 1
	if dest > Game.save.deepest_floor:
		return
	if dest == Game.run.current_floor:
		return
	Game.enter_floor(dest)
