extends RefCounted

## Item, equipment, projectile, resource, UI, and VFX. Recipe and attach sections stay skeletons on the record.

static func view(doc: Dictionary) -> Dictionary:
	return {
		"type": str(doc.get("type", "item")),
		"draw_scale": float(doc.get("draw_scale", 1)),
		"sheets": doc.get("sheets", []),
		"stats": doc.get("stats", {}),
	}
