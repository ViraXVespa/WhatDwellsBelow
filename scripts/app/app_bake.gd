extends Object

## Split from app.gd: _bake_camp (realizes Generated in memory, rebakes hub_light.png; never saves camp.tscn).

static func _bake_camp(host: Node) -> void:
	var packed = load(host.CAMP_SCENE)
	if packed == null:
		push_error("bake_camp: camp.tscn missing")
		host.get_tree().quit()
		return
	var camp = packed.instantiate()
	camp.set_script(null)  # no live _ready; the node must be in the tree so global transforms (shadow projection) are valid
	host.get_tree().root.add_child(camp)
	(load("res://scripts/world/camp_build.gd") as GDScript).bake_light(camp)
	host.get_tree().quit()
