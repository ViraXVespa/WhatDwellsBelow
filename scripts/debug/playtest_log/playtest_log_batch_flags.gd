extends Object

static func _flags(events: Array) -> PackedStringArray:
	var out: PackedStringArray = PackedStringArray()
	var spin_n: int = 0
	var mis_n: int = 0
	var hold_enemy_s: float = 0.0
	var hold_t0: float = -1.0
	var gather_busy: int = 0
	var gather_n: int = 0
	var prev: Array = []
	var prev2: Array = []
	var spin_run: int = 0
	for ev: Variant in events:
		if not (ev is Dictionary):
			continue
		var kind: String = str(ev.get("ev", ""))
		if kind == "step":
			if ev.get("mis") == 1:
				mis_n += 1
			var cell: Variant = ev.get("cell", [])
			if cell is Array and (cell as Array).size() >= 2:
				var c: Array = [int(cell[0]), int(cell[1])]
				if prev2 == c and prev != c:
					spin_run += 1
					if spin_run == 3:
						spin_n += 1
				else:
					spin_run = 0
				prev2 = prev
				prev = c
		elif kind == "decide":
			var g: String = str(ev.get("goal", ""))
			if g == "gathering":
				gather_busy += 1
			if g == "gather":
				gather_n += 1
			var enemy_hold: bool = g == "hold" and (str(ev.get("kind", "")) == "" or str(ev.get("lock_k", "")).begins_with("<") or str(ev.get("tgt", "")).begins_with("@Character"))
			var t: float = float(ev.get("t", 0.0))
			if enemy_hold:
				if hold_t0 < 0.0:
					hold_t0 = t
			elif hold_t0 >= 0.0:
				hold_enemy_s += maxf(0.0, t - hold_t0)
				hold_t0 = -1.0
	if hold_t0 >= 0.0:
		hold_enemy_s += 1.0
	if spin_n > 0:
		out.append("spin_loops=%d" % spin_n)
	if mis_n > 0:
		out.append("mis_steps=%d" % mis_n)
	if hold_enemy_s >= 1.0:
		out.append("hold_enemy=%.1fs" % hold_enemy_s)
	if gather_busy > 0:
		out.append("gathering_busy=%d" % gather_busy)
	if gather_n > 0:
		out.append("gather_start=%d" % gather_n)
	return out

static func _goal_flow(events: Array) -> String:
	var parts: PackedStringArray = PackedStringArray()
	var last: String = ""
	var n: int = 0
	for ev: Variant in events:
		if not (ev is Dictionary) or str(ev.get("ev", "")) != "decide":
			continue
		var g: String = str(ev.get("goal", ""))
		var why: String = str(ev.get("why", ""))
		var tag: String = g if why == "" else "%s:%s" % [g, why]
		if tag == last:
			n += 1
			continue
		if last != "":
			parts.append("%s×%d" % [last, n] if n > 1 else last)
		last = tag
		n = 1
	if last != "":
		parts.append("%s×%d" % [last, n] if n > 1 else last)
	if parts.size() > 24:
		parts.resize(24)
		parts.append("…")
	return " → ".join(parts)

static func _goal_counts(events: Array) -> Dictionary:
	var out: Dictionary = {}
	for ev: Variant in events:
		if not (ev is Dictionary) or str(ev.get("ev", "")) != "decide":
			continue
		var g: String = str(ev.get("goal", ""))
		if g == "":
			continue
		out[g] = int(out.get(g, 0)) + 1
	return out
