extends Object

## Best-effort depth from implied XZ position under the orthographic camera.
## Camera sits in +Z looking toward -Z, so larger Z is nearer the viewer.

static func apply(node: GeometryInstance3D, world: Vector3) -> void:
	# called only from present-after-move paths
	if node == null:
		return
	var off := world.z * 6.0 + world.x * 0.04
	if absf(node.sorting_offset - off) < 0.01:
		return
	node.sorting_offset = off
