extends Object

## Shared wipe-children loop (design/reuse-map.md Brief 1).


static func wipe(n: Node) -> void:
	while n.get_child_count() > 0:
		var c: Node = n.get_child(0)
		n.remove_child(c)
		c.queue_free()
