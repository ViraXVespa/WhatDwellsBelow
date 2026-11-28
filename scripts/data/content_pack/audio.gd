extends RefCounted

static func cues(doc: Dictionary) -> Array:
	var rows: Variant = doc.get("audio", [])
	if rows is Array:
		return rows
	return []
