extends Object

const P7 := preload("res://scripts/debug/smoke_p7.gd")
const P8 := preload("res://scripts/debug/smoke_p8.gd")
const P9 := preload("res://scripts/debug/smoke_p9.gd")

static var enter_flag: bool:
	get:
		return P8.enter_flag
	set(v):
		P8.enter_flag = v


static func tree(host: Node) -> SceneTree:
	return host.get_tree()


static func p7(host: Node) -> void:
	P7.p7(host)


static func p8(host: Node) -> void:
	P8.p8(host)


static func p9(host: Node) -> void:
	P9.p9(host)
