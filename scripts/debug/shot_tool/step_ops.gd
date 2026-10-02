extends RefCounted

## Shot flow ops. Each op is one dict from the flow JSON: {"op": "wait", "ms": 300} and so on.
## State `st`: host, frames[], checks[], texts[], n (frame counter), fail (reason; stops the run).

const Args := preload("res://scripts/debug/shot_tool/tool_args.gd")
const Capture := preload("res://scripts/debug/shot_tool/capture.gd")
const Ref := preload("res://scripts/debug/shot_tool/step_ref.gd")
const Pad := preload("res://scripts/debug/shot_tool/step_input.gd")
const Texts := preload("res://scripts/debug/shot_tool/step_texts.gd")

static func fail(st: Dictionary, op: String, why: String) -> void:
	if str(st.fail).is_empty():
		st.fail = "%s: %s" % [op, why]
	printerr("SHOT: fail op=%s why=%s" % [op, why])

static func frames(st: Dictionary, n: int) -> void:
	var tree: SceneTree = (st.host as Node).get_tree()
	var i: int = 0
	while i < n:
		await tree.process_frame
		i += 1

static func settle(st: Dictionary) -> void:
	await frames(st, 2)
	if not Args.no_pixels():
		await RenderingServer.frame_post_draw

static func _same(a: Variant, b: Variant) -> bool:
	if (a is int or a is float) and (b is int or b is float):
		return is_equal_approx(float(a), float(b))
	if typeof(a) == typeof(b):
		return a == b
	return str(a) == str(b)

static func _check(_st: Dictionary, step: Dictionary, got: Variant) -> bool:
	if step.has("equals"):
		return _same(got, step.equals)
	if step.has("not_equals"):
		return not _same(got, step.not_equals)
	if step.has("contains"):
		return str(got).find(str(step.contains)) >= 0
	if step.has("gt"):
		return float(got) > float(step.gt)
	if step.has("lt"):
		return float(got) < float(step.lt)
	if step.has("is_null"):
		return (got == null) == bool(step.is_null)
	return got != null and got != false

static func op_assert(st: Dictionary, step: Dictionary) -> void:
	var expr: String = str(step.get("target", ""))
	var got: Variant = Ref.get_value(st.host, expr)
	var ok: bool = _check(st, step, got)
	st.checks.append({"op": "assert", "target": expr, "got": str(got), "ok": ok})
	printerr("SHOT: assert target=%s got=%s ok=%s" % [expr, str(got), str(ok)])
	if not ok:
		fail(st, "assert", "%s got %s" % [expr, str(got)])

static func op_texts(st: Dictionary, step: Dictionary) -> Array:
	var root: Node = null
	if step.has("root"):
		root = Ref.get_value(st.host, str(step.root)) as Node
		if root == null:
			fail(st, "texts", "root %s not found" % str(step.root))
			return []
	return Texts.collect_ui(st.host, root)

static func op_assert_texts(st: Dictionary, step: Dictionary) -> void:
	var rows: Array = op_texts(st, step)
	if not str(st.fail).is_empty():
		return
	var min_font: int = int(step.get("min_font", 0))
	var max_chars: int = int(step.get("max_chars", 0))
	var bad: PackedStringArray = PackedStringArray()
	var all_text: String = ""
	for r: Dictionary in rows:
		var t: String = str(r.text)
		all_text += t + "\n"
		if min_font > 0 and int(r.font_size) < min_font:
			bad.append("font %d < %d: %s" % [int(r.font_size), min_font, t.left(40)])
		if max_chars > 0 and t.length() > max_chars:
			bad.append("len %d > %d: %s" % [t.length(), max_chars, t.left(40)])
	for need: Variant in step.get("must_contain", []):
		if all_text.find(str(need)) < 0:
			bad.append("missing text: " + str(need))
	for nope: Variant in step.get("forbid", []):
		if all_text.find(str(nope)) >= 0:
			bad.append("forbidden text: " + str(nope))
	st.checks.append({"op": "assert_texts", "rows": rows.size(), "bad": Array(bad), "ok": bad.is_empty()})
	printerr("SHOT: assert_texts rows=%d bad=%d" % [rows.size(), bad.size()])
	if not bad.is_empty():
		fail(st, "assert_texts", "; ".join(bad.slice(0, 3)))

static func op_interact(st: Dictionary, step: Dictionary) -> void:
	var host: Node = st.host
	var node: Node = null
	if step.has("kind"):
		node = Ref.find_kind(host, str(step.kind))
	elif step.has("target"):
		node = Ref.get_value(host, str(step.target)) as Node
	if node == null or not node.has_method("interact"):
		fail(st, "interact", "no interactable for %s" % str(step.get("kind", step.get("target", "?"))))
		return
	var who: Node = host.get("player") as Node
	if bool(step.get("near", false)) and who is Node3D and node is Node3D:
		var p: Vector3 = (node as Node3D).global_position
		(who as Node3D).global_position = Vector3(p.x, (who as Node3D).global_position.y, p.z + 1.2)
		await frames(st, 3)
	var msg: Variant = node.call("interact", who)
	printerr("SHOT: interact kind=%s msg=%s" % [str(step.get("kind", "")), str(msg)])
	await frames(st, 2)

