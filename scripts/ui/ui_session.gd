extends Object

## Pause tree + App.ui_open (+ optional PromptView.footer). Brief item 4.
## Every menu layer that opens through here fades in and out (MenuFade; Settings > UI > Menu transitions).

const MenuFade := preload("res://scripts/ui/menu_fade.gd")

static func status(host: Node, msg: String) -> void:
	if host.status:
		host.status.text = msg
	App.sfx("ui")

static func open(host: Node) -> void:
	App.ui_open = true
	host.get_tree().paused = true
	if host is CanvasLayer:
		MenuFade.fade_in(host as CanvasLayer)

## free_after: the layer is freed once it has faded out (crystal map), instead of by the caller.
static func close(host: Node, free_after: bool = false) -> void:
	App.ui_open = false
	host.get_tree().paused = false
	App.Boot.release_focus_once(App)
	if host is CanvasLayer:
		MenuFade.fade_out(host as CanvasLayer, free_after)
	elif free_after:
		host.queue_free()
