extends Object

const Gen := preload("res://scripts/dungeon/gen.gd")
const Util := preload("res://scripts/debug/dungeon_map_util.gd")

static func _emit_ascii(lines: Array[String], data: Dictionary, overlays: Dictionary) -> void:
	var grid: PackedByteArray = data.get("grid", PackedByteArray()) as PackedByteArray
	var grid_w: int = int(data.get("w", 0))
	var grid_h: int = int(data.get("h", 0))
	var Fac: GDScript = load("res://scripts/debug/dungeon_map.gd") as GDScript
	var sc: int = Fac.ascii_scale()
	var dw: int = int((float(grid_w) + float(sc) - 1.0) / float(sc))
	var dh: int = int((float(grid_h) + float(sc) - 1.0) / float(sc))
	Util._out(lines, "ascii scale=%d dw=%d dh=%d" % [sc, dw, dh])
	Util._out(lines, "legend #=wall .=floor S=spawn B=boss D=door T=stairs C=crystal G=extract_gate $=shop P=puzzle U=puzzle_gate X=chest M=mine W=wood K=break/barrel R=crack F=campfire H=shrine L=lever/plate A=ambush E=enemy_job N=named Q=quest")
	for gy: int in dh:
		var row: String = ""
		for gx: int in dw:
			row += _sample(grid, grid_w, grid_h, overlays, gx * sc, gy * sc, sc)
		Util._out(lines, "ascii=%s" % row)


static func _sample(grid: PackedByteArray, grid_w: int, grid_h: int, overlays: Dictionary, ox: int, oy: int, sc: int) -> String:
	var best_kind: String = ""
	var best_rank: int = -1
	var saw_floor: bool = false
	for y: int in range(oy, oy + sc):
		for x: int in range(ox, ox + sc):
			var cell: Vector2i = Vector2i(x, y)
			if overlays.has(cell):
				var k: String = str(overlays[cell])
				var rnk: int = Util._rank(k)
				if rnk > best_rank:
					best_rank = rnk
					best_kind = k
			if x < 0 or y < 0 or x >= grid_w or y >= grid_h:
				continue
			if int(grid[Gen.idx(x, y, grid_w)]) == Gen.FLOOR:
				saw_floor = true
	if best_kind != "":
		return Util._glyph(best_kind)
	if saw_floor:
		return "."
	return "#"
