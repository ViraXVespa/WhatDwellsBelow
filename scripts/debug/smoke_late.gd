extends Object

const P5 := preload("res://scripts/debug/smoke_p5.gd")
const P6 := preload("res://scripts/debug/smoke_p6.gd")
const P79 := preload("res://scripts/debug/smoke_p79.gd")


static func tree(host: Node) -> SceneTree:
	return host.get_tree()


static func quit_in(host: Node, sec: float) -> void:
	tree(host).create_timer(sec).timeout.connect(func(): tree(host).quit())


static func p5(host: Node) -> void:
	P5.p5(host)


static func p6(host: Node) -> void:
	P6.p6(host)


static func p7(host: Node) -> void:
	P79.p7(host)


static func p8(host: Node) -> void:
	P79.p8(host)


static func p9(host: Node) -> void:
	P79.p9(host)