static func op_press(st: Dictionary, step: Dictionary) -> void:
	var times: int = maxi(1, int(step.get("times", 1)))
	var i: int = 0
	while i < times:
		var ok: bool = await Pad.tap(st.host, step)
		if not ok:
			fail(st, "press", "unknown input %s" % JSON.stringify(step))
			return
		i += 1
		await frames(st, 2)
	printerr("SHOT: press %s x%d" % [JSON.stringify(step), times])

static func _dump_texts(st: Dictionary, step: Dictionary, stem: String) -> void:
	if not bool(step.get("texts", false)):
		return
	var rows: Array = op_texts(st, step)
	var f: FileAccess = FileAccess.open(Args.frames_dir().path_join(stem + ".texts.json"), FileAccess.WRITE)
	if f != null:
		f.store_string(JSON.stringify(rows, "  "))

static func op_shot(st: Dictionary, step: Dictionary) -> void:
	await settle(st)
	st.n = int(st.n) + 1
	var nm: String = str(step.get("name", "shot")).validate_filename()
	var stem: String = "%02d-%s" % [int(st.n), nm]
	if Args.no_pixels():
		st.frames.append({"n": st.n, "name": nm, "file": "", "w": 0, "h": 0})
		_dump_texts(st, step, stem)
		printerr("SHOT: frame n=%d name=%s nopix=1" % [int(st.n), nm])
		return
	var img: Image = Capture._read_frame(st.host)
	if img == null:
		fail(st, "shot", "no_image")
		return
	img.convert(Image.FORMAT_RGBA8)
	if step.has("crop"):
		var c: Control = Ref.get_value(st.host, str(step.crop)) as Control
		if c == null:
			fail(st, "shot", "crop target %s not found" % str(step.crop))
			return
		var pad: int = int(step.get("pad", 8))
		var f: float = float(Args.scale_pct()) / 100.0
		var gr: Rect2 = c.get_global_rect().grow(float(pad))
		var r := Rect2i(int(gr.position.x * f), int(gr.position.y * f), int(gr.size.x * f), int(gr.size.y * f))
		img = img.get_region(r.intersection(Rect2i(0, 0, img.get_width(), img.get_height())))
	var path: String = Args.frames_dir().path_join(stem + ".png")
	var err: Error = img.save_png(path)
	if err != OK:
		fail(st, "shot", "save_%d" % int(err))
		return
	st.frames.append({"n": st.n, "name": nm, "file": stem + ".png", "w": img.get_width(), "h": img.get_height()})
	printerr("SHOT: frame n=%d name=%s path=%s w=%d h=%d" % [int(st.n), nm, path, img.get_width(), img.get_height()])
	_dump_texts(st, step, stem)

static func run(st: Dictionary, op: String, step: Dictionary) -> void:
	match op:
		"wait":
			if step.has("frames"):
				await frames(st, int(step.frames))
			else:
				await (st.host as Node).get_tree().create_timer(float(step.get("ms", 100)) / 1000.0, true).timeout
		"settle":
			await settle(st)
		"shot":
			await op_shot(st, step)
		"press":
			await op_press(st, step)
		"interact":
			await op_interact(st, step)
		"call":
			var tgt: Variant = Ref.get_value(st.host, str(step.get("target", "")))
			if not (tgt is Object) or not is_instance_valid(tgt) or not (tgt as Object).has_method(str(step.get("method", ""))):
				fail(st, "call", "no method %s on %s" % [str(step.get("method", "")), str(step.get("target", ""))])
				return
			Ref.call_value(st.host, str(step.target), str(step.method), step.get("args", []))
			await frames(st, 2)
		"set":
			if not Ref.set_value(st.host, str(step.get("target", "")), step.get("value", null)):
				fail(st, "set", "cannot set %s" % str(step.get("target", "")))
		"assert":
			op_assert(st, step)
		"assert_texts":
			op_assert_texts(st, step)
		"texts":
			var rows: Array = op_texts(st, step)
			var f: FileAccess = FileAccess.open(Args.frames_dir().path_join("%s.texts.json" % str(step.get("name", "texts"))), FileAccess.WRITE)
			if f != null:
				f.store_string(JSON.stringify(rows, "  "))
			printerr("SHOT: texts rows=%d name=%s" % [rows.size(), str(step.get("name", "texts"))])
		"device":
			Pad.device(str(step.get("kind", "pad")))
			await frames(st, 2)
		"hud":
			for key: String in ["hud", "hint", "prompt", "map_layer"]:
				var n: Node = (st.host as Node).get(key) as Node
				if n != null:
					n.set("visible", bool(step.get("on", true)))
		"seed":
			seed(int(step.get("value", 1)))
		"log":
			printerr("SHOT: log %s" % str(step.get("msg", "")))
		_:
			fail(st, op, "unknown op")
