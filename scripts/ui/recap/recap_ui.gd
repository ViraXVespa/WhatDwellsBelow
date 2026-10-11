extends Object

## Recap panel chrome.

const ScrollBox := preload("res://scripts/ui/scroll_box.gd")
const Plate := preload("res://scripts/ui/plate_chrome.gd")

static func build(host: CanvasLayer) -> void:
	host.layer = 70
	host.visible = false
	host.process_mode = Node.PROCESS_MODE_ALWAYS
	Plate.overlay(host, Vector2(220, 40), Vector2(1480, 1000))
	ScrollBox.build(host, Vector2(244, 72), Vector2(1432, 940), 8)
