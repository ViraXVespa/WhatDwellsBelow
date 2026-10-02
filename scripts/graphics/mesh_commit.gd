extends Object

## One triangle-list surface from parallel buffers. Skips the surface when there are no verts;
## `norms` / `uv2` may be null to leave that slot unset.

static func commit(verts: PackedVector3Array, norms: Variant, uvs: PackedVector2Array, indices: PackedInt32Array, uv2: Variant = null) -> ArrayMesh:
	var mesh: ArrayMesh = ArrayMesh.new()
	if verts.is_empty():
		return mesh
	var arrays: Array = []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = verts
	if norms != null:
		arrays[Mesh.ARRAY_NORMAL] = norms
	arrays[Mesh.ARRAY_TEX_UV] = uvs
	if uv2 != null:
		arrays[Mesh.ARRAY_TEX_UV2] = uv2
	arrays[Mesh.ARRAY_INDEX] = indices
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return mesh
