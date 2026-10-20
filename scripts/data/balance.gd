extends "res://scripts/data/balance/vars.gd"

## All Phase 2 combat numbers. Mutated by the secret debug menu.
## Bump BAL_REV when shipping new defaults that old saves should receive.
const Schema := preload("res://scripts/data/balance/schema.gd")
const Enemies := preload("res://scripts/data/balance/enemies.gd")
const Migrate := preload("res://scripts/data/balance/migrate.gd")
const Access := preload("res://scripts/data/balance/access.gd")
const BAL_REV := 15

var enemy_stats: Dictionary = {}

func schema() -> Array:
	var rows: Array = Schema.rows()
	_ensure_enemies()
	Enemies.append_schema(rows)
	return rows

func _init() -> void:
	_ensure_enemies()

func _ensure_enemies() -> void:
	Enemies.fill(enemy_stats)

## Static reader: `App.bal` value of `key` as float, else `fallback` (no bal yet, or no such tunable).
static func f(key: String, fallback: float) -> float:
	if App.bal != null and App.bal.get(key) != null:
		return float(App.bal.get(key))
	return fallback

func getv(name: String) -> float:
	return Access.getv(self, name)

func migrate_from(old_rev: int) -> bool:
	return Migrate.run(self, old_rev, BAL_REV)

func setv(name: String, value: float) -> void:
	Access.setv(self, name, value)

func snapshot() -> Dictionary:
	return Access.snapshot(self)

func apply_defense(raw: float, defense: float) -> float:
	return raw * (defense_k / (defense_k + maxf(0.0, defense)))
