extends Object

const A := preload("res://scripts/data/balance/schema_a.gd")
const B := preload("res://scripts/data/balance/schema_b.gd")

static func rows() -> Array:
	var out: Array = []
	out.append_array(A.rows())
	out.append_array(B.rows())
	return out
