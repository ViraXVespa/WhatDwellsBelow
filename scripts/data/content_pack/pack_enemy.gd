extends RefCounted

## Enemy, sub-boss, and boss share this builder. Item drops stay a skeleton until that section is filled in.

static func view(doc: Dictionary) -> Dictionary:
	var sections: Variant = doc.get("sections", {})
	var items: Dictionary = {}
	if sections is Dictionary and sections.get("items", {}) is Dictionary:
		items = sections.get("items", {})
	return {
		"type": str(doc.get("type", "enemy")),
		"draw_scale": float(doc.get("draw_scale", 1)),
		"sheets": doc.get("sheets", []),
		"overlays": doc.get("paperdoll", []),
		"stats": doc.get("stats", {}),
		"items_skeleton": bool(items.get("skeleton", false)),
	}
