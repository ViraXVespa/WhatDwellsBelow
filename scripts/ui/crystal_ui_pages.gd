extends Object

## Crystal UI page bodies. Host is scripts/ui/crystal_ui.gd.

const Net := preload("res://scripts/ui/crystal_ui_pages_net.gd")
const Local := preload("res://scripts/ui/crystal_ui_pages_local.gd")
const Floors := preload("res://scripts/ui/crystal_ui_pages_floors.gd")


static func net_tabs(host, box: VBoxContainer) -> void:
	Net.net_tabs(host, box)


static func cycle_net(host, dir: int) -> void:
	Net.cycle_net(host, dir)


static func page_root(host) -> void:
	Net.page_root(host)


static func go_local(host) -> void:
	Net.go_local(host)


static func go_floors(host) -> void:
	Net.go_floors(host)


static func page_local(host) -> void:
	Local.page_local(host)


static func page_floors(host) -> void:
	Floors.page_floors(host)


static func open_band(host, lo: int, hi: int) -> void:
	Floors.open_band(host, lo, hi)


static func list_floors(host, box: VBoxContainer, lo: int, hi: int, deepest: int) -> void:
	Floors.list_floors(host, box, lo, hi, deepest)
