extends Object

const ThemeS := preload("res://scripts/ui/theme.gd")
const View := preload("res://scripts/ui/split_menu_view.gd")

const NODE_NAME := "confirm_dlg"


static func is_open(parent: Node) -> bool:
	var n: Node = parent.get_node_or_null(NODE_NAME)
	return n != null and n.visible


static func close(parent: Node) -> void:
	var n: Node = parent.get_node_or_null(NODE_NAME)
	if n:
		n.queue_free()


static func open(parent: Node, title: String, body: String, on_yes: Callable) -> void:
	close(parent)
	var root := Control.new()
	root.name = NODE_NAME
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_STOP
	root.process_mode = Node.PROCESS_MODE_ALWAYS
	root.z_index = 80
	parent.add_child(root)
	var dim := ColorRect.new()
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.color = Color(0.03, 0.02, 0.02, 0.72)
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	root.add_child(dim)
	var panel := ColorRect.new()
	panel.color = Color(0.13, 0.1, 0.08, 0.98)
	panel.position = Vector2(560, 280)
	panel.size = Vector2(800, 360)
	root.add_child(panel)
	var edge := ColorRect.new()
	edge.color = Color(0.55, 0.42, 0.22, 1)
	edge.position = Vector2(560, 280)
	edge.size = Vector2(800, 8)
	root.add_child(edge)
	var cap: Label = ThemeS.lab(title, 28, Color(0.95, 0.86, 0.55))
	cap.position = Vector2(592, 308)
	cap.size = Vector2(736, 40)
	root.add_child(cap)
	var msg: Label = ThemeS.lab(body, 20, Color(0.86, 0.8, 0.7))
	msg.position = Vector2(592, 360)
	msg.size = Vector2(736, 120)
	msg.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	root.add_child(msg)
	var yes: Button = ThemeS.btn("Confirm", func() -> void:
		close(parent)
		if on_yes.is_valid():
			on_yes.call()
	)
	yes.position = Vector2(592, 520)
	yes.size = Vector2(340, 52)
	root.add_child(yes)
	var no: Button = ThemeS.btn("Cancel", func() -> void: close(parent))
	no.position = Vector2(980, 520)
	no.size = Vector2(340, 52)
	root.add_child(no)
	View.wire_vert([yes, no])
	yes.focus_neighbor_left = no.get_path()
	yes.focus_neighbor_right = no.get_path()
	no.focus_neighbor_left = yes.get_path()
	no.focus_neighbor_right = yes.get_path()
	yes.grab_focus()
	root.gui_input.connect(func(event: InputEvent) -> void:
		if event.is_action_pressed("ui_cancel") or event.is_action_pressed("pause"):
			close(parent)
			root.accept_event()
	)
	App.sfx("ui")
