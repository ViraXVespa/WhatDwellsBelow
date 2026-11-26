extends RefCounted

## Character export: one body sheet plus overlay quads. The frame clock stays outside this file.

static func view(doc: Dictionary) -> Dictionary:
	return {
		"type": "character",
		"draw_scale": float(doc.get("draw_scale", 1)),
		"sheets": doc.get("sheets", []),
		"overlays": doc.get("paperdoll", []),
	}
