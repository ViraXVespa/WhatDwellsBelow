extends Object

## Split from actor_lit.gd: _sync_slot.

const Contact := preload("res://scripts/graphics/actor_lit/lit_contact.gd")
const Emis := preload("res://scripts/graphics/actor_lit/lit_emis.gd")
const Geo := preload("res://scripts/graphics/actor_lit/lit_geo.gd")
const K := preload("res://scripts/graphics/actor_lit/lit_k.gd")
const Soles := preload("res://scripts/graphics/actor_lit/soles.gd")

static func _sync_slot(host: Node, slot: int, tex: Texture2D, soles: Vector4, fl: Vector2, fr: Vector2, dir: Vector2, px: float, feet: Vector2) -> void:
	var t0: int = host._mark_t()
	var node: MeshInstance3D = host.marks[slot]
	var src: Vector2 = Vector2.ZERO
	if host._src_at[slot].length_squared() > 0.0004:
		src = host._src_at[slot] - feet
	var reach: Vector2 = dir * host._stretch_at[slot]
	var key: Array = [
		tex.get_instance_id(), px, host._flip,
		snappedf(fl.x, 0.01), snappedf(fl.y, 0.01),
		snappedf(fr.x, 0.01), snappedf(fr.y, 0.01),
		snappedf(reach.x, 0.01), snappedf(reach.y, 0.01),
		snappedf(src.x, 0.05), snappedf(src.y, 0.05),
	]
	var mat: ShaderMaterial = node.material_override as ShaderMaterial
	if mat != null:
		var t_albedo: int = host._mark_t()
		var albedo: Texture2D = Soles._solid(tex, host.solid) if host.solid != "" else Emis.mask(tex, Emis.rule_of(host.get_parent()))
		host._mark_us(7, t_albedo)
		var aid: int = albedo.get_instance_id() if albedo != null else 0
		if aid != host._albedo_id[slot]:
			mat.set_shader_parameter("albedo_tex", albedo)
			host._albedo_id[slot] = aid
		if host.solid == "profile":
			var tf: int = host._mark_t()
			host.foot = Soles._foot(tex)
			host._mark_us(4, tf)
		else:
			host.foot = 0
		var t_contact: int = host._mark_t()
		var per_col: bool = host.solid == "" and K.on_grid()
		var contact_flag: float = 1.0 if per_col else 0.0
		if contact_flag != host._contact_on[slot]:
			mat.set_shader_parameter("contact_on", contact_flag)
			host._contact_on[slot] = contact_flag
		if per_col:
			var ctex: Texture2D = Contact.tex(tex, Soles._soles(tex), px, host.plant_flat)
			var cid: int = ctex.get_instance_id() if ctex != null else 0
			if cid != host._contact_id[slot]:
				mat.set_shader_parameter("contact_tex", ctex)
				host._contact_id[slot] = cid
		host._mark_us(8, t_contact)
	if key == host._key_at[slot] and node.mesh != null:
		host._mark_us(3, t0)
		return
	host._key_at[slot] = key
	var tq: int = host._mark_t()
	node.mesh = Geo._quad(host, tex, Soles._span(tex), soles, fl, fr, dir, px, host._stretch_at[slot], src)
	host._mark_us(5, tq)
	host._mark_us(3, t0)
