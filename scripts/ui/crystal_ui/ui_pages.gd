extends Object

## Crystal UI page bodies. Host is scripts/ui/crystal_ui.gd.

const Net := preload("res://scripts/ui/crystal_ui/pages_net.gd")
const Local := preload("res://scripts/ui/crystal_ui/pages_local.gd")
const Floors := preload("res://scripts/ui/crystal_ui/pages_floors.gd")

static func cycle_net(host, dir: int) -> void:
	Net.cycle_net(host, dir)

static func page_root(host) -> void:
	Net.page_root(host)

static func page_local(host) -> void:
	Local.page_local(host)

static func page_floors(host) -> void:
	Floors.page_floors(host)
