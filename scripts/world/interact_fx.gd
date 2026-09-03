extends Object

const Depth := preload("res://scripts/world/depth.gd")


static func build(host: Node3D) -> void:
	var kind: String = host.kind
	if kind == "crystal" or kind == "loadout_crystal":
		var mesh := MeshInstance3D.new()
		var pr := PrismMesh.new()
		pr.size = Vector3(0.55, 1.2, 0.55)
		mesh.mesh = pr
		mesh.position.y = 0.7
		var m := StandardMaterial3D.new()
		m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		m.albedo_color = Color(0.35, 0.9, 1.0)
		mesh.material_override = m
		host.mesh = mesh
		host.add_child(mesh)
		return
	if kind == "stairs":
		sprite(host, "res://assets/sprites/props/stairs.png", 1.1, 0.45)
		if host.spr == null:
			var mesh := MeshInstance3D.new()
			var box := BoxMesh.new()
			box.size = Vector3(1.1, 0.55, 1.1)
			mesh.mesh = box
			mesh.position.y = 0.28
			var m := StandardMaterial3D.new()
			m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
			m.albedo_color = Color(0.55, 0.45, 0.28)
			mesh.material_override = m
			host.mesh = mesh
			host.add_child(mesh)
		return
	if kind == "gate":
		sprite(host, "res://assets/sprites/props/gate.png", 1.6, 0.85)
		var body := StaticBody3D.new()
		body.collision_layer = 1
		body.collision_mask = 0
		host.body = body
		host.add_child(body)
		var cs := CollisionShape3D.new()
		var sh := BoxShape3D.new()
		sh.size = Vector3(1.2, 1.6, 0.4)
		cs.shape = sh
		cs.position.y = 0.8
		body.add_child(cs)
		return
	if kind == "plate":
		sprite(host, "res://assets/sprites/props/plate.png", 0.7, 0.08)
		return
	sprite(host, tex_path(kind), spr_h(kind), spr_y(kind))


static func tex_path(kind: String) -> String:
	match kind:
		"anvil":
			return "res://assets/sprites/props/anvil.png"
		"quest_board":
			return "res://assets/sprites/props/notice_board.png"
		"receptionist":
			return "res://assets/sprites/npcs/receptionist.png"
		"vendor":
			return "res://assets/sprites/npcs/vendor.png"
		"dumpster":
			return "res://assets/sprites/props/dumpster.png"
		"billboard":
			return "res://assets/sprites/props/sign.png"
		"quest_item":
			return "res://assets/sprites/props/chest.png"
		"shrine":
			return "res://assets/sprites/props/shrine.png"
		"campfire":
			return "res://assets/sprites/props/campfire.png"
		"shop":
			return "res://assets/sprites/npcs/shopkeep.png"
		"extract_gate":
			return "res://assets/sprites/props/extract_gate_on.png"
		"lever":
			return "res://assets/sprites/props/lever.png"
		"chest", "base_chest", "puzzle_chest":
			return "res://assets/sprites/props/chest.png"
	return "res://assets/props/sort_crate.png"


static func spr_h(kind: String) -> float:
	if kind == "extract_gate":
		return 1.7
	if kind.begins_with("clerk") or kind == "shop" or kind == "receptionist" or kind == "vendor":
		return 1.55
	if kind == "campfire":
		return 0.9
	if kind == "shrine":
		return 1.2
	return 0.85


static func spr_y(kind: String) -> float:
	if kind == "extract_gate":
		return 0.95
	if kind.begins_with("clerk") or kind == "shop" or kind == "receptionist" or kind == "vendor":
		return 0.78
	if kind == "plate":
		return 0.06
	return 0.48


static func sprite(host: Node3D, path: String, h: float, y: float) -> void:
	var spr := Sprite3D.new()
	spr.centered = true
	spr.shaded = false
	spr.billboard = BaseMaterial3D.BILLBOARD_FIXED_Y
	spr.alpha_cut = SpriteBase3D.ALPHA_CUT_OPAQUE_PREPASS
	spr.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	if ResourceLoader.exists(path):
		spr.texture = load(path)
		if host.kind == "extract_gate":
			spr.pixel_size = 3.0 / float(maxi(1, spr.texture.get_width()))
		else:
			spr.pixel_size = h / float(maxi(1, spr.texture.get_height()))
	spr.position.y = y
	host.spr = spr
	host.add_child(spr)
	Depth.apply(spr, host.position)


static func set_extract_tex(host: Node3D, on: bool) -> void:
	if host.spr == null:
		return
	var path := "res://assets/sprites/props/extract_gate_on.png" if on else "res://assets/sprites/props/extract_gate_off.png"
	if ResourceLoader.exists(path):
		host.spr.texture = load(path)
		host.spr.pixel_size = 3.0 / float(maxi(1, host.spr.texture.get_width()))


static func add_label(host: Node3D) -> void:
	var label := Label3D.new()
	label.position = Vector3(0.0, 1.55, 0.0)
	if host.kind == "plate":
		label.position.y = 0.7
	elif host.kind == "extract_gate":
		label.position.y = 2.05
	label.font_size = 36
	label.outline_size = 8
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.no_depth_test = true
	label.pixel_size = 0.011
	host.label = label
	host.add_child(label)
