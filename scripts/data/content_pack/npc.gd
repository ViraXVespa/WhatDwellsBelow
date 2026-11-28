extends RefCounted

static func view(doc: Dictionary) -> Dictionary:
	return {
		"type": "npc",
		"draw_scale": float(doc.get("draw_scale", 1)),
		"sheets": doc.get("sheets", []),
		"dialog": doc.get("dialog", []),
	}
