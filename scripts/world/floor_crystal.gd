extends "res://scripts/world/interact.gd"

const CrystalNet := preload("res://scripts/world/crystal_net.gd")
const CrystalUI := preload("res://scripts/ui/crystal_ui.gd")

var crystal_cl := 1
var crystal_cell := Vector2i.ZERO
var crystal_on := false
var crystal_gate := false


func setup_crystal(pos: Vector3, cell: Vector2i, cl: int, gate: bool) -> void:
	crystal_cell = cell
	crystal_cl = maxi(1, cl)
	crystal_gate = gate
	crystal_on = gate or CrystalNet.is_on(cell)
	setup("crystal", pos, false)
	add_to_group("floor_crystals")
	if crystal_on:
		CrystalNet.mark_on(cell)
	refresh()


func refresh() -> void:
	if kind != "crystal":
		super.refresh()
		return
	locked = false
	if not crystal_on:
		prompt = "Clear the area to activate." if CrystalNet.area_hostile(self) else "A: Activate crystal"
	else:
		prompt = "A: Transport network"
	if label:
		label.text = _title()
		label.visible = not hidden
		label.modulate = Color(0.45, 0.95, 1.0) if crystal_on else Color(0.72, 0.82, 0.88)
	var tint := Color(0.45, 0.95, 1.0) if crystal_on else Color(0.28, 0.55, 0.7)
	if spr:
		spr.modulate = tint
	if mesh and mesh.material_override is StandardMaterial3D:
		var mat: StandardMaterial3D = mesh.material_override
		mat.albedo_color = tint


func _title() -> String:
	if kind != "crystal":
		return super._title()
	if crystal_gate:
		return "ENTRANCE CRYSTAL  ·  CL %d" % crystal_cl
	return "FLOOR CRYSTAL  ·  CL %d" % crystal_cl


func interact(who: Node) -> String:
	if kind != "crystal":
		return super.interact(who)
	if App.ui_open:
		return ""
	refresh()
	if not crystal_on:
		if CrystalNet.area_hostile(self):
			return prompt
		CrystalNet.activate(self)
		refresh()
		App.toast("Crystal bound to this floor.")
	CrystalUI.open(self)
	return "The crystal hums."
