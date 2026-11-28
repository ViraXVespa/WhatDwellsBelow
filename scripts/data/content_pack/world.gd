extends RefCounted

## Biome, building, and decoration. Layout and interior sections stay skeletons on the record.

static func view(doc: Dictionary) -> Dictionary:
	return {
		"type": str(doc.get("type", "decoration")),
		"draw_scale": float(doc.get("draw_scale", 1)),
		"sheets": doc.get("sheets", []),
	}
