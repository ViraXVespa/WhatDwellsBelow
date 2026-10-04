extends Object

## Recap panel chrome.

const ScrollBox := preload("res://scripts/ui/scroll_box.gd")
const Plate := preload("res://scripts/ui/plate_chrome.gd")

static func build(host: CanvasLayer) -> void:
	host.layer = 70
	host.visible = false
	host.process_mode = Node.PROCESS_MODE_ALWAYS
	var dim := ColorRect.new()
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.color = Plate.DIM
	host.add_child(dim)
	var panel := ColorRect.new()
	panel.color = Plate.PLATE
	panel.position = Vector2(220, 40)
	panel.size = Vector2(1480, 1000)
	host.add_child(panel)
	var edge := ColorRect.new()
	edge.color = Plate.EDGE
	edge.position = Vector2(220, 40)
	edge.size = Vector2(1480, Plate.EDGE_H)
	host.add_child(edge)
	ScrollBox.build(host, Vector2(244, 72), Vector2(1432, 940), 8)
