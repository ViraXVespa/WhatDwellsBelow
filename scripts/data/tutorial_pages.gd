extends RefCounted

## How-to-Play pages for the receptionist Ask? list. A new topic is one row here, one en.po title and body,
## and one row in tools/tutorial_shots.json. The picture is res://assets/ui/tutorial/<id>.png. A missing picture
## is an error.

const SHOT_DIR := "res://assets/ui/tutorial/"

const PAGES: Array[Dictionary] = [
	{"id": "forging", "title": "tutorial.forging.title", "body": "tutorial.forging.body"},
	{"id": "xp", "title": "tutorial.xp.title", "body": "tutorial.xp.body"},
	{"id": "extraction", "title": "tutorial.extraction.title", "body": "tutorial.extraction.body"},
	{"id": "skills", "title": "tutorial.skills.title", "body": "tutorial.skills.body"},
	{"id": "gear", "title": "tutorial.gear.title", "body": "tutorial.gear.body"},
	{"id": "combat", "title": "tutorial.combat.title", "body": "tutorial.combat.body"},
	{"id": "gathering", "title": "tutorial.gathering.title", "body": "tutorial.gathering.body"},
	{"id": "loadout", "title": "tutorial.loadout.title", "body": "tutorial.loadout.body"},
	{"id": "inventory", "title": "tutorial.inventory.title", "body": "tutorial.inventory.body"},
	{"id": "recap", "title": "tutorial.recap.title", "body": "tutorial.recap.body"},
]

static func shot_path(id: String) -> String:
	return SHOT_DIR + id + ".png"

static func page_of(id: String) -> Dictionary:
	for row: Dictionary in PAGES:
		if str(row["id"]) == id:
			return row
	push_error("tutorial page missing: " + id)
	assert(false, "tutorial page missing: " + id)
	return {}

static func shot_tex(id: String) -> Texture2D:
	var path: String = shot_path(id)
	if not ResourceLoader.exists(path):
		push_error("tutorial screenshot missing: " + path + " (python tools/tutorial_shots.py --run, then copy into assets/ui/tutorial/)")
		assert(false, "tutorial screenshot missing: " + path)
		return null
	var tex: Texture2D = load(path) as Texture2D
	if tex == null:
		push_error("tutorial screenshot failed to load: " + path)
		assert(false, "tutorial screenshot failed to load: " + path)
	return tex
