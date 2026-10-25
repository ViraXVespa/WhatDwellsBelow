extends RefCounted

## Overlay marks for a full-map sweep (sweep.json "marks"): rooms (x, y, w, h, kind), the dungeon map's marked cells
## (spawn, stairs, boss door, boss, crystals, gates, interactables, enemy spawn jobs, ambushes, named), placed props
## (loot chests, veins, puzzle parts) and wall torch sites (light_rt). All in grid cells; tools/lib/shots/map_overlay.py draws them.

const Collect := preload("res://scripts/debug/dungeon_map/map_collect.gd")

static func _cell(c: Variant) -> Array:
	var v: Vector2i = Vector2i(c) if (c is Vector2i or c is Vector2) else Vector2i(-1, -1)
	return [v.x, v.y]

static func _count(ids: Variant) -> int:
	return (ids as PackedStringArray).size() if ids is PackedStringArray else ((ids as Array).size() if ids is Array else 0)

static func collect(host: Node) -> Dictionary:
	var data: Dictionary = host.get("data") as Dictionary
	var rooms: Array = []
	for r: Variant in data.get("rooms", []):
		if r is Dictionary:
			rooms.append({"x": int(r.get("x", 0)), "y": int(r.get("y", 0)), "w": int(r.get("w", 0)), "h": int(r.get("h", 0)), "kind": str(r.get("kind", ""))})
	var overlays: Dictionary = {}
	Collect._collect(host, data, overlays)
	var cells: Array = []
	for c: Variant in overlays:
		cells.append({"cell": _cell(c), "kind": str(overlays[c])})
	var props: Array = []
	var jobs: Variant = host.get("prop_jobs")
	for j: Variant in (jobs if jobs is Array else []):
		if j is Dictionary:
			props.append({"cell": _cell(j.get("cell")), "kind": str(j.get("kind", ""))})
	var torches: Array = []
	var rt_path: String = "res://scripts/graphics/light_rt.gd"
	var rt: Variant = load(rt_path) if ResourceLoader.exists(rt_path) else null
	var sites: Variant = rt.get("_sites") if rt != null else null
	for site: Variant in (sites if sites is Array else []):
		if site is Dictionary:
			torches.append([int(site.get("fx", -1)), int(site.get("fz", -1))])
	var enemies: Array = []
	var sj: Variant = host.get("spawn_jobs")
	for j: Variant in (sj if sj is Array else []):
		if j is Dictionary:
			enemies.append({"cell": _cell(j.get("cell")), "kind": str(j.get("kind", "")), "n": _count(j.get("ids"))})
	return {"rooms": rooms, "cells": cells, "props": props, "torches": torches, "enemies": enemies}
