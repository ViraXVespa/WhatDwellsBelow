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
	var LayoutS = load("res://scripts/world/camp/layout.gd")
	var Build = load("res://scripts/world/camp_build.gd")
	var layout = LayoutS.on_camp(camp)
	layout.ensure_tree()
	Build.realize_editor(camp, layout)
	var HubLight = load("res://scripts/graphics/light_rt.gd")
	HubLight.rebuild_hub(
		int(layout.aabb_x0()),
		int(layout.aabb_z0()),
		int(layout.aabb_x1()),
		int(layout.aabb_z1()),
		Vector2(layout.spot_pos("Crystal").x, layout.spot_pos("Crystal").z),
		layout
	)
	HubLight.save_hub_bake()
	HubLight.rebuild_hub(
		int(layout.aabb_x0()),
		int(layout.aabb_z0()),
		int(layout.aabb_x1()),
		int(layout.aabb_z1()),
		Vector2(layout.spot_pos("Crystal").x, layout.spot_pos("Crystal").z),
		layout
	)
	HubLight.save_hub_bake()
	host.get_tree().quit()
