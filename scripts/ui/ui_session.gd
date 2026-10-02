extends Object

## Pause tree + App.ui_open (+ optional PromptView.footer). Brief item 4.

const PromptView := preload("res://scripts/ui/prompt_view.gd")

## Status line text (if the host has one) plus the UI click.
static func status(host: Node, msg: String) -> void:
	if host.status:
		host.status.text = msg
	App.sfx("ui")

static func open(host: Node) -> void:
	App.ui_open = true
	host.get_tree().paused = true

static func close(host: Node) -> void:
	App.ui_open = false
	host.get_tree().paused = false
