extends Object

## Recap panel chrome.

const ScrollBox := preload("res://scripts/ui/scroll_box.gd")

static func build(host: CanvasLayer) -> void:
	host.layer = 70
	host.visible = false
	host.process_mode = Node.PROCESS_MODE_ALWAYS
	var dim := ColorRect.new()
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.color = Color(0.04, 0.03, 0.03, 0.92)
	host.add_child(dim)
	var panel := ColorRect.new()
	panel.color = Color(0.12, 0.09, 0.07, 0.96)
	panel.position = Vector2(220, 40)
	panel.size = Vector2(1480, 1000)
	host.add_child(panel)
	var edge := ColorRect.new()
	edge.color = Color(0.55, 0.42, 0.22, 1)
	edge.position = Vector2(220, 40)
	edge.size = Vector2(1480, 8)
	host.add_child(edge)
	ScrollBox.build(host, Vector2(244, 72), Vector2(1432, 940), 8)
