extends Object

## Split from app.gd: _bake_camp, _mark_bake_owner.

static func _bake_camp(host: Node) -> void:
	var packed = load(host.CAMP_SCENE)
	if packed == null:
		push_error("bake_camp: camp.tscn missing")
		host.get_tree().quit()
		return
	var camp = packed.instantiate()
	var LayoutS = load("res://scripts/world/camp/camp_layout.gd")
	var Build = load("res://scripts/world/camp_build/camp_build.gd")
	var layout = LayoutS.on_camp(camp)
	layout.ensure_tree()
	Build.realize_editor(camp, layout)
	var HubLight = load("res://scripts/graphics/light_rt/light_rt.gd")
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
	var gen = camp.get_node_or_null("Generated")
	if gen:
		_mark_bake_owner(host, gen, camp)
	var out = PackedScene.new()
	var err = out.pack(camp)
	if err != OK:
		push_error("bake_camp: pack failed %s" % str(err))
		host.get_tree().quit()
		return
	err = ResourceSaver.save(out, host.CAMP_SCENE)
	if err != OK:
		push_error("bake_camp: save failed %s" % str(err))
	host.get_tree().quit()

static func _mark_bake_owner(host: Node, n, own) -> void:
	n.owner = own
	var i = 0
	while i < n.get_child_count():
		_mark_bake_owner(host, n.get_child(i), own)
		i += 1
