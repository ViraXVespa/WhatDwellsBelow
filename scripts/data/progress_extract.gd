extends Object

const ProgressQuest := preload("res://scripts/data/progress_quest.gd")
const Rules := preload("res://scripts/data/gear_rules.gd")


static func _full_mail(role: String) -> bool:
	return role == "" or role == "patty" or role == "gate"


static func extractable(p: Object, role: String = "") -> Array:
	var out: Array = []
	var gather: bool = _full_mail(role) or role == "gather"
	var misc: bool = _full_mail(role) or role == "misc"
	if gather:
		if App.ore > 0:
			out.append({"kind": "ore", "name": "Ore", "n": App.ore})
		if App.wood > 0:
			out.append({"kind": "wood", "name": "Wood", "n": App.wood})
		if p.root > 0:
			out.append({"kind": "root", "name": "Root", "n": p.root})
	if misc:
		if App.gold > 0:
			out.append({"kind": "gold", "name": "Gold", "n": App.gold})
		for it: Variant in p.bag:
			if it.get("extract", true) and str(it.kind) != "artifact" and not bool(it.get("hold", false)):
				out.append(it)
	return out


static func _mail_item(p: Object, it: Dictionary) -> String:
	var special := Rules.handle_mail(p, it)
	if special != "":
		return special
	p.bank_items.append(it)
	App.extracted = true
	p.mailed_names.append(str(it.name))
	return "Sent " + str(it.name)


static func extract_all(p: Object, role: String) -> String:
	var g: int = 0
	var o: int = 0
	var w: int = 0
	var r: int = 0
	var items: int = 0
	if _full_mail(role) or role == "gather":
		o = App.ore
		w = App.wood
		r = p.root
		App.bank_ore += App.ore
		App.bank_wood += App.wood
		App.bank_root += p.root
		ProgressQuest.quest_extract_ore(p, App.ore)
		App.ore = 0
		App.wood = 0
		p.root = 0
		p.mailed_ore += o
		p.mailed_wood += w
		p.mailed_root += r
	if _full_mail(role) or role == "misc":
		g = App.gold
		App.bank_gold += App.gold
		App.gold = 0
		p.mailed_gold += g
		var keep: Array = []
		for it: Variant in p.bag:
			if it.get("extract", true) and str(it.kind) != "artifact" and not bool(it.get("hold", false)):
				_mail_item(p, it)
				items += 1
			else:
				keep.append(it)
		p.bag = keep
	App.extracted = g + o + w + r + items > 0
	if App.extracted:
		App.toast("Sent to the surface.")
		if App.tel:
			App.tel.note_extract(g, o, w)
			App.tel.forge_n = p.forge_count
	return "Banked %dg, %d ore, %d wood, %d root, %d items." % [g, o, w, r, items]


static func extract_one(p: Object, it: Dictionary, role: String) -> String:
	var k: String = str(it.get("kind", ""))
	if k == "gold" and (_full_mail(role) or role == "misc"):
		App.bank_gold += App.gold
		var ng: int = App.gold
		App.gold = 0
		App.extracted = true
		p.mailed_gold += ng
		return "Sent %dg." % ng
	if k == "ore" and (_full_mail(role) or role == "gather"):
		ProgressQuest.quest_extract_ore(p, App.ore)
		App.bank_ore += App.ore
		var no: int = App.ore
		App.ore = 0
		App.extracted = true
		p.mailed_ore += no
		return "Sent %d ore." % no
	if k == "wood" and (_full_mail(role) or role == "gather"):
		App.bank_wood += App.wood
		var nw: int = App.wood
		App.wood = 0
		App.extracted = true
		p.mailed_wood += nw
		return "Sent %d wood." % nw
	if k == "root" and (_full_mail(role) or role == "gather"):
		var nr: int = p.root
		App.bank_root += p.root
		p.root = 0
		App.extracted = true
		p.mailed_root += nr
		return "Sent %d root." % nr
	if role == "gather":
		return "This gate takes ore, wood, and root."
	if it.has("from_slot"):
		return "Unequip that first."
	if it.has("uid"):
		var got: Dictionary = p.remove_uid(int(it.uid))
		if got.is_empty():
			return "Gone."
		if str(got.kind) == "artifact" or bool(got.get("hold", false)):
			if str(got.kind) == "artifact":
				p.add_to_bag(got)
				return "Artifacts cannot be mailed."
			p.add_to_bag(got)
			return "Forged holds stay with you."
		return _mail_item(p, got)
	return "Nothing."


static func withdraw_bank_consumables(p: Object) -> void:
	var keep: Array = []
	for it: Variant in p.bank_items:
		var k: String = str(it.get("kind", ""))
		if k == "food":
			var cur: Dictionary = p.slots.get("food", {})
			if cur.is_empty():
				p.slots["food"] = it
			elif str(cur.get("food", "")) == str(it.get("food", "")):
				cur.stack = int(cur.get("stack", 0)) + int(it.get("stack", 1))
				p.slots["food"] = cur
			else:
				keep.append(it)
		elif k == "potion":
			if p.slots.get("potion", {}).is_empty():
				it.stack = 1
				if int(it.get("charge_max", 0)) <= 0:
					it.charge_max = maxi(2, int(it.get("charges", 2)))
				if int(it.get("charges", 0)) <= 0:
					it.charges = int(it.charge_max)
				p.slots["potion"] = it
			else:
				keep.append(it)
		else:
			keep.append(it)
	p.bank_items = keep
