class_name LootStash
extends Interactable

var opened := false
var rng := RandomNumberGenerator.new()


func _ready() -> void:
	super._ready()
	rng.randomize()
	prompt = "Search stash"
	var tex := Art.load_tex("res://assets/sprites/props/chest.png")
	if tex == null:
		tex = Art.chest(Vector2i(48, 40))
	add_child(Art.make_sprite(tex, 0.78))


func get_prompt() -> String:
	return "Empty stash" if opened else "Search stash"


func interact(_player: Node) -> void:
	if opened:
		return
	opened = true
	prompt = "Empty stash"
	modulate = Color(0.45, 0.45, 0.48)
	var bits: PackedStringArray = []
	var gold_amt := rng.randi_range(10, 32)
	Game.add_run_gold(gold_amt)
	bits.append("%dg" % gold_amt)
	if rng.randf() < 0.55:
		var ore := rng.randi_range(1, 4)
		if Game.add_to_bag(ItemData.make_ore(ore)):
			bits.append("%d ore" % ore)
		else:
			bits.append("ore (bag full)")
	if rng.randf() < 0.32:
		var fam := "great_axe" if rng.randf() < 0.6 else "pickaxe"
		var gear := LootGen.roll_gear(fam, rng)
		if rng.randf() < 0.25:
			gear.rarity = ItemData.Rarity.GREEN
		if Game.add_to_bag(gear):
			bits.append(gear.full_name())
		else:
			bits.append("gear (bag full)")
	_toast("Stash: " + ", ".join(bits))


func _toast(text: String) -> void:
	for c in get_tree().root.get_children():
		if c.name == "ToastLayer":
			c.queue_free()
	var layer := CanvasLayer.new()
	layer.name = "ToastLayer"
	layer.layer = 50
	var lab := Label.new()
	lab.text = text
	lab.position = Vector2(360, 120)
	lab.size = Vector2(1200, 56)
	lab.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lab.add_theme_font_size_override("font_size", 26)
	lab.add_theme_color_override("font_color", Color(1.0, 0.86, 0.35))
	lab.add_theme_color_override("font_outline_color", Color(0.05, 0.05, 0.08))
	lab.add_theme_constant_override("outline_size", 6)
	layer.add_child(lab)
	get_tree().root.add_child(layer)
	get_tree().create_timer(2.4).timeout.connect(layer.queue_free)
