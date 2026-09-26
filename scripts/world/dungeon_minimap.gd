extends Object

## Floor minimap + fog reveal. Zoom / pan stays in dungeon_map_act.gd.

const Gen := preload("res://scripts/dungeon/gen.gd")


static func cell_color(host: Node, x: int, y: int) -> Color:
	var w: int = host.data.w
	if host.visited[Gen.idx(x, y, w)] == 0:
		return Color(0.02, 0.02, 0.03, 1)
	if host.data.grid[Gen.idx(x, y, w)] == Gen.FLOOR:
		return Color(0.22, 0.24, 0.28)
	return Color(0.08, 0.08, 0.1)


static func paint_cell(host: Node, x: int, y: int) -> void:
	if host.map_img == null:
		return
	if x < 0 or y < 0 or x >= host.data.w or y >= host.data.h:
		return
	host.map_img.set_pixel(x, y, cell_color(host, x, y))


static func reveal_around(host: Node, c: Vector2i, rad: int) -> bool:
	var w: int = host.data.w
	var h: int = host.data.h
	var r2 := rad * rad
	var grew := false
	for y in range(maxi(0, c.y - rad), mini(h, c.y + rad + 1)):
		for x in range(maxi(0, c.x - rad), mini(w, c.x + rad + 1)):
			var dx := x - c.x
			var dy := y - c.y
			if dx * dx + dy * dy <= r2:
				var i := Gen.idx(x, y, w)
				if host.visited[i] == 0:
					host.visited[i] = 1
					grew = true
					paint_cell(host, x, y)
	return grew


static func make_map(host: Node) -> void:
	host.map_layer = CanvasLayer.new()
	host.map_layer.layer = 30
	host.map_layer.visible = false
	host.add_child(host.map_layer)
	var dim := ColorRect.new()
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.color = Color(0.02, 0.03, 0.05, 0.55)
	dim.gui_input.connect(func(ev: InputEvent) -> void: _map_input(host, ev))
	host.map_layer.add_child(dim)
	host.map_img = Image.create(int(host.data.w), int(host.data.h), false, Image.FORMAT_RGBA8)
	host.map_img.fill(Color(0.02, 0.02, 0.03, 1))
	host.map_tex = ImageTexture.create_from_image(host.map_img)
	host.map_rect = TextureRect.new()
	host.map_rect.texture = host.map_tex
	host.map_rect.stretch_mode = TextureRect.STRETCH_SCALE
	host.map_rect.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	host.map_rect.gui_input.connect(func(ev: InputEvent) -> void: _map_input(host, ev))
	host.map_layer.add_child(host.map_rect)
	host.set_meta("map_pc", Vector2i(-999, -999))
	redraw_map(host)
	var MapActS: GDScript = load("res://scripts/world/dungeon_map_act.gd") as GDScript
	MapActS.reset(host)


static func _map_input(host: Node, event: InputEvent) -> void:
	var LookS: GDScript = load("res://scripts/input/look_ctrl.gd") as GDScript
	LookS.note_event(event)
	var MapActS: GDScript = load("res://scripts/world/dungeon_map_act.gd") as GDScript
	if MapActS.handle_mouse(host, event):
		host.get_viewport().set_input_as_handled()


static func redraw_map(host: Node) -> void:
	if host.map_img == null:
		return
	var old: Vector2i = host.get_meta("map_pc", Vector2i(-999, -999))
	if old.x >= 0:
		paint_cell(host, old.x, old.y)
	dot(host, host.data.crystal, Color(0.3, 0.9, 1.0), true)
	dot(host, host.data.stairs, Color(0.95, 0.75, 0.25), true)
	var marked := false
	for o in host.data.get("openings", []):
		for raw in o.get("cells", []):
			dot(host, Vector2i(raw), Color(0.9, 0.2, 0.15), true)
			marked = true
	if not marked:
		dot(host, host.data.door, Color(0.9, 0.2, 0.15), true)
	for n in host.get_tree().get_nodes_in_group("interact"):
		if n is Node3D:
			var k := str(n.get("kind"))
			var cell := Vector2i(int((n as Node3D).global_position.x), int((n as Node3D).global_position.z))
			if k == "extract_gate" or k.begins_with("clerk"):
				dot(host, cell, Color(0.95, 0.82, 0.35), true)
			elif k == "shop":
				dot(host, cell, Color(0.55, 0.85, 1.0), true)
	if host.player:
		var pc := Vector2i(int(host.player.global_position.x), int(host.player.global_position.z))
		host.set_meta("map_pc", pc)
		dot(host, pc, Color(1, 1, 1), false)
	host.map_tex.update(host.map_img)


static func dot(host: Node, p: Vector2i, col: Color, need_seen := false) -> void:
	if p.x < 0 or p.y < 0 or p.x >= host.data.w or p.y >= host.data.h:
		return
	if need_seen and host.visited[Gen.idx(p.x, p.y, host.data.w)] == 0:
		return
	host.map_img.set_pixel(p.x, p.y, col)
