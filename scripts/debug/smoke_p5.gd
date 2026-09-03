extends Object


static func tree(host: Node) -> SceneTree:
	return host.get_tree()


static func quit_in(host: Node, sec: float) -> void:
	tree(host).create_timer(sec).timeout.connect(func(): tree(host).quit())


static func p5(host: Node) -> void:
	var player: Variant = host.get("player")
	var ui: Variant = host.get("ui")
	var counts: Dictionary = host.get("counts")
	printerr("P5: res=" + ProjectSettings.globalize_path("res://"))
	printerr("P5: mine_time=" + str(App.bal.mine_time) + " wood_time=" + str(App.bal.wood_time))
	printerr("P5: mine_hits=" + str(App.bal.mine_hits) + " wood_hits=" + str(App.bal.wood_hits))
	printerr("P5: mine_chance=" + str(App.bal.mine_chance) + " wood_chance=" + str(App.bal.wood_chance))
	printerr("P5: counts=" + str(counts))
	var kinds: PackedStringArray = PackedStringArray()
	for n: Node in tree(host).get_nodes_in_group("interact"):
		var k: String = str(n.get("kind"))
		if kinds.find(k) < 0:
			kinds.append(k)
	printerr("P5: interact_kinds=" + ", ".join(kinds))
	printerr("P5: gather=" + str(tree(host).get_nodes_in_group("gather").size()))
	printerr("P5: breakables=" + str(tree(host).get_nodes_in_group("breakables").size()))
	printerr("P5: gates=" + str(tree(host).get_nodes_in_group("gates").size()))
	printerr("P5: plates=" + str(tree(host).get_nodes_in_group("plates").size()))
	App.bal.mine_chance = 1.0
	App.bal.wood_chance = 1.0
	var mine_n: Node = null
	var wood_n: Node = null
	for n2: Node in tree(host).get_nodes_in_group("gather"):
		if str(n2.get("kind")) == "mine" and mine_n == null:
			mine_n = n2
		if str(n2.get("kind")) == "wood" and wood_n == null:
			wood_n = n2
	var ore0: int = App.ore
	var wood0: int = App.wood
	var mine_hits: int = 0
	var wood_hits: int = 0
	if mine_n and mine_n.has_method("strike"):
		var r1: Dictionary = mine_n.strike()
		mine_hits = 1
		printerr("P5: mine_strike ok=" + str(r1.get("ok", false)) + " interval=" + str(mine_n.get("interval")))
	if wood_n and wood_n.has_method("strike"):
		var r2: Dictionary = wood_n.strike()
		wood_hits = 1
		printerr("P5: wood_strike ok=" + str(r2.get("ok", false)) + " interval=" + str(wood_n.get("interval")))
	printerr("P5: ore_delta=" + str(App.ore - ore0) + " wood_delta=" + str(App.wood - wood0))
	printerr("P5: nodes_ok=" + str(mine_hits == 1 and wood_hits == 1 and is_equal_approx(float(mine_n.get("interval")), 2.4) and is_equal_approx(float(wood_n.get("interval")), 1.2)))
	var smashed: int = 0
	for b: Node in tree(host).get_nodes_in_group("breakables"):
		if str(b.get("kind")) == "crack":
			continue
		if b.has_method("take_hit"):
			b.take_hit(99.0, Vector2.DOWN, false)
			smashed += 1
			break
	printerr("P5: smash=" + str(smashed) + " gold=" + str(App.gold))
	var shrine: Node = null
	var fire: Node = null
	var clerk: Node = null
	var shop: Node = null
	var lever: Node = null
	var chest: Node = null
	var crack: Node = null
	for n3: Node in tree(host).get_nodes_in_group("interact"):
		var k3: String = str(n3.get("kind"))
		if k3 == "shrine" and shrine == null:
			shrine = n3
		if k3 == "campfire" and fire == null:
			fire = n3
		if (k3 == "extract_gate" or k3.begins_with("clerk")) and clerk == null:
			clerk = n3
		if k3 == "shop" and shop == null:
			shop = n3
		if k3 == "lever" and lever == null:
			lever = n3
		if k3.ends_with("chest") and chest == null:
			chest = n3
	for b2: Node in tree(host).get_nodes_in_group("breakables"):
		if str(b2.get("kind")) == "crack":
			crack = b2
			break
	if shrine:
		shrine.interact(player)
	printerr("P5: shrine_t=" + str(App.shrine_t) + " shrine_ok=" + str(App.shrine_t > 0.0))
	var hp0: float = float(player.get("hp")) if player else 0.0
	if player:
		player.set("hp", hp0 * 0.4)
	if fire:
		fire.interact(player)
	var hp1: float = float(player.get("hp")) if player else 0.0
	printerr("P5: campfire hp " + str(hp0) + "->" + str(hp1) + " ok=" + str(hp1 > hp0 * 0.4))
	App.ore = 4
	App.wood = 3
	App.gold = 30
	if clerk:
		clerk.interact(player)
	if ui:
		ui._extract_all()
		ui.close_ui()
	printerr("P5: extract bank_g=" + str(App.bank_gold) + " bank_o=" + str(App.bank_ore) + " bank_w=" + str(App.bank_wood) + " extracted=" + str(App.extracted))
	App.gold = 80
	if shop:
		shop.interact(player)
	if ui:
		ui._buy_snack()
		if shop and shop.stock.size() > 0:
			var a: Dictionary = shop.stock[0]
			ui._buy_art(str(a.id), str(a.name))
		ui.close_ui()
	printerr("P5: shop artifacts=" + str(App.run_artifacts.size()) + " snack_buys=" + str(App.shop_buys))
	var gate_open0: bool = false
	for g: Node in tree(host).get_nodes_in_group("gates"):
		gate_open0 = bool(g.get("open"))
	if lever:
		lever.interact(player)
	var gate_open1: bool = false
	for g2: Node in tree(host).get_nodes_in_group("gates"):
		gate_open1 = bool(g2.get("open"))
	printerr("P5: lever_gate " + str(gate_open0) + "->" + str(gate_open1))
	if crack and crack.has_method("take_hit"):
		for i: int in 10:
			if is_instance_valid(crack):
				crack.take_hit(40.0, Vector2.DOWN, false)
	printerr("P5: crack_dead=" + str(crack == null or not is_instance_valid(crack) or bool(crack.get("dead"))))
	if chest:
		chest.interact(player)
	printerr("P5: chest_arts=" + str(App.run_artifacts.size()))
	var present: bool = (
		int(counts.get("mine", 0)) > 0
		and int(counts.get("wood", 0)) > 0
		and int(counts.get("break", 0)) > 0
		and int(counts.get("extract_gate", 0)) > 0
		and int(counts.get("shrine", 0)) > 0
		and int(counts.get("campfire", 0)) > 0
		and int(counts.get("lever", 0)) > 0
		and int(counts.get("gate", 0)) > 0
		and int(counts.get("plate", 0)) > 0
		and int(counts.get("crack", 0)) > 0
		and int(counts.get("shop", 0)) > 0
	)
	printerr("P5: present_ok=" + str(present))
	printerr("P5: extract_ok=" + str(App.extracted and App.bank_ore >= 4))
	quit_in(host, 0.35)
