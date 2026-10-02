extends SceneTree

func _init() -> void:
	var packed = load("res://scenes/camp.tscn")
	if packed == null:
		push_error("bake_camp: camp.tscn missing")
		quit()
		return
	var camp = packed.instantiate()
	var LayoutS = load("res://scripts/world/camp/layout.gd")
	var Build = load("res://scripts/world/camp_build.gd")
	var layout = LayoutS.on_camp(camp)
	layout.ensure_tree()
	Build.realize_editor(camp, layout)
	var gen = camp.get_node_or_null("Generated")
	if gen:
		_mark_owner(gen, camp)
	camp.remove_meta("wdb_layout")  # realize_editor tags it; packing would bake a detached Layout copy into camp.tscn that leaks on every instantiate
	if gen:
		gen.remove_meta("wdb_layout")
	var out = PackedScene.new()
	var err = out.pack(camp)
	if err != OK:
		push_error("bake_camp: pack failed %s" % str(err))
		quit()
		return
	err = ResourceSaver.save(out, "res://scenes/camp.tscn")
	if err != OK:
		push_error("bake_camp: save failed %s" % str(err))
	quit()

func _mark_owner(n, own) -> void:
	n.owner = own
	var i = 0
	while i < n.get_child_count():
		_mark_owner(n.get_child(i), own)
		i += 1
