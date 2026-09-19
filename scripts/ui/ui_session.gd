extends Object

## Pause tree + App.ui_open (+ optional PromptView.footer). Brief item 4.

const PromptView := preload("res://scripts/ui/prompt_view.gd")


static func open(host: Node) -> void:
	App.ui_open = true
	host.get_tree().paused = true


static func close(host: Node) -> void:
	App.ui_open = false
	host.get_tree().paused = false


static func open_with_footer(host: CanvasLayer, extra: Array = []) -> void:
	open(host)
	PromptView.footer(host, extra)
