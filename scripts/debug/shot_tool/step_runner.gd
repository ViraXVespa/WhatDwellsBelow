extends RefCounted

## Scripted shot flow: after the shot boot settles, run the JSON step list (--wdb-shot-steps=FILE),
## write numbered frames and flow.json into --wdb-shot-frames, then quit. Ops: step_ops.gd.

const Args := preload("res://scripts/debug/shot_tool/tool_args.gd")
const Capture := preload("res://scripts/debug/shot_tool/capture.gd")
const Ops := preload("res://scripts/debug/shot_tool/step_ops.gd")
const Ref := preload("res://scripts/debug/shot_tool/step_ref.gd")

static func _load(path: String) -> Array:
	var raw: String = FileAccess.get_file_as_string(path)
	var data: Variant = JSON.parse_string(raw)
	if data is Array:
		return data
	if data is Dictionary and (data as Dictionary).get("steps") is Array:
		return (data as Dictionary).steps
	return []

static func _until_met(st: Dictionary, cond: Dictionary) -> bool:
	var got: Variant = Ref.get_value(st.host, str(cond.get("target", "")))
	return Ops._check(st, cond, got)

static func _list(st: Dictionary, steps: Array) -> void:
	for raw: Variant in steps:
		if not str(st.fail).is_empty():
			return
		if not (raw is Dictionary):
			Ops.fail(st, "plan", "step is not an object")
			return
		var step: Dictionary = raw
		var op: String = str(step.get("op", ""))
		st.ran = int(st.ran) + 1
		if op == "repeat":
			var max_n: int = maxi(1, int(step.get("max", 8)))
			var i: int = 0
			while i < max_n and str(st.fail).is_empty():
				await _list(st, step.get("steps", []))
				i += 1
				if step.has("until") and _until_met(st, step.until):
					break
			printerr("SHOT: repeat done n=%d" % i)
			continue
		await Ops.run(st, op, step)

static func _finish(st: Dictionary) -> void:
	var host: Node = st.host
	var ok: bool = str(st.fail).is_empty()
	var report: Dictionary = {"ok": ok, "fail": st.fail, "steps": st.ran, "frames": st.frames, "checks": st.checks}
	var f: FileAccess = FileAccess.open(Args.frames_dir().path_join("flow.json"), FileAccess.WRITE)
	if f != null:
		f.store_string(JSON.stringify(report, "  "))
	if ok and not Args.no_pixels() and not (st.frames as Array).is_empty():
		var last: Dictionary = (st.frames as Array).back()
		var img: Image = Image.load_from_file(Args.frames_dir().path_join(str(last.file)))
		if img != null:
			img.save_png(Args.out_path())
	printerr("SHOT: ok=%s path=%s steps=%d frames=%d fail=%s" % [str(ok).to_lower(), Args.out_path(), int(st.ran), (st.frames as Array).size(), str(st.fail)])
	Capture._quit(host, 0 if ok else 1)

static func run(host: Node) -> void:
	var st: Dictionary = {"host": host, "frames": [], "checks": [], "n": 0, "fail": "", "ran": 0}
	DirAccess.make_dir_recursive_absolute(Args.frames_dir())
	var steps: Array = _load(Args.steps_path())
	if steps.is_empty():
		Ops.fail(st, "plan", "no steps in %s" % Args.steps_path())
	await _list(st, steps)
	_finish(st)
