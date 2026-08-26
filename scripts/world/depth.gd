extends Object

## Best-effort depth from implied XZ position under the orthographic camera.
## Camera sits in +Z looking toward -Z, so larger Z is nearer the viewer.


static func apply(node: GeometryInstance3D, world: Vector3) -> void:
	if node == null:
		return
	node.sorting_offset = world.z * 6.0 + world.x * 0.04
